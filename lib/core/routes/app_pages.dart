
import 'package:get/get.dart';

import '../../data/kyc/repositories/kyc_repository.dart';
import '../../data/wallet/repositories/wallet_repository.dart';
import '../../data/wallet/storage/wallet_storage.dart';
import '../../presentation/home/home.dart';
import '../../presentation/kyc/bindings/kyc_binding.dart';
import '../../presentation/kyc/pages/kyc_page.dart';
import '../../presentation/wallet/bindings/wallet_binding.dart';
import '../../presentation/wallet/pages/wallet_home_page.dart';
import '../../presentation/wallet/pages/wallet_top_up_page.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static List<GetPage<dynamic>> pages({
    required KycRepository kycRepository,
    required WalletRepository walletRepository,
    required WalletStorage walletStorage,
  }) {
    return [
      GetPage<dynamic>(
        name: AppRoutes.home,
        page: () => const Home(),
      ),
      GetPage<dynamic>(
        name: AppRoutes.wallet,
        page: () => const WalletHomePage(),
        binding: WalletBinding(
          repository: walletRepository,
          storage: walletStorage,
        ),
      ),
      GetPage<dynamic>(
        name: AppRoutes.kyc,
        page: () => const KycPage(),
        binding: KycBinding(
          repository: kycRepository,
        ),
      ),
      GetPage<dynamic>(
        name: AppRoutes.walletTopUp,
        page: () => const WalletTopUpPage(),
      ),
    ];
  }
}
