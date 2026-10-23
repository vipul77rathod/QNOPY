class KycSessionModel {
  const KycSessionModel({
    required this.sessionId,
    required this.status,
    required this.step,
    required this.retriesLeft,
    this.docType,
    this.docNumberMasked,
    this.reason,
    this.updatedAt,
  });

  final String sessionId;
  final String status;
  final String step;
  final int retriesLeft;
  final String? docType;
  final String? docNumberMasked;
  final String? reason;
  final DateTime? updatedAt;

  factory KycSessionModel.fromJson(Map<String, dynamic> json) {
    // POST /sessions can wrap the view as {kycView: {...}}; other endpoints
    // return the view directly.
    final raw = json['kycView'];
    final view = raw is Map ? Map<String, dynamic>.from(raw) : json;
    return KycSessionModel(
      sessionId: (view['sessionId'] ?? '').toString(),
      status: (view['status'] ?? 'created').toString(),
      step: (view['step'] ?? 'document').toString(),
      retriesLeft: _int(view['retriesLeft'], 2),
      docType: view['docType']?.toString(),
      docNumberMasked: view['docNumberMasked']?.toString(),
      reason: view['reason']?.toString(),
      updatedAt: DateTime.tryParse((view['updatedAt'] ?? '').toString()),
    );
  }

  static int _int(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool get isVerified => status == 'verified';
  bool get isManualReview => status == 'manual_review';
  bool get isBlocked => status == 'blocked';
  bool get isLivenessFailed => status == 'liveness_failed';
  bool get needsDocument => step == 'document' && status == 'created';
  bool get needsLiveness => step == 'liveness' && (status == 'document_received' || status == 'liveness_failed');
}
