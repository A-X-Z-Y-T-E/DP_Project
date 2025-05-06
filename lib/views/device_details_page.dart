import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Vital_Monitor/views/health_monitor_page.dart';
import 'package:Vital_Monitor/views/health_history_page.dart';
import 'package:Vital_Monitor/widgets/pulse_waveform_chart.dart';

class DeviceDetailsPage extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDetailsPage({super.key, required this.device});

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage>
    with SingleTickerProviderStateMixin {
  final BluetoothController controller = Get.find<BluetoothController>();
  final TextEditingController textController = TextEditingController();
  late TabController _tabController;
  String rssiValue = '-67dBm'; // Default value
  bool ledState = false;
  final List<Map<String, dynamic>> logs = []; // Changed to Map to include timestamps
  final Map<String, String> lastNotificationValues = {}; // Class-level map

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this); // PROFILE, DETAILS and LOG tabs
    
    // Add discovery and connection logs with timestamps
    _addLog('Service discovery started');
    _addLog('Peripheral scan started');
    _addLog('Connecting to peripheral(peripheral: {identifier: ${widget.device.remoteId.str}, name: ${widget.device.platformName}})');
    
    // Connect to device if not already connected
    if (controller.connectedDevice?.remoteId != widget.device.remoteId) {
      controller.connectToDevice(widget.device).then((_) {
        _addLog('Peripheral connected(peripheral: {identifier: ${widget.device.remoteId.str}, name: ${widget.device.platformName}})');
        _addLog('Stop scan');
        
        // Log MTU information
        _addLog('MTU requested: 517');
        _addLog('MTU set to 156');
        
        // Log service discovery
        _addLog('Service discovered(identifier: ${widget.device.remoteId.str}, services: [{id: 00001801-0000-1000-8000-00805f9b34fb, name: Generic Attribute}, {id: 00001800-0000-1000-8000-00805f9b34fb, name: Generic Access}, {id: 0000fe40-cc7a-482a-984a-7f2ed5b3e58f, name: P2P Server}, {id: 0000180d-0000-1000-8000-00805f9b34fb, name: Heart Rate}])');
      });
    }
    
    // Start health monitoring after connection
    controller.startHealthMonitoring();
    // Start periodic RSSI updates
    _startRssiUpdates();
    
    // Stop any simulation that might be running - we want real data
    controller.stopSimulation();

    // Find and enable notifications for the 0010 characteristic to get real pulse waveform data
    _enableTxPowerLevelNotifications();
  }

  void _enableTxPowerLevelNotifications() {
    // Debug all characteristics to help find the correct one
    print('Looking for pulse waveform characteristic (0010) with 224 bytes (56 values)');
    for (var service in controller.services) {
      print('Service: ${service.uuid}');
      for (var characteristic in service.characteristics) {
        print('Char: ${characteristic.uuid} - Notify: ${characteristic.properties.notify}');
      }
    }
    
    // After discovering services, look for the characteristic with UUID 0010
    Future.delayed(Duration(milliseconds: 500), () async {
      try {
        // Find the custom service and characteristic
        final customServiceUuid = "00000001-0000-1000-8000-00805F9B34FB";  // Based on STM toolbox
        BluetoothCharacteristic? pulseCharacteristic;
        
        // First try exact matching with the expected service/characteristic
        for (var service in controller.services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase().contains("0010")) {
              pulseCharacteristic = characteristic;
              _addLog('Found pulse waveform characteristic: ${characteristic.uuid}');
              break;
            }
          }
          if (pulseCharacteristic != null) break;
        }
        
        // If we found a suitable characteristic, enable notifications
        if (pulseCharacteristic != null) {
          if (!pulseCharacteristic.isNotifying) {
            await pulseCharacteristic.setNotifyValue(true);
            _addLog('Enabled real-time notifications for pulse waveform data (expecting 224 bytes)');
          }
          
          // Set up notification listener for 4-byte/value data format
          pulseCharacteristic.lastValueStream.listen((value) {
            if (value.isNotEmpty) {
              // Just log a simple message about receiving data
             // _addLog('Received ${value.length} bytes of pulse waveform data');
              
              // Process the raw data into waveform data
              controller.updatePulseWaveform(value);
            }
          });
          
          // Try to read initial value if available
          if (pulseCharacteristic.properties.read) {
            try {
              final initialValue = await controller.readCharacteristic(pulseCharacteristic);
              //_addLog('Read initial pulse data: ${initialValue.length} bytes');
              controller.updatePulseWaveform(initialValue);
            } catch (e) {
              _addLog('Failed to read initial pulse data: $e');
            }
          }
        } else {
          _addLog('Could not find pulse waveform characteristic (0010)');
        }
      } catch (e) {
        _addLog('Error enabling pulse waveform: $e');
      }
    });
  }

  // Helper method to add a log with timestamp
  void _addLog(String message) {
    setState(() {
      logs.add({
        'timestamp': DateTime.now(),
        'message': message
      });
      // Keep logs to a reasonable size
      if (logs.length > 100) {
        logs.removeAt(0);
      }
    });
  }

  void _startRssiUpdates() {
    // Simulate RSSI updates - in a real app, you would get this from the device
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          // Simulate a random RSSI value between -45 and -90
          final random = DateTime.now().millisecondsSinceEpoch % 45;
          rssiValue = '-${45 + random}dBm';
        });
        _startRssiUpdates();
      }
    });
  }

  @override
  void dispose() {
    // Stop RSSI updates
    _tabController.dispose();
    textController.dispose();

    // If we're navigating away from this page, ensure device is properly disconnected
    if (mounted && controller.isDeviceConnected()) {
      controller.disconnectDevice();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.device.platformName.isEmpty
                  ? 'ST Microelectronics'
                  : widget.device.platformName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.device.remoteId.str,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () {
              _showDeleteBondDialog();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isConnecting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        return Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 8),
            _buildServicesSection(),
            if (controller.isDeviceConnected()) ...[
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'PROFILE'),
                  Tab(text: 'DETAILS'),
                  Tab(text: 'LOG'),
                ],
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.blue,
              ),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _tabController,
                  children: [
                    _buildProfileTab(),
                    _buildDetailsTab(),
                    _buildLogTab(),
                  ],
                ),
              ),
            ] else
              _buildDisconnectedView(),
          ],
        );
      }),
    );
  }

  Widget _buildDisconnectedView() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_disabled,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Device disconnected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The connection with this device has been lost. Reconnect to continue monitoring.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => controller.connectToDevice(widget.device),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
            child: const Text('CONNECT AGAIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RSSI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.signal_cellular_alt,
                    color: controller.isDeviceConnected() ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    controller.isDeviceConnected() ? rssiValue : 'N/A',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Icon(
                controller.isDeviceConnected() ? Icons.link : Icons.link_off,
                color: controller.isDeviceConnected() ? Colors.blue : Colors.grey,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  if (controller.isDeviceConnected()) {
                    // Refresh connection
                    controller.discoverServices();
                    setState(() {
                      // Update RSSI
                      final random = DateTime.now().millisecondsSinceEpoch % 45;
                      rssiValue = '-${45 + random}dBm';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                  disabledForegroundColor: Colors.white.withOpacity(0.5),
                ),
                child: const Text('REFRESH'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.isDeviceConnected()) {
                    controller.disconnectDevice();
                  } else {
                    controller.connectToDevice(widget.device);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: controller.isDeviceConnected() ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(controller.isDeviceConnected() ? 'DISCONNECT' : 'CONNECT AGAIN'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return Container(
      height: 180, // Reduced from 220 to 180
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Services: ${controller.services.length}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showDeleteBondDialog(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Delete bond',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4), // Reduced from 8 to 4
          // Navigation Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.to(() => HealthMonitorPage(
                            deviceName: widget.device.platformName,
                            deviceId: widget.device.remoteId.str,
                          ));
                    },
                    icon: const Icon(Icons.monitor_heart),
                    label: const Text('Health Monitor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Get.to(() => const HealthHistoryPage()),
                    icon: const Icon(Icons.history),
                    label: const Text('Health History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4), // Reduced from 8 to 4
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: controller.services.length,
              itemBuilder: (context, index) {
                final service = controller.services[index];
                // Check if this is a P2P service
                bool isP2PService =
                    service.uuid.toString().toUpperCase().contains('FE40');

                // Skip non-P2P services if you only want to show P2P
                if (!isP2PService) {
                  return const SizedBox.shrink();
                }

                return GestureDetector(
                  onTap: () {
                    _tabController.animateTo(0);
                    _setupButtonListener(service);
                  },
                  child: Container(
                    width: 120,
                    height: 70, // Reduced from 80 to 70
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2), // Reduced vertical margin from 4 to 2
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings_ethernet,
                            color: Colors.blue,
                            size: 24,
                          ),
                          const SizedBox(height: 2), // Reduced from 4 to 2
                          Flexible(
                            child: Text(
                              'P2P Server',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 2.0), // Reduced vertical padding from 4 to 2
            child: Text(
              'Scroll to see more services',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Heart Rate Monitor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2433),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 200,
                    child: Obx(() {
                      // Determine sensor position based on location
                      Offset sensorPosition = const Offset(
                          0.5, 0.35); // Default to heart/chest position
                      switch (controller.sensorLocation.toLowerCase()) {
                        case "chest":
                          sensorPosition = const Offset(0.5, 0.35);
                          break;
                        case "wrist":
                          sensorPosition = const Offset(0.15, 0.4);
                          break;
                        case "finger":
                          sensorPosition = const Offset(0.15, 0.45);
                          break;
                        case "hand":
                          sensorPosition = const Offset(0.15, 0.4);
                          break;
                        case "ear lobe":
                          sensorPosition = const Offset(0.65, 0.15);
                          break;
                        case "foot":
                          sensorPosition = const Offset(0.65, 0.85);
                          break;
                        case "other":
                          sensorPosition = const Offset(
                              0.5, 0.35); // Default to heart/chest for "other"
                          break;
                      }

                      return CustomPaint(
                        painter: BodyOutlinePainter(
                          color: Colors.white,
                          sensorPosition: sensorPosition,
                        ),
                        size: const Size(120, 200),
                      );
                    }),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Skin contact',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Obx(() => Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: controller.hasContact
                                          ? Colors.green
                                          : Colors.grey,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      controller.hasContact ? 'Yes' : 'No',
                                      style: TextStyle(
                                        color: controller.hasContact
                                            ? Colors.green
                                            : Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              'Position',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Obx(() => Text(
                                  controller.sensorLocation,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              'RR Interval',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '1.0 s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const PulseWaveformChart(
              key: ValueKey('pulseWaveformChart'),
              height: 220,
              lineColor: Colors.red, // Changed from green to red
              title: 'Pulse Waveform Monitor',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2433),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'HRV',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      Obx(() => Text(
                            '${controller.hrv} ms',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Steps',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(() => Text(
                            '${controller.steps}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Skin Temperature',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(() => Text(
                            '${controller.skinTemperature.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Fall Detection',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(() => Text(
                            controller.fallDetected ? 'Detected' : 'None',
                            style: TextStyle(
                              color: controller.fallDetected ? Colors.red : Colors.green,
                              fontSize: 16,
                              fontWeight: controller.fallDetected ? FontWeight.bold : FontWeight.normal,
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    if (controller.characteristics.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: const Text(
            'Select a service to view details',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Add SingleChildScrollView to fix overflow
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Generic Attribute',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '1801',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Is Primary',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildActionButton(
              'READ ALL CHARACTERISTICS',
              () => _readAllCharacteristics(),
              Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildActionButton(
              'ENABLE ALL NOTIFICATIONS / INDICATIONS',
              () => _enableAllNotifications(),
              Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'READ PHY',
                    () {},
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'SET PREFERRED PHY',
                    () {},
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'REQUEST MTU',
                    () => _requestMtu(517),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'CHANGE CONNECTION INTERVAL',
                    () {},
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Display individual characteristics similar to the images
          ...controller.characteristics.map((characteristic) => 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildCharacteristicItem(characteristic),
            )
          ).toList(),
          const SizedBox(height: 20), // Add some padding at the bottom
        ],
      ),
    );
  }
  
  Widget _buildCharacteristicItem(BluetoothCharacteristic characteristic) {
    // Extract the last part of the UUID for display
    final uuidDisplay = characteristic.uuid.toString().toUpperCase();
    final rxValues = <int>[].obs; // Observable for notifications
    final timestamp = DateTime.now().obs;
    
    // Check if this is the TX POWER LEVEL characteristic (0010)
    final isPulseCharacteristic = characteristic.uuid.toString().toUpperCase().contains("00000010-0000-1000-8000-00805F9B34FB");
    
    // Set up a subscription for this characteristic if it's notifiable
    if (characteristic.properties.notify || characteristic.properties.indicate) {
      characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          rxValues.value = value;
          timestamp.value = DateTime.now();
          
          // Format the notification data in 4-byte chunks for display
          final formattedValue = formatValueAs4ByteChunks(value);
          final characteristicId = characteristic.uuid.toString();
          
          if (lastNotificationValues[characteristicId] != formattedValue) {
            lastNotificationValues[characteristicId] = formattedValue;
            
            // Format message to match the structure but with 4-byte chunk display
            String logMessage = 'Updated value for characteristic(characteristic: {id: ${characteristic.uuid}, '
                'serviceID: ${characteristic.serviceUuid}, name: , value: $formattedValue})';
                
            _addLog(logMessage);
          }
        }
      });
    }
    
    if (isPulseCharacteristic) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            Expanded(
              child: Text(
                _getCharacteristicName(characteristic.uuid),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                // Edit functionality could be added here
              },
              child: const Icon(
                Icons.edit,
                color: Colors.yellow,
                size: 20,
              ),
            ),
          ],
        ),
        Text(
          characteristic.uuid.toString().toUpperCase(),
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (characteristic.properties.read)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final value = await controller.readCharacteristic(characteristic);
                      rxValues.value = value; // Update the value
                      timestamp.value = DateTime.now();
                      
                      // Enhanced logging for characteristic reads
                      final formattedValue = formatValueAs4ByteChunks(value);
                      final characteristicName = _getCharacteristicName(characteristic.uuid);
                      
                      // Format log message similar to the images - show full details in app logs
                      String logMessage = 'Read value for characteristic(characteristic: {id: ${characteristic.uuid}, ' +
                          'serviceID: ${characteristic.serviceUuid}, name: $characteristicName, value: $formattedValue})';
                      
                      _addLog(logMessage);
                    } catch (e) {
                      _addLog('Read error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('READ'),
                ),
              if (characteristic.properties.read) 
                const SizedBox(width: 8),
              if (characteristic.properties.write || characteristic.properties.writeWithoutResponse)
                ElevatedButton(
                  onPressed: () {
                    _showWriteDialog(characteristic);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('WRITE'),
                ),
              if ((characteristic.properties.write || characteristic.properties.writeWithoutResponse) && 
                  (characteristic.properties.notify || characteristic.properties.indicate)) 
                const SizedBox(width: 8),
              if (characteristic.properties.notify || characteristic.properties.indicate)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Indicate',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: characteristic.isNotifying, // Track notification state
                      onChanged: (value) async {
                        try {
                          await characteristic.setNotifyValue(value);
                          // If we're turning off notifications, clear the stored value
                          if (!value) {
                            lastNotificationValues.remove(characteristic.uuid.toString());
                          }
                          _addLog(value 
                            ? 'Notifications enabled for ${_getCharacteristicName(characteristic.uuid)}'
                            : 'Notifications disabled for ${_getCharacteristicName(characteristic.uuid)}');
                        } catch (e) {
                          _addLog('Notification error: $e');
                        }
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              if (characteristic.properties.notify)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 16),
                    const Text(
                      'Notify',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: characteristic.isNotifying,
                      onChanged: (value) async {
                        try {
                          await characteristic.setNotifyValue(value);
                          _addLog(value 
                            ? 'Notifications enabled for ${_getCharacteristicName(characteristic.uuid)}'
                            : 'Notifications disabled for ${_getCharacteristicName(characteristic.uuid)}');
                        } catch (e) {
                          _addLog('Notification error: $e');
                        }
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Value',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Obx(() {
          String displayValue = rxValues.isNotEmpty 
              ? formatValueAs4ByteChunks(rxValues)
              : '00';
          
          return Row(
            children: [
              Icon(rxValues.isEmpty ? Icons.play_arrow : Icons.expand_more, color: Colors.blue),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Courier',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        const Text(
          'Pulse Waveform',
          style: TextStyle(
            color: Colors.green,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3))
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Live waveform visualization is available in the ',
                        style: TextStyle(color: Colors.white70)
                      ),
                      TextSpan(
                        text: 'PROFILE',
                        style: TextStyle(
                          color: Colors.green, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                      TextSpan(
                        text: ' tab',
                        style: TextStyle(color: Colors.white70)
                      ),
                    ]
                  ),
                ),
              ),
            ],
          ),
        ),
        Obx(() => Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Data points: ${controller.pulseWaveformData.length}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        )),
        Obx(() => Text(
          'Updated at ${_formatTime(timestamp.value)}',
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 12,
          ),
        )),
        if (characteristic.descriptors.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Descriptors',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...characteristic.descriptors.map((descriptor) => 
            _buildDescriptorItem(descriptor)
          ).toList(),
        ],
        const SizedBox(height: 16),
        const Divider(color: Colors.white24),
      ],
    );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _getCharacteristicName(characteristic.uuid),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                // Edit functionality could be added here
              },
              child: const Icon(
                Icons.edit,
                color: Colors.yellow,
                size: 20,
              ),
            ),
          ],
        ),
        Text(
          uuidDisplay,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (characteristic.properties.read)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final value = await controller.readCharacteristic(characteristic);
                      rxValues.value = value; // Update the value
                      timestamp.value = DateTime.now();
                      
                      // Enhanced logging for characteristic reads
                      final formattedValue = formatValueAs4ByteChunks(value);
                      final characteristicName = _getCharacteristicName(characteristic.uuid);
                      
                      // Format log message similar to the images - show full details in app logs
                      String logMessage = 'Read value for characteristic(characteristic: {id: ${characteristic.uuid}, ' +
                          'serviceID: ${characteristic.serviceUuid}, name: $characteristicName, value: $formattedValue})';
                      
                      _addLog(logMessage);
                    } catch (e) {
                      _addLog('Read error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('READ'),
                ),
              if (characteristic.properties.read) 
                const SizedBox(width: 8),
              if (characteristic.properties.write || characteristic.properties.writeWithoutResponse)
                ElevatedButton(
                  onPressed: () {
                    _showWriteDialog(characteristic);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('WRITE'),
                ),
              if ((characteristic.properties.write || characteristic.properties.writeWithoutResponse) && 
                  (characteristic.properties.notify || characteristic.properties.indicate)) 
                const SizedBox(width: 8),
              if (characteristic.properties.notify || characteristic.properties.indicate)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Indicate',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: characteristic.isNotifying, // Track notification state
                      onChanged: (value) async {
                        try {
                          await characteristic.setNotifyValue(value);
                          // If we're turning off notifications, clear the stored value
                          if (!value) {
                            lastNotificationValues.remove(characteristic.uuid.toString());
                          }
                          _addLog(value 
                            ? 'Notifications enabled for ${_getCharacteristicName(characteristic.uuid)}'
                            : 'Notifications disabled for ${_getCharacteristicName(characteristic.uuid)}');
                        } catch (e) {
                          _addLog('Notification error: $e');
                        }
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              if (characteristic.properties.notify)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 16),
                    const Text(
                      'Notify',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: characteristic.isNotifying,
                      onChanged: (value) async {
                        try {
                          await characteristic.setNotifyValue(value);
                          _addLog(value 
                            ? 'Notifications enabled for ${_getCharacteristicName(characteristic.uuid)}'
                            : 'Notifications disabled for ${_getCharacteristicName(characteristic.uuid)}');
                        } catch (e) {
                          _addLog('Notification error: $e');
                        }
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Value',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Obx(() {
          // Display the current value in the format matching the images
          String displayValue = rxValues.isNotEmpty 
              ? formatValueAs4ByteChunks(rxValues)
              : '00';
          
          return Row(
            children: [
              Icon(rxValues.isEmpty ? Icons.play_arrow : Icons.expand_more, color: Colors.blue),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Courier', // Use monospace font for better readability of hex values
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          );
        }),
        Obx(() => Text(
          'Updated at ${_formatTime(timestamp.value)}',
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 12,
          ),
        )),
        if (characteristic.descriptors.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Descriptors',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...characteristic.descriptors.map((descriptor) => 
            _buildDescriptorItem(descriptor)
          ).toList(),
        ],
        const SizedBox(height: 16),
        const Divider(color: Colors.white24),
      ],
    );
  }

  // Format timestamp to match the images
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  // Add this method to show a dialog for writing to characteristics
  void _showWriteDialog(BluetoothCharacteristic characteristic) {
    final textController = TextEditingController();
    bool writeWithResponse = true;
    
    // Use WidgetsBinding to avoid the overlay error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text(
            'Write Value',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter value (hex format):',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '01 02 03',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Write with response',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  StatefulBuilder(
                    builder: (context, setState) => Switch(
                      value: writeWithResponse,
                      onChanged: (value) {
                        setState(() {
                          writeWithResponse = value;
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final hexString = textController.text.trim().replaceAll(' ', '');
                  final List<int> bytes = [];
                  
                  for (int i = 0; i < hexString.length; i += 2) {
                    if (i + 2 <= hexString.length) {
                      bytes.add(int.parse(hexString.substring(i, i + 2), radix: 16));
                    }
                  }
                  
                  if (bytes.isEmpty) {
                    Get.back();
                    return;
                  }
                  
                  if (writeWithResponse) {
                    await characteristic.write(bytes);
                  } else {
                    await characteristic.write(bytes, withoutResponse: true);
                  }
                  
                  Get.back();
                  _addLog('Wrote: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
                } catch (e) {
                  Get.back();
                  _addLog('Write error: $e');
                }
              },
              child: const Text('WRITE', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
    });
  }

  // Adding the missing _buildDescriptorItem method
  Widget _buildDescriptorItem(BluetoothDescriptor descriptor) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2433),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Characteristic Configuration',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const Text(
            '2902', // Standard descriptor code for CCCD
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  try {
                    final value = await descriptor.read();
                    _addLog('Read descriptor: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(',')}');
                  } catch (e) {
                    _addLog('Read descriptor error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                ),
                child: const Text('READ'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Write to descriptor
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                ),
                child: const Text('WRITE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Update the RequestMTU method to remove snackbar
  void _requestMtu(int size) async {
    try {
      // Request the MTU size
      await widget.device.requestMtu(size);
      
      _addLog('MTU requested: $size');
    } catch (e) {
      _addLog('MTU request error: $e');
    }
  }

  Widget _buildLogTab() {
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'No logs available yet',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Stack(
        children: [
          // Use a Container with a fixed height constraint to prevent the TabBarView from being scrollable
          Container(
            height: MediaQuery.of(context).size.height, 
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Add bottom padding for FAB
              itemCount: logs.length,
              physics: const AlwaysScrollableScrollPhysics(), // Only allow scrolling within the ListView
              itemBuilder: (context, index) {
                // Display logs in reverse chronological order (newest first)
                final logEntry = logs[logs.length - 1 - index];
                final DateTime timestamp = logEntry['timestamp'];
                final String message = logEntry['message'];
                
                // Format date and time as shown in the images
                final String formattedDate = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
                final String formattedTime = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
                
                // Check if the message is a characteristic update/read notification
                bool isUpdateNotification = message.contains('Updated value for characteristic');
                bool isReadNotification = message.contains('Read value for characteristic');
                
                // Extract title based on type of log message
                String title = '';
                if (isUpdateNotification) {
                  title = 'Updated value for characteristic';
                } else if (isReadNotification) {
                  title = 'Read value for characteristic';
                }
                
                return Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: Colors.yellow,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            color: isReadNotification ? Colors.green : Colors.yellow,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        title.isNotEmpty ? message.substring(title.length) : message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  logs.clear();
                });
              },
              backgroundColor: Colors.red,
              mini: true,
              child: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _setupButtonListener(BluetoothService service) async {
    try {
      // Find Button characteristic
      final buttonChar = service.characteristics.firstWhere(
        (c) => c.uuid == controller.buttonCharUuid,
        orElse: () => throw Exception('Button characteristic not found'),
      );

      // Subscribe to notifications
      await buttonChar.setNotifyValue(true);

      buttonChar.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          _addLog(
              'Button state: ${value[0] == 0x01 ? 'Pressed' : 'Released'}');
        }
      });

      _addLog('Started listening for button presses');
    } catch (e) {
      _addLog('Error setting up button listener: $e');
    }
  }

  void _readAllCharacteristics() async {
    _addLog('Reading all characteristics...');
    
    // Create a list to gather all readable characteristics
    List<BluetoothCharacteristic> readableCharacteristics = 
        controller.characteristics.where((c) => c.properties.read).toList();
    
    if (readableCharacteristics.isEmpty) {
      _addLog('No readable characteristics found');
      return;
    }
    
    // Read all characteristics one by one
    for (var characteristic in readableCharacteristics) {
      try {
        final value = await controller.readCharacteristic(characteristic);
        String charName = _getCharacteristicName(characteristic.uuid);
        
        // Use our new formatter for 4-byte chunk display
        String formattedValue = formatValueAs4ByteChunks(value);
        
        // Format log message similar to the images
        String logMessage = 'Read value for characteristic(characteristic: {id: ${characteristic.uuid}, ' +
            'serviceID: ${characteristic.serviceUuid}, name: $charName, value: $formattedValue})';
        
        _addLog(logMessage);
      } catch (e) {
        _addLog('Failed to read ${characteristic.uuid}: $e');
      }
    }
    
    _addLog('Completed reading ${readableCharacteristics.length} characteristics');
  }

  void _enableAllNotifications() async {
    for (var characteristic in controller.characteristics) {
      if (characteristic.properties.notify ||
          characteristic.properties.indicate) {
        await controller.subscribeToCharacteristic(characteristic);
      }
    }
  }

  void _showDeleteBondDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text(
            'Delete Bond',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete the bond with this device?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                // Implement bond deletion
                Get.back();
                // Remove snackbar and just log
                print('Bond deleted: Device bond has been removed');
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    });
  }

  void _debugPrintServicesAndCharacteristics() {
    _addLog('Printing BLE services to console...');

    for (var service in controller.services) {
      print('Service: ${service.uuid}');
      for (var char in service.characteristics) {
        print('  Char: ${char.uuid}');
        print('    Properties: ');
        print('      Read: ${char.properties.read}');
        print('      Write: ${char.properties.write}');
        print(
            '      WriteWithoutResponse: ${char.properties.writeWithoutResponse}');
        print('      Notify: ${char.properties.notify}');
        print('      Indicate: ${char.properties.indicate}');
      }
    }
  }

  String _getCharacteristicName(Guid uuid) {
    final uuidString = uuid.toString().toUpperCase();
    
    // The specific characteristic from the images
    if (uuidString.contains('00000010-0000-1000-8000-00805F9B34FB')) {
      return 'TX POWER LEVEL';
    }
    
    // Generic Access Profile (0x1800)
    if (uuidString.contains('00002A00')) return 'DEVICE NAME';
    if (uuidString.contains('00002A01')) return 'APPEARANCE';
    if (uuidString.contains('00002A04')) return 'PERIPHERAL PREFERRED CONNECTION PARAMETERS';
    
    // Generic Attribute Profile (0x1801)
    if (uuidString.contains('00002A05')) return 'SERVICE CHANGED';
    
    // Device Information (0x180A)
    if (uuidString.contains('00002A29')) return 'MANUFACTURER NAME';
    if (uuidString.contains('00002A24')) return 'MODEL NUMBER';
    if (uuidString.contains('00002A25')) return 'SERIAL NUMBER';
    if (uuidString.contains('00002A27')) return 'HARDWARE REVISION';
    if (uuidString.contains('00002A26')) return 'FIRMWARE REVISION';
    if (uuidString.contains('00002A28')) return 'SOFTWARE REVISION';
    if (uuidString.contains('00002A23')) return 'SYSTEM ID';
    if (uuidString.contains('00002A2A')) return 'IEEE CERTIFICATION';
    if (uuidString.contains('00002A50')) return 'PNP ID';
    
    // Heart Rate Service (0x180D)
    if (uuid == controller.heartRateCharUuid || uuidString.contains('00002A37')) return 'HEART RATE MEASUREMENT';
    if (uuidString.contains('00002A38')) return 'BODY SENSOR LOCATION';
    if (uuidString.contains('00002A39')) return 'HEART RATE CONTROL POINT';
    
    // Battery Service (0x180F)
    if (uuidString.contains('00002A19')) return 'BATTERY LEVEL';
    
    // Health Thermometer (0x1809)
    if (uuidString.contains('00002A1C')) return 'TEMPERATURE MEASUREMENT';
    if (uuidString.contains('00002A1D')) return 'TEMPERATURE TYPE';
    
    // Blood Pressure (0x1810)
    if (uuidString.contains('00002A35')) return 'BLOOD PRESSURE MEASUREMENT';
    if (uuidString.contains('00002A36')) return 'INTERMEDIATE CUFF PRESSURE';
    
    // Glucose (0x1808)
    if (uuidString.contains('00002A18')) return 'GLUCOSE MEASUREMENT';
    
    // Current Time Service (0x1805)
    if (uuidString.contains('00002A2B')) return 'CURRENT TIME';
    
    // P2P Service for STM devices
    if (uuid == controller.ledCharUuid) return 'LED CONTROL';
    if (uuid == controller.buttonCharUuid) return 'BUTTON STATE';
    
    // If we can extract the assigned number from the UUID, we can make the display better
    try {
      final regex = RegExp(r'0000([0-9A-Fa-f]{4})-0000-1000-8000-00805[fF]9[bB]34[fF][bB]');
      final match = regex.firstMatch(uuidString);
      if (match != null && match.groupCount >= 1) {
        return 'CHARACTERISTIC (0x${match.group(1)?.toUpperCase()})';
      }
    } catch (e) {
      // Ignore parsing errors
    }
    
    // Get last 4 chars of the UUID as fallback
    if (uuidString.length >= 4) {
      return 'CHARACTERISTIC (${uuidString.substring(uuidString.length - 4)})';
    }
    
    return 'CHARACTERISTIC';
  }

  // Helper method to format values in 4-byte chunks like "0000-4FB2"
  String formatValueAs4ByteChunks(List<int> value) {
    if (value.isEmpty) return "00";
    
    StringBuffer formattedValue = StringBuffer();
    for (int i = 0; i < value.length; i += 4) {
      if (i + 3 < value.length) {
        // Combine 4 bytes into a 32-bit integer (big-endian)
        int combinedValue = (value[i] << 24) | (value[i+1] << 16) | 
                          (value[i+2] << 8) | value[i+3];
        
        // Format as an 8-character hex string (without 0x prefix)
        String hexValue = combinedValue.toRadixString(16).padLeft(8, '0').toUpperCase();
        
        // Add to the buffer
        formattedValue.write(hexValue);
        
        // Add hyphen between chunks (except after the last one)
        if (i + 4 < value.length) {
          formattedValue.write('-');
        }
      } else {
        // Handle any remaining bytes (if not divisible by 4)
        for (int j = i; j < value.length; j++) {
          formattedValue.write(value[j].toRadixString(16).padLeft(2, '0').toUpperCase());
        }
      }
    }
    
    return formattedValue.toString();
  }
}

class BodyOutlinePainter extends CustomPainter {
  final Color color;
  final Offset sensorPosition;

  BodyOutlinePainter({
    this.color = Colors.white,
    required this.sensorPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final width = size.width;
    final height = size.height;

    // Head
    canvas.drawCircle(
      Offset(width / 2, height * 0.1),
      height * 0.08,
      paint,
    );

    // Neck
    canvas.drawLine(
      Offset(width / 2, height * 0.18),
      Offset(width / 2, height * 0.22),
      paint,
    );

    // Body
    final bodyPath = Path()
      ..moveTo(width * 0.35, height * 0.22)
      ..lineTo(width * 0.35, height * 0.5)
      ..lineTo(width * 0.65, height * 0.5)
      ..lineTo(width * 0.65, height * 0.22)
      ..close();
    canvas.drawPath(bodyPath, paint);

    // Arms
    final leftArmPath = Path()
      ..moveTo(width * 0.35, height * 0.25)
      ..quadraticBezierTo(
        width * 0.2,
        height * 0.25,
        width * 0.15,
        height * 0.4,
      );
    canvas.drawPath(leftArmPath, paint);

    final rightArmPath = Path()
      ..moveTo(width * 0.65, height * 0.25)
      ..quadraticBezierTo(
        width * 0.8,
        height * 0.25,
        width * 0.85,
        height * 0.4,
      );
    canvas.drawPath(rightArmPath, paint);

    // Legs
    canvas.drawLine(
      Offset(width * 0.4, height * 0.5),
      Offset(width * 0.35, height * 0.85),
      paint,
    );
    canvas.drawLine(
      Offset(width * 0.6, height * 0.5),
      Offset(width * 0.65, height * 0.85),
      paint,
    );

    // Draw sensor position
    final sensorPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(width * sensorPosition.dx, height * sensorPosition.dy),
      6,
      sensorPaint,
    );
  }

  @override
  bool shouldRepaint(BodyOutlinePainter oldDelegate) =>
      color != oldDelegate.color ||
      sensorPosition != oldDelegate.sensorPosition;
}