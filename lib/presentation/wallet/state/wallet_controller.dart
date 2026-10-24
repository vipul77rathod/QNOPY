import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:qnopy/core/service/screenshot_protection.dart';

import '../../../data/wallet/models/wallet_model.dart';
import '../../../data/wallet/repositories/wallet_repository.dart';
import '../../../data/wallet/storage/wallet_storage.dart';

enum WalletPaymentState {
  idle,
  creatingOrder,
  readyToPay,
  paying,
  verifying,
  pending,
  success,
  declined,
  failed,
  unknown,
}

class WalletController extends GetxController {
  WalletController({
    required WalletRepository repository,
    required WalletStorage storage,
  })  : _repository = repository,
        _storage = storage;

  final WalletRepository _repository;
  final WalletStorage _storage;

  final Rxn<WalletModel> wallet = Rxn<WalletModel>();
  final RxList<WalletOrderModel> orders = <WalletOrderModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isBusy = false.obs;
  final RxBool paymentOutcomeUncertain = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString infoMessage = ''.obs;
  final Rx<WalletPaymentState> paymentState = WalletPaymentState.idle.obs;
  final Rxn<WalletOrderModel> activeOrder = Rxn<WalletOrderModel>();
  final RxString selectedMethod = 'upi'.obs;

  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _paymentRequestInFlight = false;

  @override
  void onInit() {
    super.onInit();
    loadDashboard(recover: true);
    ScreenshotProtection.disable();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    ScreenshotProtection.enable();
    super.onClose();
  }

