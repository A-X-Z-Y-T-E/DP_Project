import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
      print('Found ${results.length} devices'); // Debug print
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
      // Clear previous results
      _scanResults.clear();

      // Request permissions first
      await requestPermissions();

      // Check if Bluetooth is on
      if (!await FlutterBluePlus.isOn) {
        Get.snackbar('Error', 'Please turn on Bluetooth');
        return;
      }

      Get.snackbar('Scanning', 'Searching for devices...');

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      await Future.delayed(const Duration(seconds: 5));
      await FlutterBluePlus.stopScan();

      Get.snackbar('Scan Complete', 'Found ${_scanResults.length} devices');
    } catch (e) {
      print('Scan error: $e'); // Debug print
      Get.snackbar('Error', e.toString());
    }
  }
}
