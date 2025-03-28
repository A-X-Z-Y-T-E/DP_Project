import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:Vital_Monitor/views/device_details_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';

class BluetoothController extends GetxController {
  // Observable variables
  final _scanResults = <ScanResult>[].obs;
  final _connectedDevice = Rx<BluetoothDevice?>(null);
  final _isConnecting = false.obs;
  final _isScanning = false.obs;
  final _characteristics = <BluetoothCharacteristic>[].obs;
  final _services = <BluetoothService>[].obs;
  final _deviceState =
      Rx<BluetoothConnectionState>(BluetoothConnectionState.disconnected);

  // Health data observables
  final _heartRate = 0.obs;
  final _calories = 0.obs;
  final _heartRateHistory = <int>[].obs;
  final _calorieHistory = <int>[].obs;
  final _timestamps = <DateTime>[].obs;

  // Add these properties near the top with other observables
  final _sensorLocation = "Unknown".obs;
  final _hasContact = false.obs;

  // Getters
  List<ScanResult> get scanResults => _scanResults;
  BluetoothDevice? get connectedDevice => _connectedDevice.value;
  bool get isConnecting => _isConnecting.value;
  bool get isScanning => _isScanning.value;
  List<BluetoothCharacteristic> get characteristics => _characteristics;
  List<BluetoothService> get services => _services;
  BluetoothConnectionState get deviceState => _deviceState.value;

  // Health data getters
  int get heartRate => _heartRate.value;
  int get calories => _calories.value;
  List<int> get heartRateHistory => _heartRateHistory;
  List<int> get calorieHistory => _calorieHistory;
  List<DateTime> get timestamps => _timestamps;

  // Add these getters with other getters
  String get sensorLocation => _sensorLocation.value;
  bool get hasContact => _hasContact.value;

  // Subscriptions
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;

  // P2P Service UUID for STM devices
  final p2pServiceUuid = Guid('0000fe40-cc7a-482a-984a-7f2ed5b3e58f');
  // LED characteristic UUID
  final ledCharUuid = Guid('0000fe41-8e22-4541-9d4c-21edae82ed19');
  // Button characteristic UUID
  final buttonCharUuid = Guid('0000fe42-8e22-4541-9d4c-21edae82ed19');

  // Service UUIDs
  final heartRateServiceUuid = Guid('0000180d-0000-1000-8000-00805f9b34fb');
  final heartRateCharUuid = Guid('00002a37-0000-1000-8000-00805f9b34fb');
  final calorieCharUuid = Guid('00002a3f-0000-1000-8000-00805f9b34fb');

  // Firebase instance
  final _db = FirebaseFirestore.instance;
  final userController = Get.find<UserController>();