  Future<void> loadDashboard({bool recover = false}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final results = await Future.wait<dynamic>([
        _repository.getWallet(),
        _repository.getOrders(),
      ]);
      wallet.value = results[0] as WalletModel;
      orders.assignAll(results[1] as List<WalletOrderModel>);
      if (recover) await recoverActiveOrder();
    } catch (_) {
      errorMessage.value = 'Could not load wallet. Check your connection and retry.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshDashboard() => loadDashboard(recover: true);

  void setPaymentMethod(String? method) {
    if (method == 'upi' || method == 'card') selectedMethod.value = method!;
  }

  Future<void> topUp({required int amountPaise, String? note}) async {
    if (isBusy.value || _paymentRequestInFlight) return;

    final existing = activeOrder.value;
    if (existing != null && existing.status == 'processing') {
      paymentState.value = WalletPaymentState.pending;
      paymentOutcomeUncertain.value = true;
      infoMessage.value = 'This order is already processing. Do not start another payment.';
      _startPolling(existing.orderId);
      return;
    }
    if (existing != null && existing.status == 'created') {
      final started = await _storage.wasPaymentStarted(existing.orderId);
      if (started) {
        paymentOutcomeUncertain.value = true;
        paymentState.value = WalletPaymentState.unknown;
        infoMessage.value = 'A payment request was already started for this order. We will check its status; do not pay again.';
        _startPolling(existing.orderId);
        return;
      }
      await retryPaymentForCreatedOrder();
      return;
    }
    if (paymentOutcomeUncertain.value &&
        (existing == null || (existing.status != 'paid' && existing.status != 'failed'))) {
      errorMessage.value = 'A previous payment outcome is still unresolved. Do not create another order; recover the existing order first.';
      return;
    }

    isBusy.value = true;
    errorMessage.value = '';
    infoMessage.value = '';
    paymentOutcomeUncertain.value = false;
    paymentState.value = WalletPaymentState.creatingOrder;
    try {
      final order = await _repository.createOrder(
        amountPaise: amountPaise,
        note: note,
      );
      activeOrder.value = order;
      paymentState.value = WalletPaymentState.readyToPay;
      await _attemptPayment(order);
    } catch (error) {
      if (error is PendingOrderAttemptMismatchException) {
        errorMessage.value = 'A previous order-creation attempt is unresolved. Retry with its original amount; a new amount cannot reuse the same idempotency key.';
      } else if (_isNetworkUncertain(error)) {
        paymentState.value = WalletPaymentState.unknown;
        errorMessage.value = 'Order creation may have succeeded. The same amount and idempotency key are saved; refresh to recover it before trying another amount.';
      } else {
        errorMessage.value = _friendlyError(error);
        paymentState.value = WalletPaymentState.failed;
      }
    } finally {
      isBusy.value = false;
      await _refreshDashboardOnly();
    }
  }

  Future<void> retryPaymentForCreatedOrder() async {
    final order = activeOrder.value;
    if (order == null || order.status != 'created' || isBusy.value || _paymentRequestInFlight) return;
    if (await _storage.wasPaymentStarted(order.orderId)) {
      paymentOutcomeUncertain.value = true;
      paymentState.value = WalletPaymentState.unknown;
      errorMessage.value = 'The gateway request may already have been accepted. Retrying could charge twice, so this order will only be checked for status.';
      _startPolling(order.orderId);
      return;
    }

    isBusy.value = true;
    errorMessage.value = '';
    infoMessage.value = '';
    paymentOutcomeUncertain.value = false;
    try {
      await _attemptPayment(order);
    } finally {
      isBusy.value = false;
      await _refreshDashboardOnly();
    }
  }

  Future<void> _attemptPayment(WalletOrderModel order) async {
    if (_paymentRequestInFlight) return;
    _paymentRequestInFlight = true;
    paymentState.value = WalletPaymentState.paying;
    paymentOutcomeUncertain.value = true;

    try {
      await _storage.markPaymentStarted(order.orderId);
      final result = await _repository.pay(
        orderId: order.orderId,
        method: selectedMethod.value,
      );
      await _storage.saveGatewayResult(
        orderId: order.orderId,
        paymentId: result.paymentId,
        signature: result.signature,
      );

      paymentState.value = WalletPaymentState.verifying;
      await _repository.verifyPayment(
        orderId: order.orderId,
        paymentId: result.paymentId,
        signature: result.signature,
      );
      await _storage.clearGatewayResult(order.orderId);
      await _refreshOrderAndWallet(order.orderId);
      final latestStatus = activeOrder.value?.status;
      if (latestStatus == 'paid') {
        paymentState.value = WalletPaymentState.success;
        paymentOutcomeUncertain.value = false;
        infoMessage.value = 'Payment verified and order is paid. Balance shown below is fetched from the server.';
        await _storage.clearActiveOrder();
      } else if (latestStatus == 'failed') {
        paymentState.value = WalletPaymentState.failed;
        paymentOutcomeUncertain.value = false;
        errorMessage.value = 'The server reports that this order failed.';
        await _storage.clearPaymentStarted(order.orderId);
      } else {
        paymentState.value = WalletPaymentState.pending;
        infoMessage.value = 'Payment was verified, but settlement is still processing. Do not pay again.';
        _startPolling(order.orderId);
      }
    } on GatewayPendingException {
      paymentState.value = WalletPaymentState.pending;
      paymentOutcomeUncertain.value = true;
      infoMessage.value = 'The gateway says payment is pending. Do not pay again; checking this order.';
      await _refreshOrderAndWallet(order.orderId);
      _startPolling(order.orderId);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final body = error.response?.data;
      final code = body is Map ? body['error']?.toString() : null;

      if (status == 400 && code == 'signature_mismatch') {
        await _storage.clearGatewayResult(order.orderId);
      }

      if (status == 402 && code == 'payment_declined') {
        await _storage.clearPaymentStarted(order.orderId);
        await _refreshOrderAndWallet(order.orderId);
        if (activeOrder.value?.status == 'failed') {
          paymentState.value = WalletPaymentState.failed;
          paymentOutcomeUncertain.value = false;
          errorMessage.value = 'This order has reached the maximum failed attempts. Start a new top-up.';
        } else {
          paymentState.value = WalletPaymentState.declined;
          paymentOutcomeUncertain.value = false;
          final attemptsLeft = body is Map ? body['attemptsLeft'] : null;
          errorMessage.value = 'Payment declined. Attempts left: ${attemptsLeft ?? 'unknown'}. You can retry the same order.';
        }
        return;
      }

      if (status == 409 && code == 'already_paid_or_processing') {
        await _refreshOrderAndWallet(order.orderId);
        if (activeOrder.value?.status == 'paid') {
          paymentState.value = WalletPaymentState.success;
          paymentOutcomeUncertain.value = false;
          await _storage.clearActiveOrder();
        } else {
          paymentState.value = WalletPaymentState.pending;
          paymentOutcomeUncertain.value = true;
          infoMessage.value = 'The order is already processing. Do not submit another payment.';
          _startPolling(order.orderId);
        }
        return;
      }

      paymentState.value = WalletPaymentState.unknown;
      paymentOutcomeUncertain.value = true;
      errorMessage.value = (status == 400 && code == 'signature_mismatch')
          ? 'Payment verification failed. We are checking the server order status; do not pay again.'
          : 'We could not confirm the payment result. Do not pay again; checking the existing order.';
      await _recoverSpecificOrder(order.orderId);
    } catch (error) {
      paymentState.value = WalletPaymentState.unknown;
      paymentOutcomeUncertain.value = true;
      errorMessage.value = _friendlyError(error);
      await _recoverSpecificOrder(order.orderId);
    } finally {
      _paymentRequestInFlight = false;
    }
  }

  Future<void> recoverActiveOrder() async {
    final orderId = await _storage.readActiveOrderId();
    if (orderId != null && orderId.isNotEmpty) {
      await _storage.clearPendingOrderAttempt();
      await _recoverSpecificOrder(orderId);
      return;
    }

    final pending = await _storage.readPendingOrderAttempt();
    if (pending != null) {
      try {
        final order = await _repository.createOrder(
          amountPaise: pending.amountPaise,
          note: pending.note,
        );
        activeOrder.value = order;
        paymentState.value = order.status == 'created'
            ? WalletPaymentState.readyToPay
            : WalletPaymentState.pending;
        infoMessage.value = 'Recovered the existing order using its saved idempotency key. Review its status before continuing.';
        if (order.status == 'processing') {
          paymentOutcomeUncertain.value = true;
          _startPolling(order.orderId);
        }
      } catch (_) {
        paymentState.value = WalletPaymentState.unknown;
        errorMessage.value = 'Could not recover the previous order-creation attempt. Keep the saved attempt and retry refresh; do not enter a different amount yet.';
      }
    }
  }

  Future<void> _recoverSpecificOrder(String orderId) async {
    try {
      final order = await _repository.getOrder(orderId);
      activeOrder.value = order;
      switch (order.status) {
        case 'paid':
          paymentState.value = WalletPaymentState.success;
          paymentOutcomeUncertain.value = false;
          infoMessage.value = 'The server reports this order as paid. Wallet balance is refreshed from the server.';
          await _storage.clearActiveOrder();
          await _refreshDashboardOnly();
          break;
        case 'processing':
          final savedResult = await _storage.readGatewayResult(orderId);
          if (savedResult != null) {
            try {
              await _repository.verifyPayment(
                orderId: orderId,
                paymentId: savedResult.paymentId,
                signature: savedResult.signature,
              );
              await _storage.clearGatewayResult(orderId);
              activeOrder.value = await _repository.getOrder(orderId);
            } on DioException catch (verifyError) {
              final verifyBody = verifyError.response?.data;
              final verifyCode = verifyBody is Map ? verifyBody['error']?.toString() : null;
              if (verifyError.response?.statusCode == 400 && verifyCode == 'signature_mismatch') {
                await _storage.clearGatewayResult(orderId);
                errorMessage.value = 'Payment verification failed. Checking the server order status; do not pay again.';
              }
            } catch (_) {
              // Keep the saved result so verification can be retried after recovery.
            }
            if (activeOrder.value?.status == 'paid') {
              paymentState.value = WalletPaymentState.success;
              paymentOutcomeUncertain.value = false;
              infoMessage.value = 'The server reports this order as paid after recovery.';
              await _storage.clearActiveOrder();
              await _refreshDashboardOnly();
              break;
            }
          }
          paymentState.value = WalletPaymentState.pending;
          paymentOutcomeUncertain.value = true;
          infoMessage.value = 'Payment is still processing. Do not start another payment.';
          _startPolling(orderId);
          await _refreshDashboardOnly();
          break;
        case 'failed':
          paymentState.value = WalletPaymentState.failed;
          paymentOutcomeUncertain.value = false;
          errorMessage.value = 'This order has failed. You can start a new top-up.';
          await _storage.clearPaymentStarted(orderId);
          await _refreshDashboardOnly();
          break;
        case 'created':
          final started = await _storage.wasPaymentStarted(orderId);
          if (started) {
            paymentState.value = WalletPaymentState.unknown;
            paymentOutcomeUncertain.value = true;
            infoMessage.value = 'The server still shows this order as created, but a gateway request was already started. Do not retry payment; keep checking this order status.';
            _startPolling(orderId);
          } else {
            paymentState.value = WalletPaymentState.readyToPay;
            paymentOutcomeUncertain.value = false;
            infoMessage.value = 'This order has not had a gateway request started. You can pay this existing order.';
          }
          break;
        default:
          paymentState.value = WalletPaymentState.unknown;
          paymentOutcomeUncertain.value = true;
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        // If a gateway call had started, preserve the recovery marker and block
        // new payments. A missing mock-server record is not proof of no charge.
        final paymentStarted = await _storage.wasPaymentStarted(orderId);
        if (paymentStarted) {
          final amount = await _storage.readActiveOrderAmountPaise() ?? 0;
          activeOrder.value ??= WalletOrderModel(
            orderId: orderId,
            amountPaise: amount,
            status: 'unknown',
            createdAt: null,
          );
          paymentState.value = WalletPaymentState.unknown;
          paymentOutcomeUncertain.value = true;
          errorMessage.value = 'The server cannot find this saved order. The mock server may have restarted; because payment had started, do not create another payment until the original outcome is resolved.';
        } else {
          await _storage.clearActiveOrder();
          activeOrder.value = null;
          paymentState.value = WalletPaymentState.unknown;
          paymentOutcomeUncertain.value = false;
          errorMessage.value = 'The saved order is not available on the server. The mock server may have restarted. No gateway request was recorded locally for this order.';
        }
      } else {
        errorMessage.value = 'Could not recover payment status. Retry refresh; do not create another payment yet.';
      }
    } catch (_) {
      errorMessage.value = 'Could not recover payment status. Retry refresh; do not create another payment yet.';
    }
  }

  Future<void> _refreshOrderAndWallet(String orderId) async {
    try {
      activeOrder.value = await _repository.getOrder(orderId);
    } catch (_) {}
    await _refreshDashboardOnly();
  }

  Future<void> _refreshDashboardOnly() async {
    try {
      wallet.value = await _repository.getWallet();
      orders.assignAll(await _repository.getOrders());
    } catch (_) {
      // Preserve last server-confirmed values; never mutate balance locally.
    }
  }

  void _startPolling(String orderId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_pollInFlight) return;
      _pollInFlight = true;
      try {
        final order = await _repository.getOrder(orderId);
        activeOrder.value = order;
        if (order.status == 'paid') {
          _pollTimer?.cancel();
          paymentState.value = WalletPaymentState.success;
          paymentOutcomeUncertain.value = false;
          infoMessage.value = 'Top-up is paid according to the server. Balance has been refreshed from the server.';
          await _storage.clearActiveOrder();
          await _refreshDashboardOnly();
        } else if (order.status == 'failed') {
          _pollTimer?.cancel();
          paymentState.value = WalletPaymentState.failed;
          paymentOutcomeUncertain.value = false;
          errorMessage.value = 'The server reports that this order failed. You can start a new top-up.';
          await _storage.clearPaymentStarted(orderId);
          await _refreshDashboardOnly();
        }
      } catch (_) {
        // Keep checking. A transient network error is not a payment failure.
      } finally {
        _pollInFlight = false;
      }
    });
  }

  String _friendlyError(Object error) {
    if (error is FormatException) return error.message;
    if (error is PendingOrderAttemptMismatchException) {
      return 'A previous order attempt must be recovered with its original amount.';
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final code = data is Map ? data['error']?.toString() : null;
      if (status == 422 && code == 'amount_out_of_range') return 'Amount must be between ₹1 and ₹50,000.';
      if (status == 422 && code == 'idempotency_key_reuse') return 'The saved idempotency key was used with a different amount. Do not create a new payment until the original attempt is recovered.';
      if (status == 503) return 'The service is temporarily unavailable. Retry refresh before starting another payment.';
    }
    return 'Something went wrong. Check the order status before retrying.';
  }

  bool _isNetworkUncertain(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError;
    }
    return false;
  }
}
