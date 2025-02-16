import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:Vital_Monitor/views/login.dart';

class UserController extends GetxController {
  final username = ''.obs;
  final _db = FirebaseFirestore.instance;
  final _storage = GetStorage();

  @override
  void onInit() {
    super.onInit();
    // Check if user is already logged in
    final savedUsername = _storage.read('username');
    if (savedUsername != null) {
      username.value = savedUsername;
    }
  }

  void login(String user) async {
    username.value = user;
    _storage.write('username', user); // Save to persistent storage
    await _saveUserToFirestore();
  }

  void logout() {
    username.value = '';
    _storage.remove('username'); // Clear from storage
    Get.offAll(() => const Login());
  }

  Future<void> _saveUserToFirestore() async {
    try {
      await _db.collection('users').doc(username.value).set({
        'username': username.value,
        'lastLogin': DateTime.now(),
      });
    } catch (e) {
      print('Error saving user: $e');
    }
  }
}
