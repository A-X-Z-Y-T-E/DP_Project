import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show debugPrint;

final FirebaseAuth _auth = FirebaseAuth.instance;
final GoogleSignIn googleSignIn = GoogleSignIn();

//SIGN IN WITH GOOGLE
Future<User?> signInWithGoogle() async {
  try {
    // Clear previous sign in
    await googleSignIn.signOut();

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    debugPrint('Signed in: ${userCredential.user?.email}');
    return userCredential.user;
  } catch (e) {
    debugPrint('Sign in error: $e');
    return null;
  }
}

//SIGN OUT
Future<void> signOut() async {
  await _auth.signOut();
  await googleSignIn.signOut();
}
