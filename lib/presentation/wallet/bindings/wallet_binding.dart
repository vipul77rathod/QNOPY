import 'package:get/get.dart';

import '../../../data/wallet/repositories/wallet_repository.dart';
import '../../../data/wallet/storage/wallet_storage.dart';
import '../state/wallet_controller.dart';

class WalletBinding extends Bindings {
  WalletBinding({required this.repository, required this.storage});

  final WalletRepository repository;
  final WalletStorage storage;

  @override
  void dependencies() {
    Get.lazyPut<WalletController>(
      () => WalletController(repository: repository, storage: storage),
    );
  }
}
