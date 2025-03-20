import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';

class HealthMonitorPage extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final String spo2;
  final String temperature;
  final String bloodPressure;
  final String bloodSugar;

  HealthMonitorPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
    this.spo2 = '--',
    this.temperature = '--',
    this.bloodPressure = '--/--',
    this.bloodSugar = '--',
  });

  final BluetoothController bluetoothController =
      Get.find<BluetoothController>();

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();

    return Scaffold(
      backgroundColor: const Color(0xFF14141A), // Dark background color
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'HEALTH MONITOR',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity, // Full width
        height: double.infinity, // Full height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF1A1A1A),
              const Color(0xFF242424),
              Colors.grey[900]!,
              Colors.black,
            ],
            stops: const [0.0, 0.5, 0.7, 0.9, 1.0],
          ),
        ),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withAlpha(8),
                Colors.white.withAlpha(10),
                Colors.white.withAlpha(12),
                Colors.white.withAlpha(15),
                Colors.transparent,
              ],
              stops: const [
                0.0,
                0.6,
                0.8,
                0.9,
                1.0
              ], // Adjusted to match main gradient
            ).createShader(bounds);
          },
          blendMode: BlendMode.overlay,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40), // Added bottom padding
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'Welcome, ${userController.username}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // BPM Circle and Graph
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Graph
                    SizedBox(
                      height: 150,
                      child: Obx(() => LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: bluetoothController.heartRateHistory
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(
                                          e.key.toDouble(), e.value.toDouble()))
                                      .toList(),
                                  isCurved: true,
                                  color: const Color(0xFF007AFF),
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                            ),
                          )),
                    ),
                    // BPM Circle
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1C1C23),
                        border: Border.all(
                          color: Colors.white.withAlpha(26),
                          width: 2,
                        ),
                      ),
                      foregroundDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withAlpha(8),
                            Colors.transparent,
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Obx(() => Text(
                                '${bluetoothController.heartRate}',
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              )),
                          const Text(
                            'BPM',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Metrics Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        "LAST NIGHT'S METRICS",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.white.withAlpha(38),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Metrics Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'RESPIRATORY\nRATE',
                              value: '13.1',
                              unit: 'rpm',
                              range: 'within 12.2 - 13.9',
                              icon: Icons.air,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'BLOOD\nOXYGEN',
                              value: spo2,
                              unit: '%',
                              range: 'within 94% - 100%',
                              icon: Icons.water_drop,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'RHR',
                              value: '${bluetoothController.heartRate}',
                              unit: 'bpm',
                              range: 'within 44 - 53',
                              icon: Icons.favorite,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'HRV',
                              value: '69',
                              unit: 'ms',
                              range: 'within 47 - 94',
                              icon: Icons.show_chart,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'BLOOD\nPRESSURE',
                              value: bloodPressure,
                              unit: 'mmHg',
                              range: 'within 90/60-120/80',
                              icon: Icons.speed,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'SKIN TEMP\n(FROM BASELINE)',
                              value: temperature,
                              unit: '°F',
                              range: 'within -1.5 to +2.3',
                              icon: Icons.thermostat,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'BLOOD\nSUGAR',
                              value: bloodSugar,
                              unit: 'mg/dL',
                              range: 'within 70-140',
                              icon: Icons.water_drop,
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String range,
    required IconData icon,
  }) {
    // Add blood pressure check
    bool isBloodPressure = title.contains('BLOOD\nPRESSURE');
    double fontSize =
        isBloodPressure ? 22 : 28; // Smaller font for blood pressure

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha(26),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withAlpha(3), // Very subtle start
            Colors.white.withAlpha(8), // Slight increase
            Colors.white.withAlpha(8), // Maintain middle
            Colors.white.withAlpha(3), // Fade out
          ],
          stops: const [0.0, 0.3, 0.7, 1.0], // More even distribution
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: Colors.white38,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: Colors.white38,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: fontSize, // Use dynamic font size
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                range,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Color(0xFF4CAF50),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
