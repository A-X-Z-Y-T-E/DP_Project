import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show debugPrint;

final FirebaseAuth _auth = FirebaseAuth.instance;
final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: ['email'],
  signInOption: SignInOption.standard,
);

//SIGN IN WITH GOOGLE
Future<User?> signInWithGoogle() async {
  try {
    // Check if already signed in
    GoogleSignInAccount? currentUser = googleSignIn.currentUser;
    if (currentUser == null) {
      currentUser = await googleSignIn.signInSilently();
    }

    // If still null, trigger interactive sign in
    currentUser ??= await googleSignIn.signIn();

    if (currentUser == null) {
      debugPrint('Google Sign In was cancelled');
      return null;
    }

    debugPrint('Signed in with email: ${currentUser.email}');

    // Get auth details
    final GoogleSignInAuthentication googleAuth =
        await currentUser.authentication;

    // Create Firebase credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in with Firebase
    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  } catch (e) {
    debugPrint('Sign in error details: $e');
    return null;
  }
}

//SIGN OUT
Future<void> signOut() async {
  await _auth.signOut();
  await googleSignIn.signOut();
}
