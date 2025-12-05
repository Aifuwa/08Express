import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Required for image upload
import 'package:eight_express/services/auth_service.dart';
import 'package:eight_express/models/app_user.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; 

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

  // --- Authentication methods ---
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

  // --- Password Management ---
  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (_firebaseUser == null || _firebaseUser!.email == null) {
      throw FirebaseAuthException(code: 'no-user', message: 'No user logged in');
    }

    // 1. Re-authenticate user (Security requirement by Firebase)
    AuthCredential credential = EmailAuthProvider.credential(
      email: _firebaseUser!.email!,
      password: currentPassword,
    );

    await _firebaseUser!.reauthenticateWithCredential(credential);

    // 2. Update Password
    await _firebaseUser!.updatePassword(newPassword);
  }

  // --- Profile Image Management ---
  Future<void> uploadProfileImage(File imageFile) async {
    if (_firebaseUser == null) return;

    try {
      // Create a unique file name or overwrite existing one
      String fileName = 'profile_${_firebaseUser!.uid}.jpg';
      Reference ref = _storage.ref().child('user_profiles').child(fileName);

      // Upload file
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      // Get URL
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore and Local State
      await updateAppUserProfile(imageUrl: downloadUrl);
    } catch (e) {
      debugPrint("Error uploading image: $e");
      rethrow;
    }
  }

  // --- User Profile Update ---
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
    if (phoneNumber != null && phoneNumber != _appUser?.phoneNumber) {
      updateData['phoneNumber'] = phoneNumber;
      _appUser?.phoneNumber = phoneNumber;
    }

    if (updateData.isNotEmpty) {
      await _firestore.collection('users').doc(_firebaseUser!.uid).update(updateData);
      notifyListeners();
    }
  }

  // --- Address Management ---
  Future<void> addAddress(UserAddress newAddress) async {
    if (_firebaseUser == null) return;
    if (newAddress.isDefault) {
      _appUser?.addresses.forEach((addr) => addr.isDefault = false);
    }
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
      if (updatedAddress.isDefault) {
        for (var i = 0; i < _appUser!.addresses.length; i++) {
          if (i != index) {
            _appUser!.addresses[i].isDefault = false;
          }
        }
      }
      _appUser!.addresses[index] = updatedAddress;
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