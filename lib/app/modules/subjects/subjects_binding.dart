import 'package:get/get.dart';
import 'subjects_controller.dart';

class SubjectsBinding extends Bindings {
  @override
  void dependencies() { Get.lazyPut<SubjectsController>(() => SubjectsController()); }
}
