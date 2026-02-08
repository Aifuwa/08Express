import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eight_express/models/app_user.dart';

class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? _firebaseUser;
  AppUser? _appUser;
  
  // --- STATE FLAGS ---
  bool _isGuestMode = false;
  bool _isLoading = true; 
  bool _isProfileLoaded = false; 
  
  // Onboarding / Intro State
  bool _isFirstTime = true; 
  bool _isIntroCheckDone = false; // New: confirms Prefs have been read
  bool _isTransitioning = false; 

  // Phone Auth State
  String? _verificationId;
  int? _resendToken;

  // --- INITIALIZATION ---
  UserProvider() {
    _initUserProvider();
  }

  Future<void> _initUserProvider() async {
    try {
      // 1. Load Local Storage (Onboarding Status)
      final prefs = await SharedPreferences.getInstance();
      _isFirstTime = prefs.getBool('is_first_time') ?? true;
      _isIntroCheckDone = true; 
      // Notify immediately so AuthWrapper knows it can proceed
      notifyListeners(); 
      
      // 2. Listen to Persistent Auth Changes (Keeps user logged in)
      _auth.authStateChanges().listen((firebaseUser) async {
        _firebaseUser = firebaseUser;
        
        if (_firebaseUser != null) {
          // User is logged in
          _isGuestMode = false;
          _isLoading = true; // Show loader while fetching profile
          notifyListeners();

          // Load the specific user profile from Firestore
          await fetchUserProfile();
        } else {
          // User is logged out
          _appUser = null;
          _isProfileLoaded = false;
          _isGuestMode = false;
        }
        
        _isLoading = false; 
        notifyListeners(); 
      });
    } catch (e) {
      debugPrint("Initialization Error: $e");
      _isLoading = false;
      _isIntroCheckDone = true; // Ensure we don't get stuck
      notifyListeners();
    }
  }

  // --- GETTERS ---
  User? get firebaseUser => _firebaseUser; 
  AppUser? get appUser => _appUser;
  bool get isAuthenticated => _firebaseUser != null; 
  bool get isGuest => _isGuestMode;
  bool get isLoading => _isLoading; 
  bool get isProfileLoaded => _isProfileLoaded;
  bool get isTransitioning => _isTransitioning;
  
  // Gatekeeper Getters
  bool get isFirstTime => _isFirstTime;
  bool get isIntroCheckDone => _isIntroCheckDone;

  // --- CORE PROFILE MANAGEMENT ---

  /// Public method to fetch/refresh the user profile from Firestore.
  Future<void> fetchUserProfile() async {
    if (_firebaseUser == null) return;

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(_firebaseUser!.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (doc.exists) {
        _appUser = AppUser.fromFirestore(doc);
        _isGuestMode = false; 

        // DATA REPAIR: If Firestore has no email, but Auth does, patch it.
        if ((_appUser!.email == null || _appUser!.email!.isEmpty) && _firebaseUser?.email != null) {
          _appUser!.email = _firebaseUser!.email;
          await _firestore.collection('users').doc(_firebaseUser!.uid).update({'email': _appUser!.email});
        }
      } else {
        // Critical: If Auth exists but Firestore doc doesn't, create it now.
        await createInitialUserDocument(_firebaseUser!);
      }
      
      _isProfileLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      // Mark as loaded even on error to stop infinite loading spinners
      _isProfileLoaded = true; 
      notifyListeners();
    }
  }

  /// Creates the database entry for a new user.
  Future<void> createInitialUserDocument(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        AppUser newUser = AppUser(
          uid: user.uid,
          email: user.email, 
          name: user.displayName ?? (user.email != null ? user.email!.split('@')[0] : "User"),
          isAdmin: false,
          setupComplete: false, 
          wishlist: [],
          addresses: [],
        );

        // Update local state immediately for UI responsiveness
        _appUser = newUser;
        _isProfileLoaded = true;
        _isGuestMode = false;
        notifyListeners();

        // Persist to database
        await docRef.set(newUser.toFirestore());
      } else {
        // If it existed (edge case), load it
        _appUser = AppUser.fromFirestore(doc);
        _isProfileLoaded = true;
        _isGuestMode = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Initial document creation failed: $e");
    }
  }

  /// Called by the Onboarding Modal in HomeScreen to finalize registration.
  Future<void> completeProfileSetup({
    required String name,
    required String phone,
    required String street,
    required String city,
    required String state,
  }) async {
    if (_firebaseUser == null) return;

    final address = UserAddress(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      street: street, 
      city: city, 
      state: state,
      zipCode: "", 
      country: "Nigeria", 
      isDefault: true,
    );

    try {
      // Update Firestore
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'name': name,
        'phoneNumber': phone,
        'addresses': [address.toMap()],
        'setupComplete': true, 
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Local State directly 
      if (_appUser != null) {
        _appUser!.name = name;
        _appUser!.phoneNumber = phone;
        _appUser!.addresses = [address];
        _appUser!.setupComplete = true;
        notifyListeners();
      } else {
        await fetchUserProfile();
      }
    } catch (e) {
      debugPrint("Error completing setup: $e");
    }
  }

  Future<void> updateAppUserProfile({String? name, String? imageUrl, String? phoneNumber}) async {
    if (_firebaseUser == null) return;

    Map<String, dynamic> updateData = {'updatedAt': FieldValue.serverTimestamp()};
    
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

  // --- AUTHENTICATION HELPERS ---

  Future<void> verifyPhoneNumber(String phoneNumber, {
    required Function(String code) onCodeSent,
    required Function(String error) onFailed,
    required Function() onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        onAutoVerified();
      },
      verificationFailed: (FirebaseAuthException e) {
        String errorMessage = "Verification failed";
        if (e.code == 'invalid-phone-number') {
          errorMessage = "The provided phone number is not valid.";
        } else if (e.code == 'too-many-requests') {
          errorMessage = "SMS quota exceeded. Please try again later.";
        }
        onFailed(errorMessage);
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> signInWithSmsCode(String smsCode) async {
    if (_verificationId == null) return;
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    User? user = _auth.currentUser;
    if (user != null && user.email != null) {
      AuthCredential cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    }
  }

  Future<void> deleteAccount(String password) async {
    User? user = _auth.currentUser;
    if (user != null && user.email != null) {
      AuthCredential cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      await signOut();
    }
  }

  // --- TRANSITIONS & GUEST MODE ---

  Future<void> startLoginTransition() async {
    _isTransitioning = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 2000));
    _isTransitioning = false;
    notifyListeners();
  }

  /// CRITICAL: Call this when user clicks "Get Started" on Onboarding Screen
  Future<void> completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);
    _isFirstTime = false;
    notifyListeners(); 
  }

  void enterGuestMode() { 
    _isGuestMode = true; 
    notifyListeners(); 
  }

  Future<void> signOut() async { 
    await _auth.signOut(); 
    _firebaseUser = null;
    _appUser = null; 
    _isGuestMode = false; 
    _isProfileLoaded = false; 
    _isTransitioning = false;
    // Note: We do NOT reset _isFirstTime here, because they have already seen intro.
    notifyListeners(); 
  }

  // --- ADDRESS & WISHLIST ---

  Future<void> addAddress(UserAddress newAddress) async {
     if (_appUser == null) return;
     if (newAddress.isDefault) { 
       for (var addr in _appUser!.addresses) {
         addr.isDefault = false;
       } 
     }
     _appUser!.addresses.add(newAddress);
     await _saveAddressesToFirestore();
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
      await _saveAddressesToFirestore();
    }
  }

  Future<void> deleteAddress(String addressId) async {
     if (_appUser == null) return;
     _appUser!.addresses.removeWhere((addr) => addr.id == addressId);
     await _saveAddressesToFirestore();
  }

  Future<void> _saveAddressesToFirestore() async {
    if (_firebaseUser == null) return;
    await _firestore.collection('users').doc(_firebaseUser!.uid).update({
      'addresses': _appUser!.addresses.map((addr) => addr.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  bool isInWishlist(String productId) => _appUser?.wishlist.contains(productId) ?? false;

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
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Wishlist sync error: $e");
    }
  }
  
  Future<void> uploadProfileImage(File imageFile) async {
     if (_firebaseUser == null) return;
     try {
       String fileName = 'profile_${_firebaseUser!.uid}.jpg';
       Reference ref = _storage.ref().child('user_profiles').child(fileName);
       await ref.putFile(imageFile);
       String url = await ref.getDownloadURL();
       await updateAppUserProfile(imageUrl: url);
     } catch (e) {
       debugPrint("Upload failed: $e");
     }
  }
}