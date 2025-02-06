import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';

class HealthMonitorPage extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final String bpm;
  final String spo2;
  final String temperature;
  final String bloodPressure;
  final String bloodSugar;

  const HealthMonitorPage({
    Key? key,
    required this.deviceName,
    required this.deviceId,
    this.bpm = '--',
    this.spo2 = '--',
    this.temperature = '--',
    this.bloodPressure = '--/--',
    this.bloodSugar = '--',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'HEALTH MONITOR',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withAlpha(38),
              Colors.black,
              Colors.black,
            ],
            stops: const [0.0, 0.3, 0.5],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.white.withAlpha(3),
                Colors.white.withAlpha(8),
                Colors.white.withAlpha(5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 0.5, 0.7, 0.8, 1.0],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withAlpha(2),
                  Colors.white.withAlpha(5),
                  Colors.white.withAlpha(8),
                  Colors.white.withAlpha(10),
                  Colors.white.withAlpha(5),
                ],
                stops: const [0.0, 0.5, 0.6, 0.7, 0.8, 1.0],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Heart Rate Circle with Graph
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Graph behind the circle
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: 11,
                              minY: 0,
                              maxY: 2,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: const [
                                    FlSpot(0, 1.3),
                                    FlSpot(1, 1),
                                    FlSpot(2, 1.8),
                                    FlSpot(3, 1.5),
                                    FlSpot(4, 1),
                                    FlSpot(5, 1.3),
                                    FlSpot(6, 1.6),
                                    FlSpot(7, 1.4),
                                    FlSpot(8, 1.2),
                                    FlSpot(9, 1.5),
                                    FlSpot(10, 1.3),
                                    FlSpot(11, 1.8),
                                  ],
                                  isCurved: true,
                                  color: const Color(
                                      0xFF2196F3), // Solid blue line
                                  barWidth: 2,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF2196F3).withAlpha(51),
                                        const Color(0xFF2196F3).withAlpha(13),
                                        Colors.transparent,
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.0, 0.7, 1.0],
                                    ),
                                  ),
                                ),
                              ],
                              lineTouchData:
                                  const LineTouchData(enabled: false),
                            ),
                          ),
                        ),
                      ),
                      // BPM Circle
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(
                              color: Colors.white10,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withAlpha(26),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Colors.white24,
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  bpm,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              const Text(
                                'BPM',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  // Metrics Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          "LAST NIGHT'S METRICS",
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.white54,
                            fontSize: 15, // Increased from 14
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.info_outline,
                          color: Colors.white.withAlpha(102), // Match demo page
                          size: 16,
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
                                title: 'HEART\nRATE',
                                value: bpm,
                                unit: 'BPM',
                                range: 'within 60-100',
                                icon: Icons.favorite,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'BLOOD\nOXYGEN',
                                value: spo2,
                                unit: '%',
                                range: 'within 95-100',
                                icon: Icons.air,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'TEMPERATURE',
                                value: temperature,
                                unit: '°C',
                                range: 'within 36.1-37.2',
                                icon: Icons.thermostat,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'BLOOD\nPRESSURE',
                                value: bloodPressure,
                                unit: 'mmHg',
                                range: 'within 90/60-120/80',
                                icon: Icons.speed,
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
                            const SizedBox(width: 16),
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
    // Get the color based on the metric type
    Color getColor() {
      switch (icon) {
        case Icons.favorite:
          return const Color(0xFFFF1744); // Heart Rate - Red
        case Icons.air:
          return const Color(0xFF00B0FF); // Blood Oxygen - Blue
        case Icons.thermostat:
          return const Color(0xFFFFAB40); // Temperature - Orange
        case Icons.speed:
          return const Color(0xFFE040FB); // Blood Pressure - Purple
        case Icons.water_drop:
          return const Color(0xFF64FFDA); // Blood Sugar - Teal
        default:
          return Colors.white;
      }
    }

    final color = getColor();

    // Add special handling for blood pressure text size
    final bool isBloodPressure = icon == Icons.speed;
    final double valueFontSize =
        isBloodPressure ? 26 : 30; // Smaller for blood pressure
    final double unitFontSize =
        isBloodPressure ? 11 : 12; // Smaller for blood pressure

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withAlpha(77),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18, // Increased from 16
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: color.withAlpha(180),
                    fontSize: 12, // Increased from 10
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    height: 1.6,
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
                  fontFamily: 'Roboto',
                  color: color,
                  fontSize: valueFontSize, // Dynamic font size
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: color.withAlpha(180),
                    fontSize: unitFontSize, // Dynamic font size
                    fontWeight: FontWeight.w400,
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
                size: 13, // Increased from 12
              ),
              const SizedBox(width: 4),
              Text(
                range,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: Color(0xFF4CAF50),
                  fontSize: 10, // Increased from 9
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
