import 'package:get/get.dart';
import 'package:qnopy/data/kyc/repositories/kyc_repository.dart' show KycRepository;
import '../state/kyc_controller.dart';

class KycBinding extends Bindings {
  KycBinding({required this.repository});
  final KycRepository repository;
  @override
  void dependencies() {
    Get.put<KycController>(KycController(repository: repository), permanent: true);
  }
}
