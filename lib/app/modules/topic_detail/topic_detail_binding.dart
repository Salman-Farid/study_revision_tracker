import 'package:get/get.dart';
import 'topic_detail_controller.dart';

class TopicDetailBinding extends Bindings {
  @override
  void dependencies() { Get.lazyPut<TopicDetailController>(() => TopicDetailController()); }
}
