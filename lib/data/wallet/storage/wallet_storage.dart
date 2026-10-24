import 'package:shared_preferences/shared_preferences.dart';

class StoredGatewayResult {
  const StoredGatewayResult({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

class PendingOrderAttempt {
  const PendingOrderAttempt({
    required this.idempotencyKey,
    required this.amountPaise,
    this.note,
  });

  final String idempotencyKey;
  final int amountPaise;
  final String? note;
}

/// Persists only recovery metadata; never stores card or other payment credentials.
class WalletStorage {
  static const _activeOrderIdKey = 'wallet_active_order_id';
  static const _activeOrderAmountKey = 'wallet_active_order_amount_paise';
  static const _pendingKey = 'wallet_pending_order_idempotency_key';
  static const _pendingAmountKey = 'wallet_pending_order_amount_paise';
  static const _pendingNoteKey = 'wallet_pending_order_note';
  static const _paymentStartedOrderKey = 'wallet_payment_started_order_id';
  static const _gatewayResultOrderKey = 'wallet_gateway_result_order_id';
  static const _gatewayResultPaymentKey = 'wallet_gateway_result_payment_id';
  static const _gatewayResultSignatureKey = 'wallet_gateway_result_signature';

  Future<String?> readActiveOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeOrderIdKey);
  }

  Future<int?> readActiveOrderAmountPaise() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeOrderAmountKey);
  }

  Future<void> saveActiveOrder({
    required String orderId,
    required int amountPaise,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeOrderIdKey, orderId);
    await prefs.setInt(_activeOrderAmountKey, amountPaise);
  }

  Future<void> clearActiveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeOrderIdKey);
    await prefs.remove(_activeOrderAmountKey);
    await prefs.remove(_paymentStartedOrderKey);
    await prefs.remove(_gatewayResultOrderKey);
    await prefs.remove(_gatewayResultPaymentKey);
    await prefs.remove(_gatewayResultSignatureKey);
  }

  Future<PendingOrderAttempt?> readPendingOrderAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_pendingKey);
    final amount = prefs.getInt(_pendingAmountKey);
    if (key == null || key.isEmpty || amount == null) return null;
    return PendingOrderAttempt(
      idempotencyKey: key,
      amountPaise: amount,
      note: prefs.getString(_pendingNoteKey),
    );
  }

  Future<void> savePendingOrderAttempt({
    required String idempotencyKey,
    required int amountPaise,
    String? note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, idempotencyKey);
    await prefs.setInt(_pendingAmountKey, amountPaise);
    if (note == null || note.trim().isEmpty) {
      await prefs.remove(_pendingNoteKey);
    } else {
      await prefs.setString(_pendingNoteKey, note.trim());
    }
  }

  Future<void> clearPendingOrderAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    await prefs.remove(_pendingAmountKey);
    await prefs.remove(_pendingNoteKey);
  }


  Future<void> saveGatewayResult({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gatewayResultOrderKey, orderId);
    await prefs.setString(_gatewayResultPaymentKey, paymentId);
    await prefs.setString(_gatewayResultSignatureKey, signature);
  }

  Future<StoredGatewayResult?> readGatewayResult(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_gatewayResultOrderKey) != orderId) return null;
    final paymentId = prefs.getString(_gatewayResultPaymentKey);
    final signature = prefs.getString(_gatewayResultSignatureKey);
    if (paymentId == null || signature == null) return null;
    return StoredGatewayResult(
      orderId: orderId,
      paymentId: paymentId,
      signature: signature,
    );
  }

  Future<void> clearGatewayResult(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_gatewayResultOrderKey) == orderId) {
      await prefs.remove(_gatewayResultOrderKey);
      await prefs.remove(_gatewayResultPaymentKey);
      await prefs.remove(_gatewayResultSignatureKey);
    }
  }

  Future<void> markPaymentStarted(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paymentStartedOrderKey, orderId);
  }

  Future<bool> wasPaymentStarted(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_paymentStartedOrderKey) == orderId;
  }

  Future<void> clearPaymentStarted(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_paymentStartedOrderKey) == orderId) {
      await prefs.remove(_paymentStartedOrderKey);
    }
  }
}
