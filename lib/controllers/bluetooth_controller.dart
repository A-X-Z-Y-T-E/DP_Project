import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class BluetoothController extends GetxController {
  // Make scanResults observable
  final _scanResults = <ScanResult>[].obs;
  List<ScanResult> get scanResults => _scanResults;

  @override
  void onInit() {
    super.onInit();
    // Initialize listeners
    FlutterBluePlus.scanResults.listen((results) {
      _scanResults.value = results;
      update(); // Notify GetX to update the UI
    });
  }

  Future<void> requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  Future scanDevices() async {
    try {
      _scanResults.clear();
      await requestPermissions();

      if (!await FlutterBluePlus.isOn) {
        Get.snackbar(
          'Error',
          'Please turn on Bluetooth',
          backgroundColor: const Color(0xFF2C2C2C),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 8,
          icon: const Icon(Icons.error_outline, color: Colors.redAccent),
        );
        return;
      }

      Get.snackbar(
        'Scanning',
        'Searching for devices...',
        backgroundColor: const Color(0xFF2C2C2C),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
        icon: const Icon(Icons.search, color: Colors.blue),
        duration: const Duration(seconds: 2),
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      await Future.delayed(const Duration(seconds: 15));
      await FlutterBluePlus.stopScan();

      Get.snackbar(
        'Scan Complete',
        'Found ${_scanResults.length} devices',
        backgroundColor: const Color(0xFF2C2C2C),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
        icon: const Icon(Icons.bluetooth_searching, color: Colors.green),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: const Color(0xFF2C2C2C),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
        icon: const Icon(Icons.error_outline, color: Colors.redAccent),
      );
    }
  }
}
