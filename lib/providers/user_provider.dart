import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:eight_express/models/app_user.dart';

class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isGuestMode = false;
  bool _isLoading = true; 
  String? _verificationId;

  UserProvider() {
    _auth.authStateChanges().listen((firebaseUser) async {
      _firebaseUser = firebaseUser;
      if (_firebaseUser != null) {
        _isGuestMode = false;
        await _loadAppUser(_firebaseUser!.uid);
      } else {
        _appUser = null;
      }
      _isLoading = false; 
      notifyListeners(); 
    });
  }

  // --- GETTERS ---
  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isAuthenticated => _firebaseUser != null; 
  bool get isGuest => _isGuestMode;
  bool get isLoading => _isLoading; 

  void enterGuestMode() {
    _isGuestMode = true;
    notifyListeners();
  }

  Future<void> _loadAppUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _appUser = AppUser.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Error loading AppUser: $e");
    }
  }

  // --- EMAIL AUTH ---

  Future<void> registerWithEmail(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());

      if (result.user != null) {
        AppUser newUser = AppUser(
          uid: result.user!.uid,
          email: email.trim(),
          name: name,
        );
        await _firestore.collection('users').doc(result.user!.uid).set(newUser.toFirestore());
        await result.user!.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Registration failed";
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Login failed";
    }
  }

  Future<bool> checkEmailVerified() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload(); 
      return _auth.currentUser!.emailVerified;
    }
    return false;
  }

  // --- PHONE OTP AUTH ---

  Future<void> sendOTP(String phoneNumber, {required Function(String) onCodeSent, required Function(String) onError}) async {
    try {
      String formattedPhone = _formatToE164(phoneNumber);
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (cred) async => await _auth.signInWithCredential(cred),
        verificationFailed: (e) => onError(e.message ?? "Verification failed"),
        codeSent: (id, token) {
          _verificationId = id; 
          onCodeSent(id);
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> verifyOTPAndLogin(String smsCode, {String? name}) async {
    if (_verificationId == null) throw "Verification session expired.";
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: smsCode.trim());

      UserCredential result = await _auth.signInWithCredential(credential);
      if (result.user != null) {
        final doc = await _firestore.collection('users').doc(result.user!.uid).get();
        if (!doc.exists) {
          AppUser newUser = AppUser(
            uid: result.user!.uid,
            phoneNumber: result.user!.phoneNumber,
            name: name ?? "User",
          );
          await _firestore.collection('users').doc(result.user!.uid).set(newUser.toFirestore());
        }
      }
    } catch (e) {
      throw "Invalid Code. Please try again.";
    }
  }

  // --- ACCOUNT & PASSWORD MGMT ---

  Future<void> signOut() async {
    await _auth.signOut();
    _isGuestMode = false;
    _appUser = null;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Error sending reset link.";
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) return;
    AuthCredential cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount(String password) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) return;
    AuthCredential cred = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(cred);
    await _firestore.collection('users').doc(user.uid).delete();
    await user.delete();
    await signOut();
  }

  // --- PROFILE & IMAGES ---

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
    if (phoneNumber != null) {
      updateData['phoneNumber'] = phoneNumber;
      _appUser?.phoneNumber = phoneNumber;
    }
    await _firestore.collection('users').doc(_firebaseUser!.uid).update(updateData);
    notifyListeners();
  }

  Future<void> uploadProfileImage(File imageFile) async {
     if (_firebaseUser == null) return;
     String fileName = 'profile_${_firebaseUser!.uid}.jpg';
     Reference ref = _storage.ref().child('user_profiles').child(fileName);
     await ref.putFile(imageFile);
     String url = await ref.getDownloadURL();
     await updateAppUserProfile(imageUrl: url);
  }

  // --- WISHLIST ---

  bool isInWishlist(String productId) {
    if (_appUser == null) return false;
    return _appUser!.wishlist.contains(productId);
  }

  Future<void> toggleWishlist(String productId) async {
    if (_firebaseUser == null || _appUser == null) return;

    if (_appUser!.wishlist.contains(productId)) {
      _appUser!.wishlist.remove(productId);
    } else {
      _appUser!.wishlist.add(productId);
    }
    notifyListeners();

    try {
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'wishlist': _appUser!.wishlist,
      });
    } catch (e) {
      debugPrint("Wishlist sync error: $e");
    }
  }

  // --- ADDRESS MGMT ---

  Future<void> addAddress(UserAddress newAddress) async {
     if (_appUser == null) return;
     if (newAddress.isDefault) { 
       for (var addr in _appUser!.addresses) {
         addr.isDefault = false;
       } 
     }
     _appUser!.addresses.add(newAddress);
     await _saveAddresses();
  }

  Future<void> updateAddress(UserAddress updatedAddress) async {
    if (_appUser == null) return;
    int index = _appUser!.addresses.indexWhere((addr) => addr.id == updatedAddress.id);
    if (index != -1) {
      if (updatedAddress.isDefault) {
        for (var addr in _appUser!.addresses) {
          addr.isDefault = false;
        }
      }
      _appUser!.addresses[index] = updatedAddress;
      await _saveAddresses();
    }
  }

  Future<void> deleteAddress(String addressId) async {
     if (_appUser == null) return;
     _appUser!.addresses.removeWhere((addr) => addr.id == addressId);
     await _saveAddresses();
  }

  Future<void> _saveAddresses() async {
    if (_firebaseUser == null || _appUser == null) return;
    await _firestore.collection('users').doc(_firebaseUser!.uid).update({
      'addresses': _appUser!.addresses.map((addr) => addr.toMap()).toList(),
    });
    notifyListeners();
  }

  // --- HELPERS ---

  String _formatToE164(String input) {
    if (input.startsWith('+')) return input;
    String clean = input.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.startsWith('0')) clean = clean.substring(1);
    if (!clean.startsWith('234')) clean = '234$clean';
    return '+$clean';
  }
}