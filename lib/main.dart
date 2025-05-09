import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:Vital_Monitor/views/login.dart';
import 'package:Vital_Monitor/views/home_page.dart';
import 'package:Vital_Monitor/firebase_options.dart';
import 'package:Vital_Monitor/controllers/user_controller.dart';
import 'package:Vital_Monitor/controllers/bluetooth_controller.dart';
import 'package:get_storage/get_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize GetStorage first
  await GetStorage.init();

  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize user controller
  Get.put(UserController());

  // Initialize the BluetoothController at app startup
  Get.put(BluetoothController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();

    return GetMaterialApp(
      title: 'Vital Monitor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.white,
      ),
      home: Obx(() =>
          userController.username.isEmpty ? const Login() : const HomePage()),
      debugShowCheckedModeBanner: false,
    );
  }
}
