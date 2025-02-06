import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Vital_Monitor/views/health_monitor_page.dart';

class DemoPage extends StatelessWidget {
  DemoPage({super.key});

  final TextEditingController bpmController = TextEditingController(text: '75');
  final TextEditingController spo2Controller =
      TextEditingController(text: '98');
  final TextEditingController tempController =
      TextEditingController(text: '37.2');
  final TextEditingController systolicController =
      TextEditingController(text: '120');
  final TextEditingController diastolicController =
      TextEditingController(text: '80');
  final TextEditingController sugarController =
      TextEditingController(text: '95');

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
          'DEMO MODE',
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
        decoration: const BoxDecoration(
          color: Colors.black, // Simple black background
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white.withAlpha(3),
                Colors.white.withAlpha(5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 0.8, 1.0],
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withAlpha(30),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.devices,
                          size: 40,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          "ENTER VITAL SIGNS",
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.info_outline,
                          color: Colors.white.withAlpha(102),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInputField(
                    controller: bpmController,
                    label: 'HEART RATE',
                    hint: 'Enter BPM',
                    keyboardType: TextInputType.number,
                    icon: Icons.favorite,
                    color: const Color(0xFFFF1744),
                    range: '60-100 BPM',
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: spo2Controller,
                    label: 'BLOOD OXYGEN',
                    hint: 'Enter SpO2',
                    keyboardType: TextInputType.number,
                    icon: Icons.air,
                    color: const Color(0xFF00B0FF),
                    range: '95-100%',
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: tempController,
                    label: 'TEMPERATURE',
                    hint: 'Enter temperature',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    icon: Icons.thermostat,
                    color: const Color(0xFFFFAB40),
                    range: '36.1-37.2°C',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: systolicController,
                          label: 'SYSTOLIC',
                          hint: 'mmHg',
                          keyboardType: TextInputType.number,
                          icon: Icons.speed,
                          color: const Color(0xFFE040FB),
                          range: '90-120',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInputField(
                          controller: diastolicController,
                          label: 'DIASTOLIC',
                          hint: 'mmHg',
                          keyboardType: TextInputType.number,
                          icon: Icons.speed,
                          color: const Color(0xFFE040FB),
                          range: '60-80',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: sugarController,
                    label: 'BLOOD SUGAR',
                    hint: 'Enter mg/dL',
                    keyboardType: TextInputType.number,
                    icon: Icons.water_drop,
                    color: const Color(0xFF64FFDA),
                    range: '70-140 mg/dL',
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.withAlpha(77),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Get.to(() => HealthMonitorPage(
                                deviceName: 'Demo Device',
                                deviceId: 'DEMO-001',
                                bpm: bpmController.text,
                                spo2: spo2Controller.text,
                                temperature: tempController.text,
                                bloodPressure:
                                    '${systolicController.text}/${diastolicController.text}',
                                bloodSugar: sugarController.text,
                              ));
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: const Center(
                          child: Text(
                            'START MONITORING',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Colors.green,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
    required IconData icon,
    required Color color,
    required String range,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: color.withAlpha(180),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withAlpha(77),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: 'Roboto',
                color: color.withAlpha(77),
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
