import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';

class HealthHistoryPage extends StatefulWidget {
  const HealthHistoryPage({Key? key}) : super(key: key);

  @override
  State<HealthHistoryPage> createState() => _HealthHistoryPageState();
}

class _HealthHistoryPageState extends State<HealthHistoryPage> {
  final UserController _userController = Get.find<UserController>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _healthRecords = [];
  String _selectedFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_userController.username.isEmpty) {
        setState(() {
          _isLoading = false;
          _healthRecords = [];
        });
        return;
      }

      // Reference to the user's health readings collection
      final healthRef = _db
          .collection('users')
          .doc(_userController.username.value)
          .collection('health_readings');

      // Create query based on filters
      Query query = healthRef.orderBy('timestamp', descending: true);

      if (_startDate != null && _endDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!));
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(
                _endDate!.add(const Duration(days: 1))));
      }

      final querySnapshot = await query.get();
      final records = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Convert Timestamp to DateTime
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        return {
          'id': doc.id,
          'timestamp': timestamp,
          'steps': data['steps'] ?? 0,
          'skinTemperature': data['skinTemperature'] ?? 36.5,
          'fallDetected': data['fallDetected'] ?? false,
          'deviceName': data['deviceName'] ?? 'Unknown Device',
        };
      }).toList();

      setState(() {
        _isLoading = false;
        _healthRecords = records;
      });
    } catch (e) {
      print('Error loading health data: $e');
      setState(() {
        _isLoading = false;
        _healthRecords = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Health History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _healthRecords.isEmpty
                    ? const Center(
                        child: Text(
                          'No health records available',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: const Color(0xFF2C2C2C),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Records',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showDatePicker(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E3E3E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _startDate == null
                          ? 'Start Date'
                          : DateFormat('MM/dd/yyyy').format(_startDate!),
                      style: TextStyle(
                        color: _startDate == null ? Colors.grey : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showDatePicker(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E3E3E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _endDate == null
                          ? 'End Date'
                          : DateFormat('MM/dd/yyyy').format(_endDate!),
                      style: TextStyle(
                        color: _endDate == null ? Colors.grey : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 40),
            ),
            onPressed: _loadHealthData,
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _healthRecords.length,
      itemBuilder: (context, index) {
        final record = _healthRecords[index];
        final formattedDate = DateFormat('MMM dd, yyyy - HH:mm').format(record['timestamp']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF2C2C2C),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            onTap: () => _showRecordDetails(record),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Fall detection indicator with improved visibility
                      if (record['fallDetected'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.warning_amber_rounded, 
                                color: Colors.white, 
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'FALL DETECTED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Display key health metrics
                  Row(
                    children: [
                      _buildMetricCard(
                        Icons.device_thermostat,
                        '${record['skinTemperature'].toStringAsFixed(1)}°C',
                        'Skin Temp',
                        Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _buildMetricCard(
                        Icons.directions_walk,
                        '${record['steps']}',
                        'Steps',
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Add device information at the bottom
                  Text(
                    'Device: ${record['deviceName']}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF3E3E3E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF2C2C2C),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF3E3E3E),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is not before start date
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // Ensure start date is not after end date
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _showRecordDetails(Map<String, dynamic> record) {
    final formattedDate = DateFormat('MMMM dd, yyyy - HH:mm:ss')
        .format(record['timestamp']);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add fall detection banner at the top of details if detected
              if (record['fallDetected'] == true)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Fall detected in this recording. User may have required assistance.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Center(
                child: Text(
                  'Health Record Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                formattedDate,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Skin Temperature', '${record['skinTemperature'].toStringAsFixed(1)}°C'),
              _buildDetailRow('Steps Count', '${record['steps']}'),
              _buildDetailRow(
                'Fall Detection Status', 
                record['fallDetected'] ? 'Fall Detected' : 'No Falls Detected',
                valueColor: record['fallDetected'] ? Colors.red : Colors.green,
                icon: record['fallDetected'] 
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                iconColor: record['fallDetected'] ? Colors.red : Colors.green,
              ),
              _buildDetailRow('Device', record['deviceName']),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: iconColor ?? valueColor ?? Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
