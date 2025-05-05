import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart'; // Import the intl package for DateFormat

class HealthHistoryPage extends StatefulWidget {
  const HealthHistoryPage({super.key});

  @override
  State<HealthHistoryPage> createState() => _HealthHistoryPageState();
}

class _HealthHistoryPageState extends State<HealthHistoryPage> {
  final _db = FirebaseFirestore.instance;
  final userController = Get.find<UserController>();
  String? expandedChart; // Track which chart is expanded
  
  // Cache the processed data to avoid repeated calculations
  List<QueryDocumentSnapshot>? _cachedReadings;
  List<Map<String, dynamic>>? _cachedHeartRateData;
  List<Map<String, dynamic>>? _cachedHrvData;
  List<Map<String, dynamic>>? _cachedStepsData;
  List<Map<String, dynamic>>? _cachedSkinTempData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
        title: const Text('Health History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .doc(userController.username.value)
            .collection('health_readings')
            .orderBy('timestamp', descending: true)
            // Limit the query to improve performance
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final readings = snapshot.data!.docs;
          
          // Only process data if it has changed
          if (_cachedReadings == null || 
              _cachedReadings!.length != readings.length ||
              (_cachedReadings!.isNotEmpty && readings.isNotEmpty && 
               _cachedReadings!.first.id != readings.first.id)) {
            _processData(readings);
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HRV Chart
                  _buildChartContainer(
                    'hrv', 
                    'Heart Rate Variability (ms)', 
                    Colors.orange, 
                    _cachedHrvData ?? []
                  ),

                  // Readings List Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Health Readings History',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Readings List - Use ListView.builder with itemExtent for better performance
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: readings.length,
                    itemBuilder: (context, index) {
                      // Use const where possible to reduce rebuilds
                      if (index >= readings.length) return const SizedBox.shrink();
                      
                      final data = readings[index].data() as Map<String, dynamic>;
                      final timestamp = (data['timestamp'] as Timestamp).toDate();
                      return _buildReadingCard(
                          data, timestamp, readings[index].id);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Process and cache data
  void _processData(List<QueryDocumentSnapshot> readings) {
    _cachedReadings = readings;
    
    final sortedReadings = readings.toList()
      ..sort((a, b) {
        final aTime =
            (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
        final bTime =
            (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
        return aTime.compareTo(bTime);
      });
    
    // Get only the latest 10 readings for the charts
    final latestReadings = sortedReadings.length > 10 
        ? sortedReadings.sublist(sortedReadings.length - 10) 
        : sortedReadings;
    
    // Pre-process data for charts
    _cachedHeartRateData = latestReadings
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
        
    _cachedHrvData = latestReadings
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
        
    _cachedStepsData = latestReadings
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
        
    _cachedSkinTempData = latestReadings
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  // Extract chart container to reduce rebuilds
  Widget _buildChartContainer(String field, String title, Color color, List<Map<String, dynamic>> data) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: expandedChart == field ? 450 : 250,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: GestureDetector(
        onTap: () => _toggleChart(field),
        child: _buildChart(title, data, field, color),
      ),
    );
  }

  void _toggleChart(String chartName) {
    setState(() {
      expandedChart = expandedChart == chartName ? null : chartName;
    });
  }

  Widget _buildChart(String title, List<Map<String, dynamic>> data,
      String field, Color color) {
    // Get the date of the latest reading for display at the top
    String dateDisplay = '';
    if (data.isNotEmpty) {
      final latestTimestamp = data.last['timestamp'] as Timestamp;
      final latestDate = latestTimestamp.toDate();
      dateDisplay = '${latestDate.day}/${latestDate.month}/${latestDate.year}';
    }

    // Get the latest value for display
    String latestValue = '';
    if (data.isNotEmpty) {
      latestValue = '${data.last[field]}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
            ),
            if (latestValue.isNotEmpty)
              Text(
                latestValue,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
          ],
        ),
        // Display date at the top of the graph
        if (dateDisplay.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Date: $dateDisplay',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'Montserrat',
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: SfCartesianChart(
            backgroundColor: Colors.transparent,
            plotAreaBorderWidth: 0,
            margin: const EdgeInsets.all(16), // Increased margin
            // Reduce rendering quality for better performance
            enableAxisAnimation: false,
            enableSideBySideSeriesPlacement: false,
            primaryXAxis: DateTimeAxis(
              isVisible: true, // Keep axis visible
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 1, color: Colors.grey),
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
              dateFormat: DateFormat('HH:mm'), // Simplified format to just hour:minutes
              intervalType: DateTimeIntervalType.minutes,
              interval: 5, // Show labels every 5 minutes for better spacing
              labelRotation: 0,
              labelAlignment: LabelAlignment.center,
              majorTickLines: const MajorTickLines(size: 0, width: 0), // Remove tick lines
            ),
            primaryYAxis: NumericAxis(
              isVisible: true, // Always make Y-axis visible
              majorGridLines: MajorGridLines(
                width: 0.5,
                color: Colors.grey[800],
              ),
              axisLine: const AxisLine(width: 0),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              minimum: field == 'hrv' ? 20 : null, // Set minimum value for HRV
              maximum: field == 'hrv' ? 100 : null, // Set maximum value for HRV
              interval: field == 'hrv' ? 10 : null, // Set interval for HRV
            ),
            series: <CartesianSeries<Map<String, dynamic>, DateTime>>[
              SplineSeries<Map<String, dynamic>, DateTime>(
                dataSource: data,
                xValueMapper: (Map<String, dynamic> data, _) =>
                    (data['timestamp'] as Timestamp).toDate(),
                yValueMapper: (Map<String, dynamic> data, _) {
                  final value = data[field];
                  return value != null ? (value as num).toDouble() : 0;
                },
                color: color,
                width: 3, // Increased line width
                enableTooltip: true,
                // Simplify marker settings for better performance
                markerSettings: MarkerSettings(
                  isVisible: true,
                  color: color,
                  borderColor: Colors.black,
                  borderWidth: 1,
                  height: 8, // Increased marker size
                  width: 8,  // Increased marker size
                ),
                // Reduce animation duration
                animationDuration: 500,
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              activationMode: ActivationMode.longPress,
              color: color.withOpacity(0.9),
              borderColor: Colors.white.withAlpha(50),
              borderWidth: 1,
              textStyle: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 14, // Reduced font size
                fontWeight: FontWeight.w500,
              ),
              duration: 2000, // Reduced duration
              canShowMarker: true,
              header: '',
              opacity: 0.9,
              shadowColor: Colors.black26,
              elevation: 4, // Reduced elevation
              decimalPlaces: 1,
              tooltipPosition: TooltipPosition.pointer,
              builder: (dynamic data, dynamic point, dynamic series,
                  int pointIndex, int seriesIndex) {
                final DateTime time = point.x;
                final String formattedTime = DateFormat('HH:mm:ss').format(time);
                final String formattedDate = DateFormat('dd/MM/yyyy').format(time);
                
                return Container(
                  padding: const EdgeInsets.all(12), // Reduced padding
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontSize: 12, // Reduced font size
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$title: ${point.y}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontSize: 14, // Reduced font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Time: $formattedTime',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontSize: 12, // Reduced font size
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            zoomPanBehavior: ZoomPanBehavior(
              enablePinching: expandedChart != null,
              enableDoubleTapZooming: expandedChart != null,
              enablePanning: expandedChart != null,
              // Reduce zoom factor for better performance
              zoomMode: ZoomMode.x,
            ),
          ),
        ),
      ],
    );
  }

  // Optimize reading card with const where possible
  Widget _buildReadingCard(
      Map<String, dynamic> data, DateTime timestamp, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withAlpha(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with timestamp and delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Reading on ${timestamp.toString().split('.')[0]}',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Colors.red.withAlpha(150),
                    size: 20,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => _deleteReading(id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Metrics in a Wrap widget to handle overflow better
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                _buildMetricChip('HRV', '${data['hrv']} ms', Colors.orange),
                if (data['steps'] != null)
                  _buildMetricChip('Steps', '${data['steps']}', Colors.green),
                _buildMetricChip(
                  'Skin Temp', 
                  data['skinTemperature'] != null 
                      ? '${data['skinTemperature'].toStringAsFixed(1)}°C' 
                      : 'N/A', 
                  Colors.blue
                ),
                _buildMetricChip(
                  'Fall',
                  data['fallDetected'] != null 
                      ? (data['fallDetected'] == true ? 'Detected' : 'None') 
                      : 'Unknown',
                  data['fallDetected'] != null 
                      ? (data['fallDetected'] == true ? Colors.red : Colors.grey) 
                      : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Create a more compact metric display using chips
  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withAlpha(200),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Keep the old method for backward compatibility if needed
  Widget _buildMetric(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withAlpha(150),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontFamily: 'Roboto',
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReading(String id) async {
    try {
      await _db
          .collection('users')
          .doc(userController.username.value)
          .collection('health_readings')
          .doc(id)
          .delete();
      Get.snackbar('Success', 'Reading deleted');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete reading: $e');
    }
  }
}
