import 'package:shared_preferences/shared_preferences.dart';

class KycSessionStorage {
  static const _sessionIdKey = 'kyc_session_id';
  static const _createKey = 'kyc_create_idempotency_key';

  Future<String?> readSessionId() async => (await SharedPreferences.getInstance()).getString(_sessionIdKey);
  Future<void> saveSessionId(String value) async => (await SharedPreferences.getInstance()).setString(_sessionIdKey, value);
  Future<void> clearSessionId() async => (await SharedPreferences.getInstance()).remove(_sessionIdKey);
  Future<String?> readCreateKey() async => (await SharedPreferences.getInstance()).getString(_createKey);
  Future<void> saveCreateKey(String value) async => (await SharedPreferences.getInstance()).setString(_createKey, value);
  Future<void> clearCreateKey() async => (await SharedPreferences.getInstance()).remove(_createKey);
}
