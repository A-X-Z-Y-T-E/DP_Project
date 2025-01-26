import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dp_project/controllers/bluetooth_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Scanner'),
      ),
      body: GetBuilder<BluetoothController>(
        init: BluetoothController(),
        builder: (controller) {
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 50,
                  width: 200,
                  color: Colors.red,
                  child: const Center(
                      child: Text(
                    'Bluetooth App',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  )),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 50),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    onPressed: () => controller.scanDevices(),
                    child: const Text(
                      'Scan Devices',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Obx(() => ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.scanResults.length,
                      itemBuilder: (context, index) {
                        final device = controller.scanResults[index].device;
                        return Card(
                          child: ListTile(
                            title: Text(device.name.isEmpty
                                ? 'Unknown Device'
                                : device.name),
                            subtitle: Text(device.id.id),
                            trailing: Text(
                                '${controller.scanResults[index].rssi} dBm'),
                          ),
                        );
                      },
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}
