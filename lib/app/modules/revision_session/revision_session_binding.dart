import 'package:get/get.dart';
import 'revision_session_controller.dart';

class RevisionSessionBinding extends Bindings {
  @override
  void dependencies() { Get.lazyPut<RevisionSessionController>(() => RevisionSessionController()); }
}
