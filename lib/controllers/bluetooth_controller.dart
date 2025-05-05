import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final _heartRateHistory = <int>[].obs;
  final _timestamps = <DateTime>[].obs;

  // New health metrics
  final _hrv = 0.obs;
  final _hrvHistory = <int>[].obs;
  final _steps = 0.obs;
  final _fallDetected = false.obs;
  final _skinTemperature = 0.0.obs;

  // Sensor information
  final _sensorLocation = "Unknown".obs;
  final _hasContact = false.obs;

  // Add pulse waveform data property
  final _pulseWaveformData = <int>[].obs;
  List<int> get pulseWaveformData => _pulseWaveformData;

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
  List<int> get heartRateHistory => _heartRateHistory;
  List<DateTime> get timestamps => _timestamps;

  // New health metrics getters
  int get hrv => _hrv.value;
  List<int> get hrvHistory => _hrvHistory;
  int get steps => _steps.value;
  bool get fallDetected => _fallDetected.value;
  double get skinTemperature => _skinTemperature.value;

  // Sensor information getters
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
  // TX Power Level characteristic UUID
  final txPowerLevelCharUuid = Guid('00000010-0000-1000-8000-00805f9b34fb');

  // Service UUIDs
  final heartRateServiceUuid = Guid('0000180d-0000-1000-8000-00805f9b34fb');
  final heartRateCharUuid = Guid('00002a37-0000-1000-8000-00805f9b34fb');

  // Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UserController _userController = Get.find<UserController>();

  // Timer for periodic health data storage
  Timer? _storeDataTimer;

  @override
  void onInit() {
    super.onInit();
    // Initialize listeners
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults.value = results;
      update();
    });

    // Initialize with sample pulse data for development
    _pulseWaveformData.value = List.generate(56, (index) =>
        (128 + (40 * sin(index * 0.2))).toInt());

    // Start a timer to store health data every 5 minutes
    _storeDataTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isDeviceConnected()) {
        storeHealthData();
      }
    });
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
    _storeDataTimer?.cancel();
    _heartRateHistory.clear();
    _timestamps.clear();
    super.onClose();
  }

  // Helper method to show dialogs safely using post-frame callback
  Future<T?> _showDialog<T>(Widget dialog, {bool barrierDismissible = true}) {
    Completer<T?> completer = Completer<T?>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await Get.dialog<T>(
        dialog,
        barrierDismissible: barrierDismissible
      );
      completer.complete(result);
    });

    return completer.future;
  }

  Future<bool> checkPermissions() async {
    // Check if Bluetooth is supported
    if (!await FlutterBluePlus.isSupported) {
      print('Error: Bluetooth not supported on this device');
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
      final bool shouldRequest = await _showDialog<bool>(
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
        print('Permission required: Please grant permissions in Settings');
        await openAppSettings();
        return false;
      }
    }

    return await _checkServicesEnabled();
  }

  Future<bool> _checkServicesEnabled() async {
    // Check if Location is enabled
    if (!await Permission.location.serviceStatus.isEnabled) {
      _showDialog(
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
      _showDialog(
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

      // Use safe dialog method
      await _showDialog(
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
      print('Scan Error: Failed to scan: $e');
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

      // Use safe dialog method
      await _showDialog(
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
      print('Connection Error: Failed to connect: $e');
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
        _heartRateHistory.clear();
        _timestamps.clear();

        // Disconnect the device
        await _connectedDevice.value!.disconnect();

        // We're keeping the device reference but updating the state
        // instead of setting connectedDevice to null
        _deviceState.value = BluetoothConnectionState.disconnected;

        // Clear services and characteristics
        _characteristics.clear();
        _services.clear();
      }
    } catch (e) {
      print('Error: Failed to disconnect: $e');
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

  Future<List<int>> readCharacteristic(
      BluetoothCharacteristic characteristic) async {
    try {
      List<int> value = await characteristic.read();

      // Log the operation
      String logEntry = 'Reading characteristic value{characteristic: {id: ${characteristic.uuid}, serviceID: ${characteristic.serviceUuid}, name: , value: }}';
      print(logEntry);

      // Convert the value to different formats for display
      String hexValue = value.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join('-');

      // For known characteristics, try to interpret the data appropriately
      if (characteristic.uuid == heartRateCharUuid) {
        if (value.isNotEmpty) {
          int hr = value[1]; // For heart rate, usually the second byte contains the value
          print('Heart Rate: $hr BPM');
        }
      }

      print('Read value in hex: $hexValue');

      // No snackbar, just return the value
      return value;
    } catch (e) {
      print('Error reading characteristic: $e');
      return [];
    }
  }

  // Helper method to format characteristic values
  String formatCharacteristicValue(List<int> value, Guid uuid) {
    // Default format is hex
    String hexValue = value.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join('-');

    // Special formatting for TX POWER LEVEL characteristic (Pulse data)
    if (uuid.toString().toUpperCase().contains("00000010-0000-1000-8000-00805F9B34FB")) {
      // Process and store the pulse waveform data
      if (value.isNotEmpty) {
        _pulseWaveformData.value = List<int>.from(value);
        print('Received ${value.length} pulse waveform data points');
      }

      // Format exactly like in the images with 0000-XXXX pattern for display
      return value.map((e) => "0000-${e.toRadixString(16).padLeft(4, '0').toUpperCase()}").join('-');
    }

    // For heart rate measurements
    if (uuid == heartRateCharUuid && value.isNotEmpty) {
      // First byte contains flags
      final flags = value[0];
      // Check heart rate value format (bit 0)
      bool is16Bit = (flags & 0x1) == 0x1;

      // Get heart rate value based on format flag
      int hrValue;
      if (is16Bit && value.length >= 3) {
        hrValue = value[2] << 8 | value[1];
      } else if (value.length >= 2) {
        hrValue = value[1];
      } else {
        return "Invalid format";
      }

      return "$hrValue BPM";
    }

    return hexValue;
  }

  Future<void> writeCharacteristic(
      BluetoothCharacteristic characteristic, String data) async {
    try {
      await characteristic.write(utf8.encode(data));
      print('Data written to device: $data');
    } catch (e) {
      print('Failed to write to characteristic: $e');
    }
  }

  Future<void> subscribeToCharacteristic(
      BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);

      characteristic.lastValueStream.listen((value) {
        print('Notification: ${utf8.decode(value)}');
      });

      print('Subscribed to notifications for ${characteristic.uuid}');
    } catch (e) {
      print('Failed to subscribe: $e');
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

      print('LED Control: LED turned ${on ? 'ON' : 'OFF'}');
    } catch (e) {
      print('Error: Failed to control LED: $e');
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
          print('Button Press: Button pressed on device');
        }
      });

      print('Button Notifications: Listening for button presses');
    } catch (e) {
      print('Error: Failed to listen for button press: $e');
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

          // Get heart rate value
          final hr = value[1];
          _heartRate.value = hr;

          if (_heartRateHistory.length >= 20) {
            _heartRateHistory.removeAt(0);
          }
          _heartRateHistory.add(hr);
          _timestamps.add(DateTime.now());

          _saveHealthData(hr);
        }
      });
    } catch (e) {
      print('Error starting health monitoring: $e');
    }
  }

  Future<void> _saveHealthData(int heartRate) async {
    try {
      await _db
          .collection('users')
          .doc(_userController.username.value)
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
        'timestamp': Timestamp.now(),
      });
      print('Health data saved successfully to Firestore');
    } catch (e) {
      print('Error saving to Firestore: $e');
    }
  }

  // Method to store health data in Firestore
  Future<void> storeHealthData() async {
    try {
      // Skip if no user is logged in
      if (_userController.username.value.isEmpty) {
        print('No user logged in, skipping health data storage');
        return;
      }

      // Create a health reading with default values for null fields
      final healthReading = {
        'timestamp': Timestamp.now(),
        'hrv': _hrv.value, // Always include HRV (default is 0)
        'steps': _steps.value, // Default is 0
        'fallDetected': _fallDetected.value, // Default is false
        'skinTemperature': _skinTemperature.value > 0 ? _skinTemperature.value : 36.5, // Default to normal if 0
        'deviceId': _connectedDevice.value?.remoteId.str ?? 'unknown',
        'deviceName': _connectedDevice.value?.platformName ?? 'Unknown Device',
      };

      // Store in Firestore
      await _db
          .collection('users')
          .doc(_userController.username.value)
          .collection('health_readings')
          .add(healthReading);

      print('Health data stored successfully');
    } catch (e) {
      print('Error storing health data: $e');
    }
  }
}
