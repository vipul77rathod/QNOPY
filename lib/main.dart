import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qnopy/presentation/home/home.dart';
import 'core/network/api_client.dart';
import 'data/kyc/repositories/kyc_repository.dart';
import 'data/kyc/storage/kyc_session_storage.dart';
import 'presentation/kyc/bindings/kyc_binding.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = KycRepository(dio: ApiClient().dio, storage: KycSessionStorage());
  runApp(KycApp(repository: repository));
}

class KycApp extends StatelessWidget {
  const KycApp({super.key, required this.repository});
  final KycRepository repository;

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'Qnopy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457C5))),
        darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8EACFF), brightness: Brightness.dark)),
        themeMode: ThemeMode.system,
        initialBinding: KycBinding(repository: repository),
        home: const Home(),
      );
}
