// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For @visibleForTesting

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Stream to listen to authentication state changes (login/logout)
  Stream<User?> get user {
    return _firebaseAuth.authStateChanges();
  }

  // --- Email/Password Methods ---

  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error (Register Email): ${e.message}");
      throw e; // Re-throw to be caught by UI for specific error messages
    } catch (e) {
      debugPrint("General Error (Register Email): $e");
      throw Exception("An unknown error occurred during registration.");
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error (Sign In Email): ${e.message}");
      throw e;
    } catch (e) {
      debugPrint("General Error (Sign In Email): $e");
      throw Exception("An unknown error occurred during login.");
    }
  }

  // --- Phone Number Methods ---

  // Stores the verification ID after sending SMS
  String? _verificationId;

  // Method to send SMS code for phone number verification
  // Callback functions are used to communicate events back to the UI
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String smsCodeSentId, int? resendToken) smsCodeSentCallback,
    required Function(FirebaseAuthException e) verificationFailed,
    Function(PhoneAuthCredential credential)? codeAutoVerified, // For Android auto-retrieval
    Function(String verificationId)? codeAutoRetrievalTimeout, // When auto-retrieval times out
  }) async {
    _verificationId = null; // Reset before new verification

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval or instant verification on Android.
        // Sign the user in directly.
        await _firebaseAuth.signInWithCredential(credential);
        codeAutoVerified?.call(credential); // Notify UI if provided
      },
      verificationFailed: (FirebaseAuthException e) {
        verificationFailed(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId; // Store the ID
        smsCodeSentCallback(verificationId, resendToken); // Notify UI that code was sent
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId; // Keep the ID even if timeout
        codeAutoRetrievalTimeout?.call(verificationId);
      },
      timeout: const Duration(seconds: 60), // SMS timeout duration
    );
  }

  // Method to sign in with the SMS code received by the user
  Future<User?> signInWithSmsCode(String smsCode) async {
    if (_verificationId == null) {
      throw Exception("Phone number verification not initiated or timed out.");
    }
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      UserCredential result = await _firebaseAuth.signInWithCredential(credential);
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error (Sign In SMS): ${e.message}");
      throw e;
    } catch (e) {
      debugPrint("General Error (Sign In SMS): $e");
      throw Exception("An unknown error occurred during SMS login.");
    }
  }

  // --- Sign Out ---

  Future<void> signOut() async {
    try {
      return await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error (Sign Out): ${e.message}");
      throw e;
    } catch (e) {
      debugPrint("General Error (Sign Out): $e");
      throw Exception("An unknown error occurred during logout.");
    }
  }
}