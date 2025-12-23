import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> get user {
    return _firebaseAuth.authStateChanges();
  }

  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      // Send Verification Email immediately after signup
      if (result.user != null && !result.user!.emailVerified) {
        await result.user!.sendEmailVerification();
      }
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth Error: ${e.message}");
      throw e;
    } catch (e) {
      throw Exception("An unknown error occurred");
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth Error: ${e.message}");
      throw e;
    } catch (e) {
      throw Exception("An unknown error occurred");
    }
  }

  // --- NEW: Password Reset ---
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}