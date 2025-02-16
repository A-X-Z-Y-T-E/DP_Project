import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Vital_Monitor/views/demo_page.dart';
import 'package:Vital_Monitor/views/bluetooth_scan_page.dart';
import 'package:Vital_Monitor/services/auth.dart';
import 'package:Vital_Monitor/views/login.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
        title: const Text(
          'Health Monitor',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              final userController = Get.find<UserController>();
              userController.logout();
            },
          ),
        ],
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButton(
                title: 'Bluetooth Scan',
                icon: Icons.bluetooth_searching,
                color: Colors.blue,
                onPressed: () => Get.to(() => const BluetoothScanPage()),
              ),
              const SizedBox(height: 20),
              _buildButton(
                title: 'Demo Mode',
                icon: Icons.devices,
                color: Colors.green,
                onPressed: () => Get.to(() => DemoPage()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withAlpha(51),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: color,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
