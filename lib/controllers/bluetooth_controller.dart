import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data'; // Added for ByteData, Endian, Uint8List if not already present

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

  // Add these properties to track scan performance and status
  final _scanStartTime = DateTime.now().obs;
  final _isTimeoutDialogShown = false.obs;
  final _scannedDevicesCount = 0.obs;
  int get scannedDevicesCount => _scannedDevicesCount.value;

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
  // Fall detection characteristic UUID (seen in the image)
  final fallDetectionCharUuid = Guid('00000001-8e22-4541-9d4c-21edae82ed19');

  // Service UUIDs
  final heartRateServiceUuid = Guid('0000180d-0000-1000-8000-00805f9b34fb');
  final heartRateCharUuid = Guid('00002a37-0000-1000-8000-00805f9b34fb');

  // Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UserController _userController = Get.find<UserController>();

  // Timer for periodic health data storage
  Timer? _storeDataTimer;

  // Add Firebase initialization check and debug method
  Future<bool> _checkFirebaseInitialization() async {
    print('🔥 Checking Firebase initialization status...');
    try {
      // Test Firebase connection by attempting a simple operation
      await _db.collection('_test_connection').get();
      print('✅ Firebase connection successful');
      return true;
    } catch (e) {
      print('❌ Firebase connection error: ${e.toString()}');
      
      // Try to diagnose the issue based on the error message
      String errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('permission-denied') || errorMsg.contains('permission denied')) {
        print('🔐 Firebase security rules are preventing access. Check your Firestore rules.');
      } else if (errorMsg.contains('network') || errorMsg.contains('connection')) {
        print('🌐 Network connection issue. Check internet connectivity.');
      } else if (errorMsg.contains('not initialized') || errorMsg.contains('app-not-initialized')) {
        print('🔧 Firebase not properly initialized. Check Firebase setup in main.dart');
      } else if (errorMsg.contains('not-found')) {
        print('📂 Collection or document not found. This may be normal for the test collection.');
      }
      
      return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    
    // Check Firebase initialization first thing
    _checkFirebaseInitialization().then((isInitialized) {
      if (!isInitialized) {
        print('⚠️ Warning: Firebase may not work correctly. Data saving might fail.');
      }
    });
    
    // Initialize listeners
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults.value = results;
      update();
    });

    // Set up the timer with more verbose logging
    _storeDataTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      print('⏱️ Timer fired: Periodic health data storage (every 5 minutes)');
      if (isDeviceConnected()) {
        print('📱 Device is connected - proceeding with data storage');
        _saveHealthData(heartRate); 
      } else {
        print('📱 Device is NOT connected - skipping data storage');
      }
    });
    
    // Add a one-time initial save attempt after a delay
    Future.delayed(Duration(seconds: 15), () {
      print('⏱️ Initial save attempt after 15 seconds delay');
      if (isDeviceConnected()) {
        _saveHealthData(heartRate);
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
      _showDialog(
        AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Bluetooth Not Supported', style: TextStyle(color: Colors.white)),
          content: const Text('This device does not support Bluetooth.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('OK', style: TextStyle(color: Colors.blue))),
          ],
        ),
      );
      return false;
    }

    // Get current permission statuses
    final locationStatus = await Permission.location.status;
    final bluetoothScanStatus = await Permission.bluetoothScan.status;
    final bluetoothConnectStatus = await Permission.bluetoothConnect.status; // Also check connect permission

    // If all necessary permissions are already granted, check if services are enabled
    if (locationStatus.isGranted && bluetoothScanStatus.isGranted && bluetoothConnectStatus.isGranted) {
      return await _checkServicesEnabled();
    }

    // Handle permanently denied permissions first
    if (locationStatus.isPermanentlyDenied || bluetoothScanStatus.isPermanentlyDenied || bluetoothConnectStatus.isPermanentlyDenied) {
      print('Permissions permanently denied. Directing to settings.');
      await _showDialog<void>(
        AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Permissions Required', style: TextStyle(color: Colors.white)),
          content: const Text(
              'This app requires Bluetooth and Location permissions to function. Location is needed by Android to allow Bluetooth scanning. Please enable them in app settings.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
            TextButton(
                onPressed: () {
                  Get.back();
                  openAppSettings();
                },
                child: const Text('OPEN SETTINGS', style: TextStyle(color: Colors.blue))),
          ],
        ),
      );
      return false;
    }

    // If permissions are denied (but not permanently) or not yet determined, ask the user
    // This dialog explains why permissions are needed before the system dialog appears.
    final bool? shouldRequest = await _showDialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Permissions Required', style: TextStyle(color: Colors.white)),
        content: const Text(
            'This app needs Bluetooth and Location permissions. Location permission is required by Android to allow Bluetooth scanning, even if this app does not use your GPS location directly. Would you like to grant them?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('NOT NOW', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('CONTINUE', style: TextStyle(color: Colors.blue))),
        ],
      ),
    );

    if (shouldRequest != true) {
      print('User declined to grant permissions via pre-dialog.');
      return false; // User chose "NOT NOW"
    }

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Permission.bluetooth, // Optional: for older Android versions if not covered by above
    ].request();

    // Check statuses after request
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
        print('${permission.toString()} was not granted. Status: $status');
      }
    });

    if (!allGranted) {
      print('One or more permissions were not granted after request.');
      // Optionally, show another dialog explaining that settings need to be checked if still denied.
      // This is especially relevant if a permission was denied (not permanently) during the system prompt.
      await _showDialog<void>(
        AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Permissions Still Required', style: TextStyle(color: Colors.white)),
          content: const Text(
              'Some permissions were not granted. Location is needed by Android for Bluetooth scanning. Please check app settings to enable them for full functionality.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('LATER', style: TextStyle(color: Colors.grey))),
            TextButton(
                onPressed: () {
                  Get.back();
                  openAppSettings();
                },
                child: const Text('OPEN SETTINGS', style: TextStyle(color: Colors.blue))),
          ],
        ),
      );
      return false;
    }

    // If all permissions are granted, proceed to check if services (like GPS, Bluetooth adapter) are enabled
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
      _scanStartTime.value = DateTime.now();
      _scannedDevicesCount.value = 0;
      _isTimeoutDialogShown.value = false;

      // Start the scan before showing dialog to prevent delays
      FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [], // Add specific service UUIDs if known
      );

      // Set up a listener to track the number of devices found
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults.value = results;
        _scannedDevicesCount.value = results.length;
        update();
      });

      // Use safe dialog method - improved with progress tracking
      await _showDialog(
        PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              // Setup a periodic timer to update the dialog
              Future.delayed(const Duration(milliseconds: 500), () {
                if (context.mounted) setState(() {});
              });

              // Calculate elapsed time
              final elapsedSeconds = DateTime.now().difference(_scanStartTime.value).inSeconds;
              
              // Check if scan is taking too long with no results
              if (elapsedSeconds > 8 && _scanResults.isEmpty && !_isTimeoutDialogShown.value) {
                _isTimeoutDialogShown.value = true;
                
                // Schedule showing a helpful message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showScanningTipDialog();
                });
              }
              
              return Dialog(
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
                        'Scanning for devices...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Found ${_scannedDevicesCount.value} device${_scannedDevicesCount.value == 1 ? "" : "s"}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan time: $elapsedSeconds seconds',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              stopScan();
                              Get.back();
                            },
                            child: const Text('CANCEL',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // Keep the results, but close the dialog
                              Get.back();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            child: const Text('SHOW RESULTS'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }
          ),
        ),
        barrierDismissible: false,
      );

      _isScanning.value = false;
    } catch (e) {
      _isScanning.value = false;
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      print('Scan Error: Failed to scan: $e');
    }
  }

  void _showScanningTipDialog() {
    // Only show the dialog if we're still scanning and the scan dialog is open
    if (!_isScanning.value || !(Get.isDialogOpen ?? false)) {
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          'Scanning Tips',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'If scanning is taking too long:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text(
              '• Make sure Bluetooth is turned on',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              '• Check that the device is powered on and nearby',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              '• Some devices only advertise periodically to save power',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              '• Try restarting your Bluetooth',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('GOT IT', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
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

      // Start connecting before showing dialog
      // This fixes the issue where device only connects on "Cancel" press
      final Future<void> connectionFuture = device.connect();

      // Show dialog while connecting
      _showDialog(
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

      // Wait for connection to complete
      await connectionFuture;

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

      // Delay a bit before closing the dialog to ensure connection is established
      await Future.delayed(Duration(milliseconds: 300));
      
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      _isConnecting.value = false;

      // Navigate to device details page
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

  // Modified to use raw data without scaling, and parse steps/temp from a list of 4-byte values
  void updatePulseWaveform(List<int> rawBytes) {
    if (rawBytes.isEmpty) return;

    print('Processing raw data. Total bytes received: ${rawBytes.length}');

    // Convert all received bytes into a list of 4-byte integer values (big-endian)
    final allIntegerValues = <int>[];
    for (int i = 0; i < rawBytes.length; i += 4) {
      if (i + 3 < rawBytes.length) {
        // Using big-endian format: first byte is most significant
        int value = (rawBytes[i] << 24) |
                    (rawBytes[i+1] << 16) |
                    (rawBytes[i+2] << 8)  |
                    rawBytes[i+3];
        allIntegerValues.add(value);
      } else {
        // Log if there are trailing bytes not forming a full 4-byte value.
        print('Trailing bytes detected: ${rawBytes.length - i} bytes. Not processed into an integer value.');
        break; // Stop processing if a full 4-byte chunk isn't available
      }
    }
    print('Converted raw bytes into ${allIntegerValues.length} integer values.');

    // 1. Process Pulse Waveform Data (first 56 integer values)
    final processedWaveformData = <int>[];
    if (allIntegerValues.isNotEmpty) {
      // Take up to the first 56 values for the waveform
      processedWaveformData.addAll(allIntegerValues.take(56));
    }
    
    // Pad with zeros if fewer than 56 values were extracted for the waveform
    while (processedWaveformData.length < 56) {
      processedWaveformData.add(0);
    }
    // Ensure exactly 56 values for the waveform (take(56) should handle this, but as a safeguard)
    if (processedWaveformData.length > 56) {
       processedWaveformData.length = 56;
    }

    if (!_areListsEqual(_pulseWaveformData, processedWaveformData)) {
      _pulseWaveformData.value = List<int>.from(processedWaveformData);
      print('Updated pulse waveform with ${processedWaveformData.length} data points.');
    }

    // 2. Process Step Count (the 57th integer value, which is at index 56)
    if (allIntegerValues.length >= 57) {
      try {
        int stepsValue = allIntegerValues[56]; // 57th value is at index 56
        _steps.value = stepsValue;
        print('Updated steps from 57th value: $stepsValue');
      } catch (e) {
        // This catch might be redundant if length check is robust, but good for safety.
        print('Error processing step count from 57th value (index 56): $e');
      }
    } else {
      print('Not enough integer values for step count. Found ${allIntegerValues.length} values, need at least 57.');
    }

    // 3. Process Skin Temperature (the 58th integer value, which is at index 57)
    if (allIntegerValues.length >= 58) {
      try {
        int tempIntValue = allIntegerValues[57]; // 58th value is at index 57
        
        // Convert to double, assuming the integer value needs to be divided by 100.0
        // Example: if device sends 3650, this becomes 36.50 C.
        // Adjust divisor if device sends temperature scaled differently (e.g., by 10).
        double tempValue = tempIntValue / 100.0; 
        
        _skinTemperature.value = tempValue;
        print('Updated skin temperature from 58th value: ${tempValue.toStringAsFixed(2)}°C (raw int: $tempIntValue)');
      } catch (e) {
        // This catch might be redundant if length check is robust.
        print('Error processing skin temperature from 58th value (index 57): $e');
      }
    } else {
      print('Not enough integer values for skin temperature. Found ${allIntegerValues.length} values, need at least 58.');
    }
    
    // Values after the 58th integer value (i.e., after 58*4 = 232 bytes) are ignored.
  }

  // Helper method to check if two lists have the same content
  bool _areListsEqual(RxList<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  // Add this method to stop any simulation that might be running
  void stopSimulation() {
    // This is just a placeholder since we're using real device data now
    // but needed to maintain compatibility with existing code
    print('Real-time data mode active - using only hardware device data');
  }

  // Helper method to format characteristic values to match STM toolbox
  String formatCharacteristicValue(List<int> value, Guid uuid) {
    // Special formatting for TX POWER LEVEL characteristic (Pulse data) (0010)
    if (uuid.toString().toUpperCase().contains("00000010-0000-1000-8000-00805F9B34FB")) {
      // Process and store the pulse waveform data
      if (value.isNotEmpty) {
        // Update the pulse waveform data efficiently with actual device data
        updatePulseWaveform(value);
        
        // Format the display string in 4-byte chunks to show the actual binary values
        StringBuffer formattedValue = StringBuffer();
        for (int i = 0; i < value.length; i += 4) {
          if (i + 3 < value.length) {
            // Combine 4 bytes to make a 32-bit value (4-byte format)
            int combinedValue = (value[i] << 24) | (value[i+1] << 16) | 
                               (value[i+2] << 8) | value[i+3];
                               
            // Format as 8-character hex value (representing 4 bytes)
            String hexChunk = combinedValue.toRadixString(16).padLeft(8, '0').toUpperCase();
            formattedValue.write(hexChunk);
            
            // Add a dash between values (except after the last one)
            if (i + 4 < value.length) {
              formattedValue.write('-');
            }
          }
        }
        
        // Print to console for debugging/monitoring
        print('0010 characteristic value (4-byte format): ${formattedValue.toString().substring(0, math.min(100, formattedValue.length))}...');
        
        return formattedValue.toString();
      }
    } else {
      // Format all other characteristics in 4-byte chunks as well for consistency
      if (value.isNotEmpty) {
        StringBuffer formattedValue = StringBuffer();
        
        for (int i = 0; i < value.length; i += 4) {
          if (i + 3 < value.length) {
            // Group into 4-byte chunks
            int combinedValue = (value[i] << 24) | (value[i+1] << 16) | (value[i+2] << 8) | value[i+3];
            String hexChunk = combinedValue.toRadixString(16).padLeft(8, '0').toUpperCase();
            formattedValue.write(hexChunk);
          } else {
            // Remaining bytes (if not divisible by 4)
            for (int j = i; j < value.length; j++) {
              formattedValue.write(value[j].toRadixString(16).padLeft(2, '0').toUpperCase());
            }
          }
          
          // Add a dash between groups (except after the last one)
          if (i + 4 < value.length) {
            formattedValue.write('-');
          }
        }
        
        return formattedValue.toString();
      }
    }

    // For heart rate measurements with special formatting
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

    // If we got here and value is empty, return default
    if (value.isEmpty) {
      return "00";
    }
    
    // This shouldn't happen with the new logic, but keeping as a fallback
    return value.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join('-');
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

  Future<void> startFallDetectionMonitoring() async {
    try {
      print('Starting fall detection monitoring...');
      
      // Try to find the fall detection characteristic across all services
      BluetoothCharacteristic? fallDetectionChar;
      for (var service in _services) {
        try {
          fallDetectionChar = service.characteristics.firstWhere(
            (c) => c.uuid == fallDetectionCharUuid,
          );
          
          if (fallDetectionChar != null) {
            print('Found fall detection characteristic in service: ${service.uuid}');
            break;
          }
        } catch (e) {
          // Characteristic not found in this service, continue searching
        }
      }
      
      if (fallDetectionChar == null) {
        print('Warning: Fall detection characteristic not found in any service');
        
        // Try with string comparison as fallback (in case UUID comparison has issues)
        for (var service in _services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains('00000001-8e22-4541-9d4c-21edae82ed19')) {
              fallDetectionChar = characteristic;
              print('Found fall detection characteristic via string comparison');
              break;
            }
          }
          if (fallDetectionChar != null) break;
        }
      }
      
      if (fallDetectionChar == null) {
        print('Error: Could not find fall detection characteristic');
        return;
      }
      
      // Subscribe to fall detection notifications
      print('Enabling notifications for fall detection characteristic');
      await fallDetectionChar.setNotifyValue(true);
      
      fallDetectionChar.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          print('Received fall detection value: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join('-')}');
          
          bool fallDetected = false;
          
          // Modified logic: fall is detected if value is not 0x00
          // Only consider "no fall" if the value is exactly 0x00
          if (value.length >= 1) {
            // Check if all bytes are 0x00
            bool allZeros = true;
            for (int byte in value) {
              if (byte != 0x00) {
                allZeros = false;
                break;
              }
            }
            
            // Fall is detected if we have any non-zero value
            fallDetected = !allZeros;
            
            if (fallDetected) {
              print('⚠️ FALL DETECTED! Value: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join('-')} ⚠️');
              
              // Show alert dialog when fall is detected
              if (Get.context != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showFallDetectionAlert();
                });
              }
            } else {
              print('No fall detected (all zeros in reading)');
            }
            
            // Update the fallDetected state
            if (_fallDetected.value != fallDetected) {
              _fallDetected.value = fallDetected;
              
              // If a fall was detected, save health data immediately
              if (fallDetected) {
                print('Saving health data due to fall detection');
                _saveHealthData(heartRate);
              }
              
              // Force UI update
              update();
            }
          }
        }
      });
      
      print('Successfully set up fall detection monitoring');
    } catch (e) {
      print('Error setting up fall detection monitoring: $e');
    }
  }
  
  void showFallDetectionAlert() {
    // Only show if not already showing a dialog
    if (!(Get.isDialogOpen ?? false)) {
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Fall Detected!', 
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'A fall has been detected. This indicates the user may have fallen and might need assistance.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Mark as resolved (turn off fall detection)
                updateFallDetection(false);
                saveHealthData();
                Get.back(); 
              },
              child: const Text('MARK AS RESOLVED', style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('CLOSE', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
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

      // Start fall detection monitoring in addition to heart rate
      await startFallDetectionMonitoring();
      
    } catch (e) {
      print('Error starting health monitoring: $e');
    }
  }

  // Modified method to add more debug info and save testing
  Future<void> _saveHealthData(int heartRate) async {
    print('🔍 Attempting to save health data - Start debugging sequence');
    
    try {
      // Check if user is logged in
      if (_userController.username.value.isEmpty) {
        print('❌ ERROR: No user logged in, username is empty - cannot save to Firestore');
        return;
      }
      
      print('👤 User logged in: ${_userController.username.value}');

      // Check if we have proper data to save
      if (_pulseWaveformData.isEmpty) {
        print('⚠️ WARNING: No waveform data to save. Will use empty array.');
      }

      // Check device connection
      print('📱 Device connection state: ${_deviceState.value}');
      print('📱 Device connected? ${isDeviceConnected()}');
      
      // Check Firebase connectivity first (bypass if we know it's failing)
      bool firebaseAvailable = await _checkFirebaseInitialization();
      if (!firebaseAvailable) {
        print('⚠️ WARNING: Firebase connection issues detected. Attempting fallback save method...');
        // In a real app, you might save locally here using shared preferences or SQLite
        // But for now we'll continue and at least try to save
      }
      
      // Get the current timestamp
      final currentTimestamp = Timestamp.now();
      final DateTime currentTime = currentTimestamp.toDate();
      
      // Create a health reading with the new schema
      final healthReading = {
        'timestamp': currentTimestamp,
        // Convert waveform data to a more compatible format (list of integers as strings)
        // This helps avoid serialization issues with large integer arrays
        'waveformData': _pulseWaveformData.map((value) => value.toString()).toList(),
        'steps': _steps.value,
        'skinTemperature': _skinTemperature.value > 0 ? _skinTemperature.value : 36.5,
        'fallDetected': _fallDetected.value, // Updated to use the actual fall detection status
        'deviceId': _connectedDevice.value?.remoteId.str ?? 'unknown',
        'deviceName': _connectedDevice.value?.platformName ?? 'Unknown Device',
      };

      // Debug print before storing
      print('========= FIRESTORE STORAGE - START =========');
      print('Storing health data to Firestore at ${currentTime.toString()}');
      print('Username: ${_userController.username.value}');
      print('Steps: ${_steps.value}');
      print('Temperature: ${_skinTemperature.value > 0 ? _skinTemperature.value : 36.5}°C');
      print('Fall Detected: ${_fallDetected.value}'); // Add fall detection to debug logs 
      print('Device: ${_connectedDevice.value?.platformName ?? 'Unknown Device'} (${_connectedDevice.value?.remoteId.str ?? 'unknown'})');
      print('Waveform data points: ${_pulseWaveformData.length} (converted to strings for compatibility)');
      
      try {
        print('⏱️ Attempting immediate Firestore save with simplified data...');
        
        // Create reference path explicitly for clarity
        final collectionRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_userController.username.value)
            .collection('health_readings');
            
        print('🔥 Writing to collection: ${collectionRef.path}');
        
        // Store in Firestore with more robust error handling
        DocumentReference? docRef;
        
        try {
          docRef = await collectionRef.add(healthReading);
          print('✅ Data successfully saved to Firestore');
          print('📄 Document ID: ${docRef.id}');
        } catch (innerError) {
          print('❌ First save attempt failed: $innerError');
          
          // Try a more robust fallback approach with a simpler payload
          print('⚠️ Trying fallback with minimal data...');
          final minimalData = {
            'timestamp': FieldValue.serverTimestamp(), // Use server timestamp as a fallback
            'steps': _steps.value,
            'skinTemperature': _skinTemperature.value > 0 ? _skinTemperature.value : 36.5,
            'deviceName': _connectedDevice.value?.platformName ?? 'Unknown Device',
          };
          
          docRef = await collectionRef.add(minimalData);
          print('✅ Fallback save successful with minimal data');
          print('📄 Document ID: ${docRef.id}');
        }
        
        print('========= FIRESTORE STORAGE - END =========');
        
      } catch (firebaseError) {
        print('❌ ERROR: All Firestore save attempts failed: $firebaseError');
        
        // Additional diagnostics based on the error type
        if (firebaseError.toString().contains('DEVELOPER_ERROR') || 
            firebaseError.toString().contains('API unavailable')) {
          print('🔧 Google Play Services error. You may need to:');
          print('1. Update Google Play Services on the device');
          print('2. Check if your app is correctly registered in Firebase console');
          print('3. Verify the SHA-1 fingerprint in Firebase console matches your app');
          print('4. Try rebuilding the app with a production keystore');
        }
      }
      
    } catch (e) {
      // Debug print for errors
      print('❌ ERROR: Failed to save health data to Firestore');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error details: $e');
      print('========= FIRESTORE STORAGE - FAILED =========');
    }
  }

  // Add a manual trigger for testing purposes
  Future<void> testFirestoreSave() async {
    print('🧪 MANUAL TEST: Triggering Firestore save for testing...');
    await _saveHealthData(0); // Pass a placeholder value
  }

  // Add a method to manually trigger Firebase test and save
  Future<void> debugFirebaseAndSave() async {
    print('🧪 MANUAL FIREBASE DEBUG TEST');
    bool initialized = await _checkFirebaseInitialization();
    if (initialized) {
      await _saveHealthData(0);
    } else {
      print('❌ Firebase initialization check failed - fix Firebase setup first');
    }
  }

  // Add public methods to update fall detection status and show alert
  void updateFallDetection(bool status) {
    _fallDetected.value = status;
    update();
  }
  
  // Toggle fall detection status (for testing)
  void toggleFallDetection() {
    _fallDetected.value = !_fallDetected.value;
    if (_fallDetected.value) {
      showFallDetectionAlert();
    }
    update();
  }
  
  // Add public method to save health data
  Future<void> saveHealthData() async {
    await _saveHealthData(heartRate);
  }
}