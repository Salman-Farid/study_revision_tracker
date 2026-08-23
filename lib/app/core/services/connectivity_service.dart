import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final isConnected = true.obs;
  late StreamSubscription<List<ConnectivityResult>> _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      isConnected.value = results.any((r) => r != ConnectivityResult.none);
    });
  }

  @override
  void onClose() { _sub.cancel(); super.onClose(); }
}
