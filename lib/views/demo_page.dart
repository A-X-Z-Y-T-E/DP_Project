import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Vital_Monitor/views/health_monitor_page.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Vital_Monitor/views/health_history_page.dart';

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

  final _db = FirebaseFirestore.instance;
  final userController = Get.find<UserController>();

  Future<void> _saveReading(String type, double value) async {
    try {
      await _db
          .collection('users')
          .doc(userController.username.value)
          .collection('readings')
          .add({
        'type': type,
        'value': value,
        'timestamp': DateTime.now(),
      });
      debugPrint('Reading saved successfully');
    } catch (e) {
      debugPrint('Error saving reading: $e');
    }
  }

  Future<void> _saveAllReadings() async {
    try {
      await _db
          .collection('users')
          .doc(userController.username.value)
          .collection('readings')
          .add({
        'heartRate': double.parse(bpmController.text),
        'spo2': double.parse(spo2Controller.text),
        'temperature': double.parse(tempController.text),
        'systolic': double.parse(systolicController.text),
        'diastolic': double.parse(diastolicController.text),
        'bloodSugar': double.parse(sugarController.text),
        'timestamp': DateTime.now(),
      });
      debugPrint('All readings saved successfully');
    } catch (e) {
      debugPrint('Error saving readings: $e');
    }
  }

  Future<void> _saveHealthData() async {
    try {
      debugPrint('Attempting to save health data...');
      debugPrint('Current username: ${userController.username.value}');

      final data = {
        'heartRate': double.parse(bpmController.text),
        'spo2': double.parse(spo2Controller.text),
        'temperature': double.parse(tempController.text),
        'bloodPressure': {
          'systolic': double.parse(systolicController.text),
          'diastolic': double.parse(diastolicController.text),
        },
        'bloodSugar': double.parse(sugarController.text),
        'timestamp': DateTime.now(),
      };

      debugPrint('Data to save: $data');

      await _db
          .collection('users')
          .doc(userController.username.value)
          .collection('health_readings')
          .add(data);

      debugPrint('Health data saved successfully!');

      // Verify data was saved
      final snapshot = await _db
          .collection('users')
          .doc(userController.username.value)
          .collection('health_readings')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        debugPrint('Latest saved data: ${snapshot.docs.first.data()}');
      }
    } catch (e) {
      debugPrint('Error saving health data: $e');
      // Show error to user
      Get.snackbar(
        'Error',
        'Failed to save health data: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${userController.username.value}'),
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF1A1A1A),
              const Color(0xFF242424),
              Colors.grey[900]!,
              Colors.black,
            ],
            stops: const [0.0, 0.5, 0.7, 0.9, 1.0],
          ),
        ),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withAlpha(8),
                Colors.white.withAlpha(10),
                Colors.white.withAlpha(12),
                Colors.white.withAlpha(15),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 0.8, 0.9, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.overlay,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.black,
                expandedHeight: 120,
                floating: false,
                pinned: true,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                  onPressed: () => Get.back(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey,
                        child:
                            Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  centerTitle: false,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      // Tab Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTab('OVERVIEW', true),
                            _buildTab('STRAIN', false),
                            _buildTab('RECOVERY', false),
                            _buildTab('SLEEP', false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Recovery Circle
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: CircularProgressIndicator(
                              value: 0.87,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withAlpha(20),
                              color: Colors.green,
                            ),
                          ),
                          Column(
                            children: [
                              const Text(
                                '87%',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 42,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                'RECOVERY',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withAlpha(150),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'HRV 69',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: Colors.white.withAlpha(120),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Strain and Calories
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '11.8',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade300,
                                  ),
                                ),
                                Text(
                                  'DAY STRAIN',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  '1,073',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'CALORIES',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Start Activity Button
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          onPressed: () {},
                          child: const Text(
                            'START ACTIVITY',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Activity List
                      _buildActivityTile(
                        icon: Icons.directions_run,
                        color: Colors.blue,
                        title: 'RUNNING',
                        time: '9.1',
                        startTime: '7:49am',
                        endTime: '7:14am',
                      ),
                      _buildActivityTile(
                        icon: Icons.nightlight_round,
                        color: Colors.grey,
                        title: 'SLEEP',
                        time: '7:02',
                        startTime: '5:53am',
                        endTime: '(Tue) 10:30pm',
                      ),
                      const SizedBox(height: 20),
                      // Health Monitor
                      InkWell(
                        onTap: () async {
                          await _saveHealthData();
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
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite_border,
                                    color: Colors.white.withAlpha(150),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'HEALTH MONITOR',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '5/5 METRICS',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(150),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withAlpha(40),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _buildInputField(
                              label: 'HEART RATE',
                              controller: bpmController,
                              color: const Color(0xFFFF1744),
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              label: 'BLOOD OXYGEN',
                              controller: spo2Controller,
                              color: const Color(0xFF00B0FF),
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              label: 'TEMPERATURE',
                              controller: tempController,
                              color: const Color(0xFF00E676),
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              label: 'SYSTOLIC',
                              controller: systolicController,
                              color: const Color(0xFF00B0FF),
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              label: 'DIASTOLIC',
                              controller: diastolicController,
                              color: const Color(0xFF00B0FF),
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              label: 'BLOOD SUGAR',
                              controller: sugarController,
                              color: const Color(0xFF00E676),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Get.to(() => HealthHistoryPage()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(20),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.history, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'VIEW HISTORY',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withAlpha(220),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withAlpha(100),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.watch), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: ''),
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool isSelected) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.white.withAlpha(100),
          ),
        ),
        const SizedBox(height: 8),
        if (isSelected)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Widget _buildActivityTile({
    required IconData icon,
    required Color color,
    required String title,
    required String time,
    required String startTime,
    required String endTime,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            '$title $time',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            '$startTime → $endTime',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: Colors.white.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withAlpha(150),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C23),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withAlpha(26),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withAlpha(3),
                Colors.white.withAlpha(8),
                Colors.white.withAlpha(8),
                Colors.white.withAlpha(3),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: label,
              hintStyle: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withAlpha(100),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
