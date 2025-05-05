import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';

class HealthMonitorPage extends StatelessWidget {
  final String deviceName;
  final String deviceId;

  HealthMonitorPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  final BluetoothController bluetoothController =
      Get.find<BluetoothController>();

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Health Monitor',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User greeting
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'Hello, ${userController.username}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Greeting spacer
            const SizedBox(height: 24),
            
            // HRV Section
            _buildSectionTitle('Heart Rate Variability'),
            const SizedBox(height: 16),
            Obx(() => _buildStatusCard(
              icon: Icons.monitor_heart,
              title: 'HRV',
              value: '${bluetoothController.hrv} ms',
              color: Colors.orange,
              description: bluetoothController.hrv > 50 ? 'Good recovery state' : 'Recovery needed',
            )),
            
            const SizedBox(height: 24),
            
            // Fall Detection Section
            _buildSectionTitle('Fall Detection'),
            const SizedBox(height: 16),
            Obx(() => _buildStatusCard(
              icon: Icons.warning_amber_rounded,
              title: 'Fall Detection',
              value: bluetoothController.fallDetected ? 'FALL DETECTED!' : 'No Falls',
              color: bluetoothController.fallDetected ? Colors.red : Colors.green,
              description: bluetoothController.fallDetected ? 'Emergency alert sent' : 'Monitoring active',
            )),
            
            const SizedBox(height: 24),
            
            // Steps Counter Section
            _buildSectionTitle('Daily Activity'),
            const SizedBox(height: 16),
            Obx(() => _buildStatusCard(
              icon: Icons.directions_walk,
              title: 'Steps',
              value: '${bluetoothController.steps}',
              color: Colors.blue,
              description: '${(bluetoothController.steps / 80).round()}% of daily goal (8,000 steps)',
              showProgressBar: true,
              progress: bluetoothController.steps / 8000,
            )),
            
            const SizedBox(height: 24),
            
            // Skin Temperature Section
            _buildSectionTitle('Skin Temperature'),
            const SizedBox(height: 16),
            Obx(() => _buildStatusCard(
              icon: Icons.thermostat,
              title: 'Skin Temperature',
              value: '${bluetoothController.skinTemperature.toStringAsFixed(1)}°C',
              color: Colors.green,
              description: bluetoothController.skinTemperature > 36.0 && bluetoothController.skinTemperature < 37.5 ? 'Within normal range' : 'Outside normal range',
            )),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String description,
    bool showProgressBar = false,
    double progress = 0.0,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          if (showProgressBar) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ],
      ),
    );
  }
}
