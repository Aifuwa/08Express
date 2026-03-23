import 'dart:io';
import 'dart:async';
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
  bool _isIntroCheckDone = false; // Confirms SharedPreferences have been read
  bool _isTransitioning = false; 
  bool _isIntroCompleted = false; // Flag used by main.dart RootGatekeeper

  // Phone Auth State
  String? _verificationId;
  int? _resendToken;

  // --- INITIALIZATION ---
  UserProvider() {
    _initUserProvider();
  }

  /// Initializes the provider by checking local onboarding status 
  /// and listening to Firebase Auth state changes.
  Future<void> _initUserProvider() async {
    try {
      // 1. Load Local Storage (Onboarding Status)
      final prefs = await SharedPreferences.getInstance();
      _isFirstTime = prefs.getBool('is_first_time') ?? true;
      
      // Sync the completion flag with the local storage value
      if (!_isFirstTime) {
        _isIntroCompleted = true;
      }
      
      _isIntroCheckDone = true; 
      notifyListeners(); 
      
      // 2. Listen to Persistent Auth Changes
      _auth.authStateChanges().listen((firebaseUser) async {
        _firebaseUser = firebaseUser;
        
        if (_firebaseUser != null) {
          // User is authenticated
          _isGuestMode = false;
          _isLoading = true; 
          notifyListeners();

          // Load the specific user profile from Firestore
          await fetchUserProfile();
        } else {
          // User is logged out or session expired
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
      _isIntroCheckDone = true; 
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
  bool get isFirstTime => _isFirstTime;
  bool get isIntroCheckDone => _isIntroCheckDone;
  bool get isIntroCompleted => _isIntroCompleted; // The getter required by main.dart
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;

  // --- CORE PROFILE MANAGEMENT ---

  /// Fetches the user document from Firestore.
  Future<void> fetchUserProfile() async {
    if (_firebaseUser == null) return;

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(_firebaseUser!.uid)
          .get()
          .timeout(const Duration(seconds: 15));
      
      if (doc.exists) {
        _appUser = AppUser.fromFirestore(doc);
        _isGuestMode = false; 

        // DATA REPAIR: If Firestore has no email, but Firebase Auth does, sync them.
        if ((_appUser!.email == null || _appUser!.email!.isEmpty) && _firebaseUser?.email != null) {
          _appUser!.email = _firebaseUser!.email;
          await _firestore.collection('users').doc(_firebaseUser!.uid).update({
            'email': _appUser!.email,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Critical: Auth exists but DB document is missing (e.g. manual delete in console)
        await createInitialUserDocument(_firebaseUser!);
      }
      
      _isProfileLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      _isProfileLoaded = true; 
      notifyListeners();
    }
  }

  /// Creates the database entry for a new user with default fields.
  Future<void> createInitialUserDocument(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);

      AppUser newUser = AppUser(
        uid: user.uid,
        email: user.email, 
        name: user.displayName ?? (user.email != null ? user.email!.split('@')[0] : "User"),
        isAdmin: false,
        setupComplete: false, 
        wishlist: [],
        addresses: [],
      );

      // Persist to database
      await docRef.set(newUser.toFirestore());
      
      // Update local state
      _appUser = newUser;
      _isProfileLoaded = true;
      _isGuestMode = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Initial document creation failed: $e");
    }
  }

  /// CRITICAL: Completes the user's profile with delivery details.
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
      // 1. Update Firestore Database
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'name': name,
        'phoneNumber': phone,
        'addresses': [address.toMap()],
        'setupComplete': true, 
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Local State Immediately
      if (_appUser != null) {
        _appUser!.name = name;
        _appUser!.phoneNumber = phone;
        _appUser!.addresses = [address];
        _appUser!.setupComplete = true;
      } else {
        await fetchUserProfile();
      }
      
      notifyListeners(); 
    } catch (e) {
      debugPrint("Error completing setup: $e");
      rethrow; 
    }
  }

  /// Generic method to update specific user profile fields.
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
      
      // Delete from DB first, then Auth
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

  /// Marks the intro/onboarding screen as seen forever.
  Future<void> completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);
    _isFirstTime = false;
    _isIntroCompleted = true; // Update the flag for RootGatekeeper
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
    try {
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'addresses': _appUser!.addresses.map((addr) => addr.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Address Sync Error: $e");
    }
  }

  bool isInWishlist(String productId) => _appUser?.wishlist.contains(productId) ?? false;

  Future<void> toggleWishlist(String productId) async {
    if (_firebaseUser == null || _appUser == null) return;
    
    // Optimistic UI Update
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
      await fetchUserProfile();
    }
  }
  
  /// Uploads and updates profile picture.
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
       rethrow;
     }
  }
}