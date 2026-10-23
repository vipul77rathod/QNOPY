import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/kyc_session_model.dart';
import '../storage/kyc_session_storage.dart';

class KycRepository {
  KycRepository({required Dio dio, required KycSessionStorage storage}) : _dio = dio, _storage = storage;
  final Dio _dio;
  final KycSessionStorage _storage;
  static const _uuid = Uuid();

  Future<KycSessionModel> createOrResumeSession() async {
    final savedId = await _storage.readSessionId();
    if (savedId != null && savedId.isNotEmpty) {
      try {
        return await getSession(savedId);
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
        await _storage.clearSessionId();
      }
    }

    var key = await _storage.readCreateKey();
    if (key == null || key.isEmpty) {
      key = _uuid.v4();
      await _storage.saveCreateKey(key);
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/kyc/sessions',
      data: <String, dynamic>{},
      options: Options(headers: {'Idempotency-Key': key}),
    );
    final session = KycSessionModel.fromJson(Map<String, dynamic>.from(response.data ?? {}));
    if (session.sessionId.isEmpty) throw const FormatException('Server response did not include sessionId.');
    await _storage.saveSessionId(session.sessionId);
    await _storage.clearCreateKey();
    return session;
  }

  Future<KycSessionModel> getSession(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/kyc/sessions/${Uri.encodeComponent(id)}');
    return KycSessionModel.fromJson(Map<String, dynamic>.from(response.data ?? {}));
  }

  Future<KycSessionModel> submitDocument({required String sessionId, required String docType, required String docNumber}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/kyc/sessions/${Uri.encodeComponent(sessionId)}/document',
      data: {
        'docType': docType,
        'docNumber': docNumber
      },
    );
    return KycSessionModel.fromJson(Map<String, dynamic>.from(response.data ?? {}));
  }

  Future<KycSessionModel> submitLiveness({required String sessionId, required double score}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/kyc/sessions/${Uri.encodeComponent(sessionId)}/liveness',
      data: {
        'score': score
      },
    );
    return KycSessionModel.fromJson(Map<String, dynamic>.from(response.data ?? {}));
  }

  Future<void> startNewSession() async {
    await _storage.clearSessionId();
    await _storage.clearCreateKey();
  }
}
