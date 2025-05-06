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
    this.lineColor = Colors.red,
    this.height = 70000.0,
    this.title = 'Pulse Waveform',
  }) : super(key: key);

  @override
  State<PulseWaveformChart> createState() => _PulseWaveformChartState();
}

class _PulseWaveformChartState extends State<PulseWaveformChart> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  BluetoothController? _controller;
  Timer? _refreshTimer;
  List<FlSpot> _spots = [];
  Map<String, double> _yRange = {'min': 0, 'max': 70000}; // Updated to 70000
  
  // Track the last data we processed to detect changes
  List<int> _lastProcessedData = [];
  int _updateCounter = 0;
  
  // Track controller status 
  bool _controllerAvailable = false;
  
  // Add worker reference to explicitly dispose it
  Worker? _worker;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    _initializeController();
  }
  
  void _initializeController() {
    try {
      _controller = Get.find<BluetoothController>();
      _controllerAvailable = true;
      
      // Use a higher refresh rate for smoother animation
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (mounted) {
          _updateChartData();
        }
      });
      
      // Dispose any existing worker
      _worker?.dispose();
      
      // Create a properly typed worker to listen for changes to the pulse data
      _worker = ever<List<int>>(
        _controller!.pulseWaveformData as RxInterface<List<int>>, 
        _processNewData
      );
      
      // Initial data update
      if (_controller!.pulseWaveformData.isNotEmpty) {
        _processNewData(_controller!.pulseWaveformData);
      }
      
    } catch (e) {
      _controllerAvailable = false;
      print("Error initializing chart: $e");
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Try to re-initialize controller if needed
    if (!_controllerAvailable) {
      _initializeController();
    }
  }

  // Separate method to process new data
  void _processNewData(List<int> newData) {
    if (mounted && newData.length == 56) {
      // This callback is triggered whenever new data arrives
      
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
    _worker?.dispose(); // Properly dispose the worker
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Try to get the controller again if it was lost
    if (_controller == null || !_controllerAvailable) {
      _initializeController();
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
                'Data points: ${_controllerAvailable ? _controller?.pulseWaveformData.length ?? 0 : 0}',
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
    if (!_controllerAvailable || _controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Reconnecting to controller...',
              style: TextStyle(color: widget.lineColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.lineColor.withOpacity(0.7),
              ),
            ),
          ],
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
              horizontalInterval: 10000, // Updated for 70000 scale
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
                    // Show markers at 0, 10000, 20000, etc. up to 70000
                    if (value % 10000 == 0 && value >= 0 && value <= 70000) {
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
                  reservedSize: 45, // Increased for larger numbers
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
            minY: _yRange['min'],
            maxY: _yRange['max'], // Now using 70000 as max
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: const Color(0xDD2C2C2C),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    if (_controllerAvailable && _controller != null && 
                        index >= 0 && index < _controller!.pulseWaveformData.length) {
                      // Show the raw value in decimal and hex format
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

        // Add Y-axis scale indicator - updated to show 0-70000 range
        Positioned(
          top: 5,
          left: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Y-axis: 0-70000',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
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
      
      // Use the raw values directly - will be capped by the chart's Y range if necessary
      double y = pulseData[i].toDouble();

      // Create spot - no scaling needed as we've set the y-axis to accommodate values up to 70000
      spots.add(FlSpot(x, y));
    }
    
    return spots;
  }
}