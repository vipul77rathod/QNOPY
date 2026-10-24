import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../models/wallet_model.dart';
import '../storage/wallet_storage.dart';

class WalletRepository {
  WalletRepository({
    required Dio dio,
    required WalletStorage storage,
  })  : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final WalletStorage _storage;
  static const Uuid _uuid = Uuid();

  Future<WalletModel> getWallet() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/wallet');
    return WalletModel.fromJson(
      Map<String, dynamic>.from(response.data ?? <String, dynamic>{}),
    );
  }

  Future<List<WalletOrderModel>> getOrders() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/orders');
    final data = Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    final rawOrders = data['orders'];
    if (rawOrders is! List) return const [];
    return rawOrders
        .whereType<Map>()
        .map((item) => WalletOrderModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<WalletOrderModel> getOrder(String orderId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/orders/${Uri.encodeComponent(orderId)}',
    );
    return WalletOrderModel.fromJson(
      Map<String, dynamic>.from(response.data ?? <String, dynamic>{}),
    );
  }

  Future<WalletOrderModel> createOrder({
    required int amountPaise,
    String? note,
  }) async {
    final normalizedNote = (note == null || note.trim().isEmpty) ? null : note.trim();
    var pending = await _storage.readPendingOrderAttempt();

    if (pending != null &&
        (pending.amountPaise != amountPaise || pending.note != normalizedNote)) {
      throw const PendingOrderAttemptMismatchException();
    }

    if (pending == null) {
      pending = PendingOrderAttempt(
        idempotencyKey: _uuid.v4(),
        amountPaise: amountPaise,
        note: normalizedNote,
      );
      await _storage.savePendingOrderAttempt(
        idempotencyKey: pending.idempotencyKey,
        amountPaise: pending.amountPaise,
        note: pending.note,
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/orders',
      data: {
        'amount': pending.amountPaise,
        if (pending.note != null) 'note': pending.note,
      },
      options: Options(headers: {'Idempotency-Key': pending.idempotencyKey}),
    );

    final order = WalletOrderModel.fromJson(
      Map<String, dynamic>.from(response.data ?? <String, dynamic>{}),
    );
    if (order.orderId.isEmpty) {
      throw const FormatException('Order response did not include orderId.');
    }

    await _storage.saveActiveOrder(
      orderId: order.orderId,
      amountPaise: order.amountPaise,
    );
    await _storage.clearPendingOrderAttempt();
    return order;
  }

  Future<GatewayPaymentResult> pay({
    required String orderId,
    required String method,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/gateway/pay',
      data: {'orderId': orderId, 'method': method},
      options: Options(
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    if (response.statusCode == 202 || data['status'] == 'pending') {
      throw const GatewayPendingException();
    }
    final result = GatewayPaymentResult.fromJson(data);
    if (result.paymentId.isEmpty || result.signature.isEmpty) {
      throw const FormatException('Gateway response is missing payment verification fields.');
    }
    return result;
  }

  Future<String> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/payments/verify',
      data: {
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      },
    );
    final data = Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    if (data['verified'] != true) {
      throw const FormatException('Payment signature verification failed.');
    }
    return (data['orderStatus'] ?? 'processing').toString();
  }
}

class GatewayPendingException implements Exception {
  const GatewayPendingException();
}

class PendingOrderAttemptMismatchException implements Exception {
  const PendingOrderAttemptMismatchException();
}
