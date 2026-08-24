import 'package:get/get.dart';
import 'statistics_controller.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() { Get.lazyPut<HistoryController>(() => HistoryController()); }
}
