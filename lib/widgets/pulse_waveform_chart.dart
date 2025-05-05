import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';

class PulseWaveformChart extends StatefulWidget {
  final Color lineColor;
  final double height;
  final String title;

  const PulseWaveformChart({
    Key? key,
    this.lineColor = Colors.green,
    this.height = 200.0,
    this.title = 'Pulse Waveform',
  }) : super(key: key);

  @override
  State<PulseWaveformChart> createState() => _PulseWaveformChartState();
}

class _PulseWaveformChartState extends State<PulseWaveformChart> with SingleTickerProviderStateMixin {
  BluetoothController? _controller;
  Timer? _refreshTimer;
  List<FlSpot> _spots = [];
  Map<String, double> _yRange = {'min': 0, 'max': 200};

  @override
  void initState() {
    super.initState();
    
    try {
      _controller = Get.find<BluetoothController>();
      
      // Only refresh the UI with a timer
      _refreshTimer = Timer.periodic(Duration(milliseconds: 16), (_) {
        if (mounted) {
          _updateChartData();
        }
      });
    } catch (e) {
      print("Error initializing chart: $e");
    }
  }
  
  void _updateChartData() {
    if (!mounted || _controller == null) return;
    
    final pulseData = _controller!.pulseWaveformData;
    if (pulseData.isNotEmpty) {
      setState(() {
        _spots = _createSpots(pulseData);
      });
    }
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Try to get the controller if it wasn't initialized or was lost
    if (_controller == null) {
      try {
        _controller = Get.find<BluetoothController>();
      } catch (e) {
        return _buildErrorContainer('Bluetooth controller not available');
      }
    }

    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              Text(
                'Data points: ${_controller?.pulseWaveformData.length ?? 0}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_controller == null) {
      return Center(
        child: Text(
          'Controller not available',
          style: TextStyle(color: widget.lineColor.withOpacity(0.7)),
        ),
      );
    }

    final data = _controller!.pulseWaveformData;
    if (data.isEmpty) {
      return _buildWaitingView();
    }

    if (_spots.isEmpty) {
      _spots = _createSpots(data);
    }

    return _buildWaveformChart();
  }
  
  Widget _buildErrorContainer(String message) {
    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2433),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                message,
                style: TextStyle(color: widget.lineColor.withOpacity(0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: widget.lineColor,
            strokeWidth: 2.0,
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for real-time data from\ncharacteristic 0010',
            style: TextStyle(color: widget.lineColor.withOpacity(0.9)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildWaveformChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 40,
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
            axisNameWidget: null,
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 40 == 0 && value >= 0 && value <= 200) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: widget.lineColor.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: Colors.white24),
            bottom: BorderSide.none,
            right: BorderSide.none,
            top: BorderSide.none,
          ),
        ),
        minX: 0,
        maxX: _spots.isEmpty ? 10 : _spots.length.toDouble() - 1,
        minY: 0,
        maxY: 200,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xDD2C2C2C),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'Value: ${spot.y.toInt()}',
                  TextStyle(color: widget.lineColor, fontWeight: FontWeight.bold),
                );
              }).toList();
            }
          ),
          touchSpotThreshold: 10,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: widget.lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: widget.lineColor.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
  
  List<FlSpot> _createSpots(List<int> pulseData) {
    return pulseData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      // Use the actual values from the device, clamped to our display range
      final deviceValue = entry.value.toDouble().clamp(0.0, 200.0);
      return FlSpot(index, deviceValue);
    }).toList();
  }
}