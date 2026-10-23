import 'package:dio/dio.dart';

class ApiClient {
  ApiClient() : dio = Dio(BaseOptions(
    //baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3002'),
    baseUrl: "http://10.69.50.57:3002",
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    sendTimeout: const Duration(seconds: 12),
    headers: const {'Content-Type': 'application/json'},
  ));
  final Dio dio;
}
