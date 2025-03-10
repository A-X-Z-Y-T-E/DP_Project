import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class BluetoothScanPage extends StatelessWidget {
  const BluetoothScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
        title: const Text(
          'Bluetooth Scanner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
      ),
      body: GetBuilder<BluetoothController>(
        init: BluetoothController(),
        builder: (controller) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.bluetooth_searching,
                        size: 50,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: controller.isScanning
                            ? controller.stopScan
                            : controller.startScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              controller.isScanning ? Colors.red : Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          controller.isScanning ? 'STOP SCAN' : 'SCAN DEVICES',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: StreamBuilder<List<ScanResult>>(
                    stream: FlutterBluePlus.scanResults,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.bluetooth_disabled,
                                size: 50,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No devices found',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return AnimationLimiter(
                        child: ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final result = snapshot.data![index];
                            final device = result.device;
                            final rssi = result.rssi;
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 200),
                              child: SlideAnimation(
                                horizontalOffset: 100.0,
                                curve: Curves.easeOutQuart,
                                child: FadeInAnimation(
                                  curve: Curves.easeOutQuart,
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    color: const Color(0xFF2C2C2C),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        final BluetoothController controller =
                                            Get.find();
                                        controller.connectToDevice(device);
                                      },
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.blue,
                                        child: Icon(
                                          Icons.bluetooth,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        device.name.isEmpty
                                            ? 'Unknown Device'
                                            : device.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        device.id.id,
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$rssi dBm',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
