class WalletModel {
  const WalletModel({
    required this.balancePaise,
    required this.currency,
    required this.processingOrders,
  });

  final int balancePaise;
  final String currency;
  final int processingOrders;

  double get balanceRupees => balancePaise / 100.0;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      balancePaise: _asInt(json['balance']),
      currency: (json['currency'] ?? 'INR').toString(),
      processingOrders: _asInt(json['processingOrders']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class WalletOrderModel {
  const WalletOrderModel({
    required this.orderId,
    required this.amountPaise,
    required this.status,
    required this.createdAt,
    this.note,
    this.paymentId,
    this.failedAttempts = 0,
  });

  final String orderId;
  final int amountPaise;
  final String status;
  final DateTime? createdAt;
  final String? note;
  final String? paymentId;
  final int failedAttempts;

  double get amountRupees => amountPaise / 100.0;

  factory WalletOrderModel.fromJson(Map<String, dynamic> json) {
    return WalletOrderModel(
      orderId: (json['orderId'] ?? '').toString(),
      amountPaise: _asInt(json['amount']),
      status: (json['status'] ?? 'created').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      note: json['note']?.toString(),
      paymentId: json['paymentId']?.toString(),
      failedAttempts: _asInt(json['failedAttempts']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class GatewayPaymentResult {
  const GatewayPaymentResult({
    required this.paymentId,
    required this.signature,
  });

  final String paymentId;
  final String signature;

  factory GatewayPaymentResult.fromJson(Map<String, dynamic> json) {
    return GatewayPaymentResult(
      paymentId: (json['paymentId'] ?? '').toString(),
      signature: (json['signature'] ?? '').toString(),
    );
  }
}
