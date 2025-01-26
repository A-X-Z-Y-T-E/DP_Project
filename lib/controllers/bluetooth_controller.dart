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

      // Show scanning dialog
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: const Dialog(
            backgroundColor: Color(0xFF2C2C2C),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.blue,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Scanning for devices...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      // Wait for 3.5 seconds before showing results
      await Future.delayed(const Duration(milliseconds: 3800));

      // Close the loading dialog
      Get.back();

      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Close the loading dialog if there's an error
      if (Get.isDialogOpen ?? false) Get.back();

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
