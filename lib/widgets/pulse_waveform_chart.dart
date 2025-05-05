import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';

class PulseWaveformChart extends StatelessWidget {
  final Color lineColor;
  final double height;
  final bool showPoints;

  const PulseWaveformChart({
    Key? key,
    this.lineColor = Colors.green,
    this.height = 200.0,
    this.showPoints = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely get the controller instance
    final BluetoothController controller;
    try {
      controller = Get.find<BluetoothController>();
    } catch (e) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Bluetooth controller not available',
            style: TextStyle(color: lineColor.withOpacity(0.7)),
          ),
        ),
      );
    }
    
    return SizedBox(
      height: height,
      child: Obx(() {
        final pulseData = controller.pulseWaveformData;
        
        // Check data availability
        if (pulseData.isEmpty) {
          return Center(
            child: Text(
              'Waiting for pulse data...',
              style: TextStyle(color: lineColor.withOpacity(0.7)),
            ),
          );
        }

        // Create spots from pulse waveform data
        final spots = pulseData.asMap().entries.map((entry) {
          final index = entry.key.toDouble();
          final value = entry.value.toDouble();
          return FlSpot(index, value);
        }).toList();

        // Calculate max Y with some padding
        double maxY = pulseData.isEmpty ? 255.0 : 
                    (pulseData.reduce((a, b) => a > b ? a : b) * 1.2);
                    
        // Ensure maxY is at least 10 to prevent scaling issues
        if (maxY < 10) maxY = 255;

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.white10,
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 50,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: lineColor.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: spots.isEmpty ? 10 : spots.length.toDouble() - 1,
            minY: 0,
            maxY: maxY,
            lineTouchData: LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: lineColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: showPoints,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: lineColor,
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: lineColor.withOpacity(0.15),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
