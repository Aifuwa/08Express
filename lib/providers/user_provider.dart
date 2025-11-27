import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/services/auth_service.dart';
import 'package:eight_express/models/app_user.dart'; // Make sure UserAddress is also accessible

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  AppUser? _appUser;

  UserProvider() {
    _authService.user.listen((firebaseUser) {
      _firebaseUser = firebaseUser;
      if (_firebaseUser != null) {
        _loadAppUser(_firebaseUser!.uid);
      } else {
        _appUser = null;
        notifyListeners();
      }
    });
  }

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isAuthenticated => _firebaseUser != null;

  Future<void> _loadAppUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _appUser = AppUser.fromFirestore(doc);
        _appUser?.email ??= _firebaseUser?.email;
        _appUser?.phoneNumber ??= _firebaseUser?.phoneNumber;
      } else {
        _appUser = AppUser(
          uid: uid,
          email: _firebaseUser?.email,
          phoneNumber: _firebaseUser?.phoneNumber,
        );
        await _firestore.collection('users').doc(uid).set(_appUser!.toFirestore());
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading app user: $e");
      _appUser = null;
      notifyListeners();
    }
  }

  // --- Authentication methods (unchanged) ---
  Future<User?> registerWithEmail(String email, String password) async {
    User? user = await _authService.registerWithEmailAndPassword(email, password);
    return user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    User? user = await _authService.signInWithEmailAndPassword(email, password);
    return user;
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String smsCodeSentId, int? resendToken) smsCodeSentCallback,
    required Function(FirebaseAuthException e) verificationFailed,
    Function(PhoneAuthCredential credential)? codeAutoVerified,
    Function(String verificationId)? codeAutoRetrievalTimeout,
  }) async {
    await _authService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      smsCodeSentCallback: smsCodeSentCallback,
      verificationFailed: verificationFailed,
      codeAutoVerified: codeAutoVerified,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<User?> signInWithSmsCode(String smsCode) async {
    User? user = await _authService.signInWithSmsCode(smsCode);
    return user;
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  // --- User Profile Update Methods (New/Updated) ---

  Future<void> updateAppUserProfile({String? name, String? imageUrl, String? phoneNumber}) async {
    if (_firebaseUser == null) return;

    Map<String, dynamic> updateData = {};
    if (name != null) {
      updateData['name'] = name;
      _appUser?.name = name;
    }
    if (imageUrl != null) {
      updateData['imageUrl'] = imageUrl;
      _appUser?.imageUrl = imageUrl;
    }
    // Update phone number in Firestore (if provided and different)
    if (phoneNumber != null && phoneNumber != _appUser?.phoneNumber) {
      updateData['phoneNumber'] = phoneNumber;
      _appUser?.phoneNumber = phoneNumber;
    }

    if (updateData.isNotEmpty) {
      await _firestore.collection('users').doc(_firebaseUser!.uid).update(updateData);
      notifyListeners();
    }
  }

  // --- Address Management Methods (New) ---

  Future<void> addAddress(UserAddress newAddress) async {
    if (_firebaseUser == null) return;

    // Ensure only one address is default at a time
    if (newAddress.isDefault) {
      _appUser?.addresses.forEach((addr) => addr.isDefault = false);
    }
    // Add the new address
    _appUser?.addresses.add(newAddress);

    await _firestore.collection('users').doc(_firebaseUser!.uid).update({
      'addresses': _appUser!.addresses.map((addr) => addr.toMap()).toList(),
    });
    notifyListeners();
  }

  Future<void> updateAddress(UserAddress updatedAddress) async {
    if (_firebaseUser == null) return;

    int index = _appUser!.addresses.indexWhere((addr) => addr.id == updatedAddress.id);
    if (index != -1) {
      // If the updated address is set as default, clear default from others
      if (updatedAddress.isDefault) {
        for (var i = 0; i < _appUser!.addresses.length; i++) {
          if (i != index) {
            _appUser!.addresses[i].isDefault = false;
          }
        }
      }
      _appUser!.addresses[index] = updatedAddress; // Update the address in the list

      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'addresses': _appUser!.addresses.map((addr) => addr.toMap()).toList(),
      });
      notifyListeners();
    }
  }

  Future<void> deleteAddress(String addressId) async {
    if (_firebaseUser == null) return;

    _appUser?.addresses.removeWhere((addr) => addr.id == addressId);

    await _firestore.collection('users').doc(_firebaseUser!.uid).update({
      'addresses': _appUser!.addresses.map((addr) => addr.toMap()).toList(),
    });
    notifyListeners();
  }
}