import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class HealthHistoryPage extends StatefulWidget {
  const HealthHistoryPage({super.key});

  @override
  State<HealthHistoryPage> createState() => _HealthHistoryPageState();
}

class _HealthHistoryPageState extends State<HealthHistoryPage> {
  final _db = FirebaseFirestore.instance;
  final userController = Get.find<UserController>();
  String? expandedChart; // Track which chart is expanded

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
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final readings = snapshot.data!.docs;

          return Column(
            children: [
              // Charts
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Heart Rate Chart
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: expandedChart == 'heartRate' ? 400 : 200,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withAlpha(50)),
                      ),
                      child: GestureDetector(
                        onTap: () => _toggleChart('heartRate'),
                        child: _buildChart('Heart Rate (BPM)', readings,
                            'heartRate', Colors.red),
                      ),
                    ),

                    // SpO2 Chart
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: expandedChart == 'spo2' ? 400 : 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withAlpha(50)),
                      ),
                      child: GestureDetector(
                        onTap: () => _toggleChart('spo2'),
                        child: _buildChart(
                            'SpO2 (%)', readings, 'spo2', Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

              // Readings List
              Expanded(
                child: ListView.builder(
                  itemCount: readings.length,
                  itemBuilder: (context, index) {
                    final data = readings[index].data() as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp).toDate();
                    return _buildReadingCard(
                        data, timestamp, readings[index].id);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleChart(String chartName) {
    setState(() {
      expandedChart = expandedChart == chartName ? null : chartName;
    });
  }

  Widget _buildChart(String title, List<QueryDocumentSnapshot> readings,
      String field, Color color) {
    final sortedReadings = readings.toList()
      ..sort((a, b) {
        final aTime =
            (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
        final bTime =
            (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
        return aTime.compareTo(bTime);
      });

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
            if (sortedReadings.isNotEmpty)
              Text(
                '${(sortedReadings.last.data() as Map<String, dynamic>)[field]}',
                style: TextStyle(
                  color: color,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SfCartesianChart(
            backgroundColor: Colors.transparent,
            plotAreaBorderWidth: 0,
            primaryXAxis: DateTimeAxis(
              isVisible: expandedChart != null,
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 0),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            primaryYAxis: NumericAxis(
              isVisible: expandedChart != null,
              majorGridLines: MajorGridLines(
                width: 0.5,
                color: Colors.grey[800],
              ),
              axisLine: const AxisLine(width: 0),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            series: <CartesianSeries<Map<String, dynamic>, DateTime>>[
              SplineSeries<Map<String, dynamic>, DateTime>(
                dataSource: sortedReadings
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList(),
                xValueMapper: (Map<String, dynamic> data, _) =>
                    (data['timestamp'] as Timestamp).toDate(),
                yValueMapper: (Map<String, dynamic> data, _) =>
                    (data[field] as num).toDouble(),
                color: color,
                width: 2,
                enableTooltip: true,
                markerSettings: MarkerSettings(
                  isVisible: true,
                  color: color,
                  borderColor: Colors.black,
                  borderWidth: 2,
                  height: 8,
                  width: 8,
                ),
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
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              format: '$title: point.y\nTime: point.x',
              duration: 3000,
              canShowMarker: true,
              header: '',
              opacity: 0.9,
              shadowColor: Colors.black26,
              elevation: 8,
              decimalPlaces: 1,
              tooltipPosition: TooltipPosition.pointer,
              builder: (dynamic data, dynamic point, dynamic series,
                  int pointIndex, int seriesIndex) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$title: ${point.y}\nTime: ${point.x}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
            zoomPanBehavior: ZoomPanBehavior(
              enablePinching: expandedChart != null,
              enableDoubleTapZooming: expandedChart != null,
              enablePanning: expandedChart != null,
            ),
          ),
        ),
      ],
    );
  }

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
      child: ListTile(
        title: Text(
          'Reading on ${timestamp.toString().split('.')[0]}',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetric('Heart Rate', '${data['heartRate']} BPM', Colors.red),
            _buildMetric('SpO2', '${data['spo2']}%', Colors.blue),
            _buildMetric(
                'Temperature', '${data['temperature']}°C', Colors.green),
            _buildMetric(
                'Blood Sugar', '${data['bloodSugar']} mg/dL', Colors.orange),
            _buildMetric(
              'Blood Pressure',
              '${data['bloodPressure']['systolic']}/${data['bloodPressure']['diastolic']}',
              Colors.purple,
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete,
            color: Colors.red.withAlpha(150),
          ),
          onPressed: () => _deleteReading(id),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withAlpha(150),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontFamily: 'Roboto',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
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
