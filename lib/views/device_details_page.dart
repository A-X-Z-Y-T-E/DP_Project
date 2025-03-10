import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';

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
  final List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this); // PROFILE, DETAILS and LOG tabs
    // Connect to device if not already connected
    if (controller.connectedDevice?.id != widget.device.id) {
      controller.connectToDevice(widget.device);
    }
    // Start periodic RSSI updates
    _startRssiUpdates();
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
    _tabController.dispose();
    textController.dispose();
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

        if (!controller.isDeviceConnected()) {
          return Center(
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
                  child: const Text('RECONNECT'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 8),
            _buildServicesSection(),
            Expanded(
              child: Column(
                children: [
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
                      controller: _tabController,
                      children: [
                        _buildProfileTab(),
                        _buildDetailsTab(),
                        _buildLogTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
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
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    rssiValue,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.link,
                color: Colors.blue,
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
                  // Refresh connection
                  controller.discoverServices();
                  setState(() {
                    // Update RSSI
                    final random = DateTime.now().millisecondsSinceEpoch % 45;
                    rssiValue = '-${45 + random}dBm';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('REFRESH'),
              ),
              ElevatedButton(
                onPressed: () {
                  controller.disconnectDevice();
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('DISCONNECT'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return Container(
      height: 120,
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
          const SizedBox(height: 8),
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
                  return const SizedBox
                      .shrink(); // Return empty widget for non-P2P services
                }

                return GestureDetector(
                  onTap: () {
                    // Switch to profile tab when P2P service is tapped
                    _tabController.animateTo(0);
                    // Setup button listener for the selected service
                    _setupButtonListener(service);
                  },
                  child: Container(
                    width: 120,
                    height: 80, // Reduced height
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4), // Reduced margin
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0), // Reduced padding
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings_ethernet,
                            color: Colors.blue,
                            size: 24, // Smaller icon
                          ),
                          const SizedBox(height: 4), // Reduced spacing
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
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
    // Check if P2P service is available
    bool hasP2PService = controller.hasP2PService();

    if (!hasP2PService) {
      return const Center(
        child: Text(
          'P2P service not available on this device',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'P2P Server',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'FE40',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Is Primary',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Application P2P server',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.notifications_none,
                  color: Colors.grey, size: 30),
              const SizedBox(width: 16),
              const Text(
                'No alarm received',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.grey, size: 30),
              const SizedBox(width: 16),
              Switch(
                value: ledState,
                onChanged: (value) {
                  _toggleLed();
                },
                activeColor: Colors.blue,
              ),
              Text(
                ledState ? 'LED ON' : 'LED OFF',
                style: TextStyle(
                  color: ledState ? Colors.blue : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Activity Log',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No activity yet',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: logs.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        final reversedIndex = logs.length - 1 - index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${reversedIndex + 1}. ',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  logs[reversedIndex],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    if (controller.characteristics.isEmpty) {
      return const Center(
        child: Text(
          'Select a service to view details',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Generic Attribute',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '1801',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Is Primary',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          'READ ALL CHARACTERISTICS',
          () => _readAllCharacteristics(),
          Colors.blue,
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          'ENABLE ALL NOTIFICATIONS / INDICATIONS',
          () => _enableAllNotifications(),
          Colors.blue,
        ),
        const SizedBox(height: 16),
        Row(
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'REQUEST MTU',
                () {},
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
      ],
    );
  }

  Widget _buildLogTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Log entry ${10 - index}: ${DateTime.now().toString()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        );
      },
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
          setState(() {
            logs.add(
                'Button state: ${value[0] == 0x01 ? 'Pressed' : 'Released'}');
          });
        }
      });

      setState(() {
        logs.add('Started listening for button presses');
      });
    } catch (e) {
      setState(() {
        logs.add('Error setting up button listener: $e');
      });
    }
  }

  Future<void> _toggleLed() async {
    try {
      // Find P2P service
      final service = controller.services.firstWhere(
        (s) => s.uuid == controller.p2pServiceUuid,
        orElse: () => throw Exception('P2P service not found'),
      );

      // Find LED characteristic
      final ledChar = service.characteristics.firstWhere(
        (c) => c.uuid == controller.ledCharUuid,
        orElse: () => throw Exception('LED characteristic not found'),
      );

      // Check if the characteristic supports write
      if (!ledChar.properties.write &&
          !ledChar.properties.writeWithoutResponse) {
        setState(() {
          logs.add(
              'Error: LED characteristic does not support write operations');
        });
        Get.snackbar(
          'Write Not Supported',
          'This LED characteristic does not support write operations',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Toggle LED state
      setState(() {
        ledState = !ledState;
      });

      // Write value to turn LED on/off
      if (ledChar.properties.writeWithoutResponse) {
        await ledChar.write([ledState ? 0x01 : 0x00], withoutResponse: true);
      } else {
        await ledChar.write([ledState ? 0x01 : 0x00]);
      }

      setState(() {
        logs.add('LED turned ${ledState ? 'ON' : 'OFF'}');
      });
    } catch (e) {
      setState(() {
        logs.add('Error toggling LED: $e');
      });
      Get.snackbar(
        'LED Control Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _readAllCharacteristics() async {
    for (var characteristic in controller.characteristics) {
      if (characteristic.properties.read) {
        await controller.readCharacteristic(characteristic);
      }
    }
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
              Get.snackbar(
                'Bond Deleted',
                'Device bond has been removed',
                backgroundColor: Colors.blue,
                colorText: Colors.white,
              );
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _debugPrintServicesAndCharacteristics() {
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
}
