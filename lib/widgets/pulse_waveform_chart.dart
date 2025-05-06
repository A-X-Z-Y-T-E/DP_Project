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
  
  // Track the last data we processed to detect changes
  List<int> _lastProcessedData = [];
  int _updateCounter = 0;

  @override
  void initState() {
    super.initState();
    
    try {
      _controller = Get.find<BluetoothController>();
      
      // Use a higher refresh rate for smoother animation
      _refreshTimer = Timer.periodic(Duration(milliseconds: 16), (_) {
        if (mounted) {
          _updateChartData();
        }
      });
      
      // Fix: Use custom listener instead of 'ever' to avoid type issues
      // Create a worker to listen for changes to the pulse data
      final worker = ever<List<int>>(_controller!.pulseWaveformData as RxInterface<List<int>>, _processNewData);
      
      // Make sure to dispose the worker when the widget is disposed
      // We'll save a reference to it
    } catch (e) {
      print("Error initializing chart: $e");
    }
  }
  
  // Separate method to process new data
  void _processNewData(List<int> newData) {
    if (mounted && newData.length == 56) {
      // This callback is triggered whenever new data arrives
      print('New pulse data received: ${newData.length} points');
      
      // Process the new data and update the chart
      if (!_areListsEqual(newData, _lastProcessedData)) {
        setState(() {
          _spots = _createSpots(newData);
          _lastProcessedData = List<int>.from(newData);
          _updateCounter++;
        });
      }
    }
  }
  
  bool _areListsEqual(List<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
  
  void _updateChartData() {
    if (!mounted || _controller == null) return;
    
    final pulseData = _controller!.pulseWaveformData;
    if (pulseData.isNotEmpty && pulseData.length == 56) {
      // Only update if data changed since last time to avoid unnecessary redraws
      if (!_areListsEqual(pulseData, _lastProcessedData)) {
        setState(() {
          _spots = _createSpots(pulseData);
          _lastProcessedData = List<int>.from(pulseData);
          _updateCounter++;
        });
      }
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

    // Create spots if needed
    if (_spots.isEmpty && data.isNotEmpty) {
      _spots = _createSpots(data);
      _lastProcessedData = List<int>.from(data);
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
    return Stack(
      children: [
        LineChart(
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
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    // Show markers at regular intervals that match the screenshot
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
            maxX: 55, // Always show all 56 points (0-55)
            minY: 0,
            maxY: 200, // Fixed scale to match STM toolbox
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: const Color(0xDD2C2C2C),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    if (index >= 0 && index < _controller!.pulseWaveformData.length) {
                      // Show the value in decimal and hex format
                      final value = _controller!.pulseWaveformData[index];
                      final hexValue = value.toRadixString(16).padLeft(8, '0').toUpperCase();
                      return LineTooltipItem(
                        'Value: $value (0x$hexValue)',
                        TextStyle(color: widget.lineColor, fontWeight: FontWeight.bold),
                      );
                    }
                    return LineTooltipItem(
                      'Value: ${spot.y.round()}',
                      TextStyle(color: widget.lineColor, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                }
              ),
              touchSpotThreshold: 20,
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
          // Fix: Remove swapAnimationDuration parameter as it's not supported
        ),
        
        // Show update indicator
        Positioned(
          top: 5,
          right: 5,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _updateCounter % 2 == 0 ? Colors.green : Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
  
  List<FlSpot> _createSpots(List<int> pulseData) {
    // Create exactly 56 spots for the full waveform display
    List<FlSpot> spots = [];
    
    for (int i = 0; i < pulseData.length; i++) {
      // X-axis is the sample index (0-55)
      double x = i.toDouble();
      
      // Y-axis is the value, clamped to chart range
      double y = pulseData[i].toDouble().clamp(0.0, 200.0);
      
      spots.add(FlSpot(x, y));
    }
    
    return spots;
  }
}