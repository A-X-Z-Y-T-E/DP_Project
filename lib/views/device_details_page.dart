import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Vital_Monitor/views/health_monitor_page.dart';
import 'package:Vital_Monitor/views/health_history_page.dart';

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
    if (controller.connectedDevice?.remoteId != widget.device.remoteId) {
      controller.connectToDevice(widget.device);
    }
    // Start health monitoring after connection
    controller.startHealthMonitoring();
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
    // Stop RSSI updates
    _tabController.dispose();
    textController.dispose();

    // If we're navigating away from this page, ensure device is properly disconnected
    if (mounted) {
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

        return SingleChildScrollView(
          child: Column(
            children: [
              _buildStatusCard(),
              const SizedBox(height: 8),
              _buildServicesSection(),
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
              SizedBox(
                height: MediaQuery.of(context).size.height *
                    1.5, // Increased height to accommodate both graphs
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      physics:
                          const ClampingScrollPhysics(), // Added to prevent nested scroll conflicts
                      child: _buildProfileTab(),
                    ),
                    _buildDetailsTab(),
                    _buildLogTab(),
                  ],
                ),
              ),
            ],
          ),
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
                            spo2: '98',
                            temperature: '37.2',
                            bloodPressure: '120/80',
                            bloodSugar: '95',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
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
          Container(
            height: 300,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2433),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Obx(() {
              if (controller.heartRateHistory.isEmpty) {
                return const Center(
                  child: Text(
                    'Waiting for heart rate data...',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              return LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white10,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 10,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (controller.heartRateHistory.length - 1).toDouble(),
                  minY: 65, // Set minimum to show better scale
                  maxY: 75, // Set maximum to show better scale
                  lineBarsData: [
                    LineChartBarData(
                      spots:
                          controller.heartRateHistory.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.red,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(() => _buildMetricCard(
                    icon: Icons.favorite,
                    value: '${controller.heartRate}',
                    unit: 'BPM',
                    color: Colors.red,
                  )),
              Obx(() => _buildMetricCard(
                    icon: Icons.local_fire_department,
                    value: '${controller.calories}',
                    unit: 'KCAL',
                    color: const Color(0xFF00E5FF), // Changed to cyan color
                  )),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Calories Burned',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300, // Increased from 200 to 300
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8), // Adjusted padding
            decoration: BoxDecoration(
              color: const Color(
                  0xFF1C2433), // Darker blue background to match image
              borderRadius: BorderRadius.circular(12),
            ),
            child: Obx(() {
              if (controller.calorieHistory.isEmpty) {
                return const Center(
                  child: Text(
                    'Waiting for calorie data...',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              return LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5, // Show grid lines every 5 calories
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white10,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5, // Show labels every 5 calories
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (controller.calorieHistory.length - 1).toDouble(),
                  minY: 70, // Set minimum to 70 calories
                  maxY: 90, // Set maximum to 90 calories
                  lineBarsData: [
                    LineChartBarData(
                      spots: controller.calorieHistory.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF00E5FF),
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF00E5FF),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF00E5FF).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.43,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 12,
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
    setState(() {
      logs.add('Printing BLE services to console...');
    });

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
