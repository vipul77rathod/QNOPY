
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/network/api_client.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'data/kyc/repositories/kyc_repository.dart';
import 'data/kyc/storage/kyc_session_storage.dart';
import 'data/wallet/repositories/wallet_repository.dart';
import 'data/wallet/storage/wallet_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();

  final walletStorage = WalletStorage();

  final kycRepository = KycRepository(
    dio: apiClient.dio,
    storage: KycSessionStorage(),
  );

  final walletRepository = WalletRepository(
    dio: apiClient.dio,
    storage: walletStorage,
  );

  runApp(
    MyApp(
      kycRepository: kycRepository,
      walletRepository: walletRepository,
      walletStorage: walletStorage,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.kycRepository,
    required this.walletRepository,
    required this.walletStorage,
  });

  final KycRepository kycRepository;
  final WalletRepository walletRepository;
  final WalletStorage walletStorage;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Qnopy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2457C5),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8EACFF),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages(
        kycRepository: kycRepository,
        walletRepository: walletRepository,
        walletStorage: walletStorage,
      ),
    );
  }
}
