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
  bool _isGuestMode = false;
  bool _isLoading = true; 
  bool _isProfileLoaded = false; 
  bool _isFirstTime = true; 
  bool _isTransitioning = false; 

  // --- DOCUMENTATION IMPLEMENTATION: PHONE AUTH STATE ---
  String? _verificationId;
  int? _resendToken;

  UserProvider() {
    _initUserProvider();
  }

  Future<void> _initUserProvider() async {
    try {
      // 1. Load the intro status from local memory (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      _isFirstTime = prefs.getBool('is_first_time') ?? true;
      
      // 2. Monitor Firebase Authentication changes
      _auth.authStateChanges().listen((firebaseUser) async {
        _firebaseUser = firebaseUser;
        
        if (_firebaseUser != null) {
          _isGuestMode = false;
          // Trigger profile loading immediately upon valid login
          await _loadAppUser(_firebaseUser!.uid);
        } else {
          // If no user is found, reset internal states
          _appUser = null;
          _isProfileLoaded = false;
          _isGuestMode = false;
        }
        
        // Finalize the initial loading phase
        _isLoading = false; 
        notifyListeners(); 
      });
    } catch (e) {
      debugPrint("Initialization Error: $e");
      _isLoading = false;
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
  bool get isFirstTime => _isFirstTime;
  bool get isTransitioning => _isTransitioning;

  // --- DOCUMENTATION IMPLEMENTATION: MANUAL PHONE AUTH FLOW ---

  Future<void> verifyPhoneNumber(String phoneNumber, {
    required Function(String code) onCodeSent,
    required Function(String error) onFailed,
    required Function() onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      // 1. Instant verification or Auto-retrieval
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        onAutoVerified();
      },
      // 2. Failure Handling (Quota, Invalid Format, etc)
      verificationFailed: (FirebaseAuthException e) {
        String errorMessage = "Verification failed";
        if (e.code == 'invalid-phone-number') {
          errorMessage = "The provided phone number is not valid.";
        } else if (e.code == 'too-many-requests') {
          errorMessage = "SMS quota exceeded. Please try again later.";
        }
        onFailed(errorMessage);
      },
      // FIXED: Parameter name corrected to codeSent (resolves build error)
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        onCodeSent(verificationId);
      },
      // 4. Auto-retrieval timeout
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

  // --- TRANSITIONS & INTRO ---
  Future<void> startLoginTransition() async {
    _isTransitioning = true;
    notifyListeners();
    // Provides time for the "Securing Session" animation/blur to play
    await Future.delayed(const Duration(milliseconds: 2000));
    _isTransitioning = false;
    notifyListeners();
  }

  Future<void> completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);
    _isFirstTime = false;
    // NotifyListeners tells AuthWrapper to switch from Onboarding to AuthScreen
    notifyListeners(); 
  }

  // --- PROFILE LOADING & SYNC ---
  Future<void> _loadAppUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get().timeout(const Duration(seconds: 8));
      
      if (doc.exists) {
        _appUser = AppUser.fromFirestore(doc);

        // FIX: Ensure EMAIL address is never missing from the Drawer or Profile.
        // If the database field is empty, patch it using the Firebase Auth email.
        if ((_appUser!.email == null || _appUser!.email!.isEmpty) && _firebaseUser?.email != null) {
          _appUser!.email = _firebaseUser!.email;
          await _firestore.collection('users').doc(uid).update({'email': _appUser!.email});
        }
      } else {
        // Create a new database document if one doesn't exist (Registration flow)
        await createInitialUserDocument(_firebaseUser!);
      }
      
      _isProfileLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Firestore load error: $e");
      // Still set to true to prevent infinite loading screens
      _isProfileLoaded = true; 
      notifyListeners();
    }
  }

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
        await docRef.set(newUser.toFirestore());
        _appUser = newUser;
      } else {
        _appUser = AppUser.fromFirestore(doc);
      }
      _isProfileLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Initial document creation failed: $e");
    }
  }

  // --- PROFILE UPDATE METHODS ---
  Future<void> updateAppUserProfile({String? name, String? imageUrl, String? phoneNumber}) async {
    if (_firebaseUser == null) {
      return;
    }
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

  Future<void> completeProfileSetup({
    required String name,
    required String phone,
    required String street,
    required String city,
    required String state,
  }) async {
    if (_firebaseUser == null) {
      return;
    }

    final address = UserAddress(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      street: street, city: city, state: state,
      zipCode: "", country: "Nigeria", isDefault: true,
    );

    // Save additional details collected from the "Welcome" screen
    await _firestore.collection('users').doc(_firebaseUser!.uid).update({
      'name': name,
      'phoneNumber': phone,
      'addresses': [address.toMap()],
      'setupComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // RE-LOAD profile to ensure local model has all data (including the original email)
    await _loadAppUser(_firebaseUser!.uid);
  }

  Future<void> uploadProfileImage(File imageFile) async {
     if (_firebaseUser == null) {
       return;
     }
     try {
       String fileName = 'profile_${_firebaseUser!.uid}.jpg';
       Reference ref = _storage.ref().child('user_profiles').child(fileName);
       await ref.putFile(imageFile);
       String url = await ref.getDownloadURL();
       // Update state using the generic method above
       await updateAppUserProfile(imageUrl: url);
     } catch (e) {
       debugPrint("Upload failed: $e");
     }
  }

  // --- AUTH ACTIONS ---
  Future<void> sendPasswordReset(String email) async {
    // DOCUMENTATION IMPLEMENTATION: Explicit call to send reset link
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
      // Delete from Firestore, then delete Auth account
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      await signOut();
    }
  }

  // --- ADDRESS MANAGEMENT ---
  Future<void> addAddress(UserAddress newAddress) async {
     if (_appUser == null) {
       return;
     }
     if (newAddress.isDefault) { 
       for (var addr in _appUser!.addresses) {
         addr.isDefault = false;
       } 
     }
     _appUser!.addresses.add(newAddress);
     await _saveAddressesToFirestore();
  }

  Future<void> updateAddress(UserAddress updatedAddress) async {
    if (_appUser == null) {
      return;
    }
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
     if (_appUser == null) {
       return;
     }
     _appUser!.addresses.removeWhere((addr) => addr.id == addressId);
     await _saveAddressesToFirestore();
  }

  Future<void> _saveAddressesToFirestore() async {
    if (_firebaseUser == null) {
      return;
    }
    await _firestore.collection('users').doc(_firebaseUser!.uid).update({
      'addresses': _appUser!.addresses.map((addr) => addr.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  // --- PERSISTENT WISHLIST ---
  bool isInWishlist(String productId) => _appUser?.wishlist.contains(productId) ?? false;

  Future<void> toggleWishlist(String productId) async {
    if (_firebaseUser == null || _appUser == null) {
      return;
    }
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
  
  void enterGuestMode() { 
    _isGuestMode = true; 
    notifyListeners(); 
  }

  // --- LOGOUT (FIXED LOGIN LOOP) ---
  Future<void> signOut() async { 
    await _auth.signOut(); 
    // CRITICAL: Force reset every piece of state to ensure the next user starts clean
    _firebaseUser = null;
    _appUser = null; 
    _isGuestMode = false; 
    _isProfileLoaded = false; 
    _isTransitioning = false;
    notifyListeners(); 
  }
}