  @override
  void onInit() {
    super.onInit();
    // Initialize listeners
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults.value = results;
      update();
    });
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
    _heartRateHistory.clear();
    _calorieHistory.clear();
    _timestamps.clear();
    super.onClose();
  }

  Future<bool> checkPermissions() async {
    // Check if Bluetooth is supported
    if (!await FlutterBluePlus.isSupported) {
      Get.snackbar('Error', 'Bluetooth not supported on this device',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }

    // First check existing permissions
    final locationStatus = await Permission.location.status;
    final bluetoothStatus = await Permission.bluetoothScan.status;

    // If permissions are already granted, check if services are enabled
    if (locationStatus.isGranted && bluetoothStatus.isGranted) {
      return await _checkServicesEnabled();
    }

    // If permissions were previously denied, show settings dialog
    if (locationStatus.isDenied || bluetoothStatus.isDenied) {
      final bool shouldRequest = await Get.dialog<bool>(
            AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: const Text('Permissions Required',
                  style: TextStyle(color: Colors.white)),
              content: const Text(
                  'This app needs Bluetooth and Location permissions to function properly. Would you like to grant them?',
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text('NOT NOW',
                      style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text('CONTINUE',
                      style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ) ??
          false;

      if (!shouldRequest) return false;

      // Request permissions if user agrees
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses.values.any((status) => !status.isGranted)) {
        Get.snackbar(
          'Permission Required',
          'Please grant permissions in Settings',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          mainButton: TextButton(
            onPressed: () => openAppSettings(),
            child:
                const Text('SETTINGS', style: TextStyle(color: Colors.white)),
          ),
        );
        return false;
      }
    }

    return await _checkServicesEnabled();
  }

  Future<bool> _checkServicesEnabled() async {
    // Check if Location is enabled
    if (!await Permission.location.serviceStatus.isEnabled) {
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Location Required',
              style: TextStyle(color: Colors.white)),
          content: const Text('Please enable Location services',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                openAppSettings();
              },
              child:
                  const Text('SETTINGS', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
      return false;
    }

    // Check if Bluetooth is enabled
    if (!await FlutterBluePlus.isOn) {
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Bluetooth Required',
              style: TextStyle(color: Colors.white)),
          content: const Text('Please enable Bluetooth',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Get.back();
                try {
                  await FlutterBluePlus.turnOn();
                } catch (e) {
                  openAppSettings();
                }
              },
              child:
                  const Text('TURN ON', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> startScan() async {
    if (!await checkPermissions()) return;

    try {
      _scanResults.clear();
      _isScanning.value = true;

      // Show scanning dialog
      Get.dialog(
        PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF2C2C2C),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Scanning for STM devices...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      stopScan();
                      Get.back();
                    },
                    child: const Text('CANCEL',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Start scan with filters for STM devices
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [], // Add specific service UUIDs if known
        // Filter for STM devices if needed
        // scanMode: ScanMode.lowLatency,
      );

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 4));

      // Close dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      _isScanning.value = false;
    } catch (e) {
      _isScanning.value = false;
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Scan Error',
        'Failed to scan: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _isScanning.value = false;
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (!await checkPermissions()) return;

    try {
      _isConnecting.value = true;
      _connectedDevice.value = device;

      // Show connecting dialog
      Get.dialog(
        PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF2C2C2C),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Connecting to ${device.platformName.isEmpty ? 'Unknown Device' : device.platformName}...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Get.back();
                      _isConnecting.value = false;
                    },
                    child: const Text('CANCEL',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      await device.connect();

      _stateSubscription?.cancel();
      _stateSubscription = device.state.listen((state) {
        _deviceState.value = state;
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice.value = null;
          _characteristics.clear();
          _services.clear();
        }
      });

      // Discover services
      await discoverServices();

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      _isConnecting.value = false;

      // Instead of showing a snackbar, navigate to the device details page
      Get.off(() => DeviceDetailsPage(device: device));
    } catch (e) {
      _isConnecting.value = false;
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Connection Error',
        'Failed to connect: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> disconnectDevice() async {
    try {
      if (_connectedDevice.value != null) {
        // Cancel all notifications and subscriptions
        for (var service in _services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.notify ||
                characteristic.properties.indicate) {
              await characteristic.setNotifyValue(false);
            }
          }
        }

        // Clear all histories and reset values
        _heartRate.value = 0;
        _calories.value = 0;
        _heartRateHistory.clear();
        _calorieHistory.clear();
        _timestamps.clear();

        // Disconnect the device
        await _connectedDevice.value!.disconnect();
        _connectedDevice.value = null;
        _characteristics.clear();
        _services.clear();

        Get.snackbar(
          'Disconnected',
          'Device disconnected',
          backgroundColor: const Color(0xFF2C2C2C),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to disconnect: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> discoverServices() async {
    if (_connectedDevice.value == null) return;

    try {
      List<BluetoothService> services =
          await _connectedDevice.value!.discoverServices();
      _services.value = services;

      List<BluetoothCharacteristic> chars = [];
      for (var service in services) {
        chars.addAll(service.characteristics);
      }
      _characteristics.value = chars;

      print(
          'Discovered ${services.length} services and ${chars.length} characteristics');
    } catch (e) {
      print('Error discovering services: $e');
    }
  }

  Future<void> readCharacteristic(
      BluetoothCharacteristic characteristic) async {
    try {
      List<int> value = await characteristic.read();
      print('Read value: ${utf8.decode(value)}');

      Get.snackbar(
        'Read Value',
        'Value: ${utf8.decode(value)}',
        backgroundColor: const Color(0xFF2C2C2C),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to read characteristic: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> writeCharacteristic(
      BluetoothCharacteristic characteristic, String data) async {
    try {
      await characteristic.write(utf8.encode(data));

      Get.snackbar(
        'Write Success',
        'Data written to device',
        backgroundColor: Colors.green.withOpacity(0.7),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to write to characteristic: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> subscribeToCharacteristic(
      BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);

      characteristic.lastValueStream.listen((value) {
        print('Notification: ${utf8.decode(value)}');
      });

      Get.snackbar(
        'Subscribed',
        'Listening for notifications',
        backgroundColor: const Color(0xFF2C2C2C),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to subscribe: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  bool isDeviceConnected() {
    return _connectedDevice.value != null &&
        _deviceState.value == BluetoothConnectionState.connected;
  }

  // Method to toggle LED
  Future<void> toggleLed(bool on) async {
    try {
      // Find P2P service
      final service = _services.firstWhere(
        (s) => s.uuid == p2pServiceUuid,
        orElse: () => throw Exception('P2P service not found'),
      );

      // Find LED characteristic
      final ledChar = service.characteristics.firstWhere(
        (c) => c.uuid == ledCharUuid,
        orElse: () => throw Exception('LED characteristic not found'),
      );

      // Write value to turn LED on/off
      await ledChar.write([on ? 0x01 : 0x00]);

      Get.snackbar(
        'LED Control',
        on ? 'LED turned ON' : 'LED turned OFF',
        backgroundColor: on ? Colors.green : Colors.grey,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to control LED: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Method to listen for button press
  Future<void> listenForButtonPress() async {
    try {
      // Find P2P service
      final service = _services.firstWhere(
        (s) => s.uuid == p2pServiceUuid,
        orElse: () => throw Exception('P2P service not found'),
      );

      // Find Button characteristic
      final buttonChar = service.characteristics.firstWhere(
        (c) => c.uuid == buttonCharUuid,
        orElse: () => throw Exception('Button characteristic not found'),
      );

      // Subscribe to notifications
      await buttonChar.setNotifyValue(true);

      buttonChar.lastValueStream.listen((value) {
        if (value.isNotEmpty && value[0] == 0x01) {
          Get.snackbar(
            'Button Press',
            'Button pressed on device',
            backgroundColor: Colors.blue,
            colorText: Colors.white,
          );
        }
      });

      Get.snackbar(
        'Button Notifications',
        'Listening for button presses',
        backgroundColor: const Color(0xFF2C2C2C),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to listen for button press: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Method to check if device has P2P service
  bool hasP2PService() {
    return _services.any((s) => s.uuid == p2pServiceUuid);
  }

  // Helper method to determine sensor location
  String _getSensorLocation(int locationByte) {
    switch (locationByte) {
      case 0:
        return "Other";
      case 1:
        return "Chest";
      case 2:
        return "Wrist";
      case 3:
        return "Finger";
      case 4:
        return "Hand";
      case 5:
        return "Ear Lobe";
      case 6:
        return "Foot";
      default:
        return "Position not identified";
    }
  }

  Future<void> startHealthMonitoring() async {
    try {
      final service = _services.firstWhere(
        (s) => s.uuid == heartRateServiceUuid,
        orElse: () => throw Exception('Heart Rate service not found'),
      );

      // Find heart rate characteristic
      final heartRateChar = service.characteristics.firstWhere(
        (c) => c.uuid == heartRateCharUuid,
        orElse: () => throw Exception('Heart Rate characteristic not found'),
      );

      // Try to find the sensor location characteristic first
      try {
        final sensorLocationChar = service.characteristics.firstWhere(
            (c) => c.uuid == Guid('00002a38-0000-1000-8000-00805f9b34fb'));
        final locationData = await sensorLocationChar.read();
        if (locationData.isNotEmpty) {
          _sensorLocation.value = _getSensorLocation(locationData[0]);
        } else {
          _sensorLocation.value = "Position not identified";
        }
      } catch (e) {
        print('Could not determine sensor position: $e');
        _sensorLocation.value = "Position not identified";
      }

      // Subscribe to heart rate notifications
      await heartRateChar.setNotifyValue(true);
      heartRateChar.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          // First byte contains flags
          final flags = value[0];

          // Check sensor contact status (bits 1-2)
          final contactBits = (flags >> 1) & 0x3;
          _hasContact.value = contactBits == 0x3; // 0x3 means contact detected

          // Get heart rate value from second byte
          final hr = value[1];
          _heartRate.value = hr;

          if (_heartRateHistory.length >= 20) {
            _heartRateHistory.removeAt(0);
          }
          _heartRateHistory.add(hr);
          _timestamps.add(DateTime.now());

          // Parse calorie data from the characteristic value
          // Format: 1f48005200 where 52 is the calorie value (4th byte)
          String hexValue =
              value.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
          print('Received hex value: $hexValue');

          if (value.length >= 4) {
            // The calorie value is in the fourth byte (index 3)
            int calorieValue =
                value[3]; // Get the fourth byte (52 in the example)
            print('Raw calorie value: $calorieValue');

            // Store the raw value
            _calories.value = calorieValue;
            if (_calorieHistory.length >= 20) {
              _calorieHistory.removeAt(0);
            }
            _calorieHistory.add(calorieValue);
            print('Current calorie history: $_calorieHistory');
          }

          _saveHealthData(_heartRate.value, _calories.value);
        }
      });
    } catch (e) {
      print('Error starting health monitoring: $e');
      Get.snackbar(
        'Error',
        'Failed to start health monitoring: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _saveHealthData(int heartRate, int calories) async {
    try {
      await _db
          .collection('users')
          .doc(userController.username.value)
          .collection('health_readings')
          .add({
        'heartRate': heartRate,
        'spo2': 98, // Default value, update when available
        'temperature': 37.2, // Default value, update when available
        'bloodPressure': {
          'systolic': 120, // Default value, update when available
          'diastolic': 80, // Default value, update when available
        },
        'bloodSugar': 95, // Default value, update when available
        'calories': calories,
        'timestamp': Timestamp.now(),
      });
      print('Health data saved successfully to Firestore');
    } catch (e) {
      print('Error saving to Firestore: $e');
    }
  }
}
