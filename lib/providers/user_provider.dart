import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:eight_express/services/auth_service.dart';
import 'package:eight_express/models/app_user.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; 

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isGuestMode = false;

  UserProvider() {
    _authService.user.listen((firebaseUser) {
      _firebaseUser = firebaseUser;
      if (_firebaseUser != null) {
        _isGuestMode = false;
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
  bool get isGuest => _isGuestMode;

  void enterGuestMode() {
    _isGuestMode = true;
    notifyListeners();
  }

  bool _isEmail(String input) {
    return input.contains('@');
  }

  String _normalizeToAuthEmail(String input) {
    if (_isEmail(input)) return input.trim();
    String cleanPhone = input.replaceAll(RegExp(r'[^\d]'), '');
    return '$cleanPhone@eightexpress.com'; 
  }

  // --- LOGIN ---
  Future<User?> login(String identity, String password) async {
    String authEmail = _normalizeToAuthEmail(identity);
    return await _authService.signInWithEmailAndPassword(authEmail, password);
  }

  // --- REGISTER ---
  Future<User?> register(String identity, String password, String name) async {
    String authEmail = _normalizeToAuthEmail(identity);
    bool isEmailInput = _isEmail(identity);

    User? user = await _authService.registerWithEmailAndPassword(authEmail, password);
    
    if (user != null) {
      AppUser newUser = AppUser(
        uid: user.uid,
        email: isEmailInput ? identity : authEmail,
        phoneNumber: !isEmailInput ? identity : null,
        name: name,
        addresses: [],
      );
      
      await _firestore.collection('users').doc(user.uid).set(newUser.toFirestore());
      await _loadAppUser(user.uid);
    }
    return user;
  }

  // --- RESET PASSWORD ---
  Future<void> resetPassword(String identity) async {
    String authEmail = _normalizeToAuthEmail(identity);
    await _authService.sendPasswordResetEmail(authEmail);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (_firebaseUser == null || _firebaseUser!.email == null) {
      throw FirebaseAuthException(code: 'no-user', message: 'No user logged in');
    }
    AuthCredential credential = EmailAuthProvider.credential(
      email: _firebaseUser!.email!,
      password: currentPassword,
    );
    await _firebaseUser!.reauthenticateWithCredential(credential);
    await _firebaseUser!.updatePassword(newPassword);
  }

  // --- NEW: SECURE ACCOUNT DELETION ---
  Future<void> deleteAccount(String password) async {
    if (_firebaseUser == null || _firebaseUser!.email == null) {
      throw FirebaseAuthException(code: 'no-user', message: 'No user logged in');
    }

    // 1. Re-authenticate the user (Required for sensitive operations like deletion)
    AuthCredential credential = EmailAuthProvider.credential(
      email: _firebaseUser!.email!,
      password: password,
    );
    await _firebaseUser!.reauthenticateWithCredential(credential);

    // 2. Delete User Data from Firestore
    await _firestore.collection('users').doc(_firebaseUser!.uid).delete();

    // 3. Delete from Firebase Auth
    await _firebaseUser!.delete();

    // 4. Reset Local State
    _appUser = null;
    _firebaseUser = null;
    _isGuestMode = false;
    notifyListeners();
  }

  Future<void> _loadAppUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _appUser = AppUser.fromFirestore(doc);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading user: $e");
    }
  }

  Future<void> signOut() async {
    _isGuestMode = false;
    await _authService.signOut();
  }

  Future<void> updateAppUserProfile({String? name, String? imageUrl, String? phoneNumber}) async {
    if (_firebaseUser == null) return;
    Map<String, dynamic> updateData = {};
    if (name != null) { updateData['name'] = name; _appUser?.name = name; }
    if (imageUrl != null) { updateData['imageUrl'] = imageUrl; _appUser?.imageUrl = imageUrl; }
    if (phoneNumber != null) { updateData['phoneNumber'] = phoneNumber; _appUser?.phoneNumber = phoneNumber; }
    if (updateData.isNotEmpty) {
      await _firestore.collection('users').doc(_firebaseUser!.uid).update(updateData);
      notifyListeners();
    }
  }

  Future<void> uploadProfileImage(File imageFile) async {
     if (_firebaseUser == null) return;
     try {
       String fileName = 'profile_${_firebaseUser!.uid}.jpg';
       Reference ref = _storage.ref().child('user_profiles').child(fileName);
       UploadTask uploadTask = ref.putFile(imageFile);
       TaskSnapshot snapshot = await uploadTask;
       String downloadUrl = await snapshot.ref.getDownloadURL();
       await updateAppUserProfile(imageUrl: downloadUrl);
     } catch (e) { rethrow; }
  }

  Future<void> addAddress(UserAddress newAddress) async {
     if (_firebaseUser == null) return;
     if (newAddress.isDefault) _appUser?.addresses.forEach((addr) => addr.isDefault = false);
     _appUser?.addresses.add(newAddress);
     await _saveAddresses();
  }

  Future<void> updateAddress(UserAddress updatedAddress) async {
      if (_firebaseUser == null || _appUser == null) return;
      int index = _appUser!.addresses.indexWhere((addr) => addr.id == updatedAddress.id);
      if (index != -1) {
        if (updatedAddress.isDefault) {
          for (var addr in _appUser!.addresses) addr.isDefault = false;
        }
        _appUser!.addresses[index] = updatedAddress;
        await _saveAddresses();
      }
  }

  Future<void> deleteAddress(String addressId) async {
     if (_firebaseUser == null) return;
     _appUser?.addresses.removeWhere((addr) => addr.id == addressId);
     await _saveAddresses();
  }

  Future<void> _saveAddresses() async {
    await _firestore.collection('users').doc(_firebaseUser!.uid).update({
      'addresses': _appUser!.addresses.map((addr) => addr.toMap()).toList(),
    });
    notifyListeners();
  }
}