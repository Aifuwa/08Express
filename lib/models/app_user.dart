import 'package:cloud_firestore/cloud_firestore.dart';

class UserAddress {
  String id; 
  String street;
  String city;
  String state;
  String zipCode;
  String country;
  bool isDefault;

  UserAddress({
    this.id = '', 
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    this.isDefault = false,
  });

  factory UserAddress.fromMap(Map<String, dynamic> data) {
    return UserAddress(
      id: data['id'] as String? ?? '',
      street: data['street'] as String? ?? '',
      city: data['city'] as String? ?? '',
      state: data['state'] as String? ?? '',
      zipCode: data['zipCode'] as String? ?? '',
      country: data['country'] as String? ?? '',
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
      'isDefault': isDefault,
    };
  }
}

class AppUser {
  final String uid; 
  String? email; 
  String? name;
  String? imageUrl; 
  String? phoneNumber; 
  bool isAdmin; 
  bool setupComplete; 
  List<UserAddress> addresses;
  List<String> wishlist; 

  AppUser({
    required this.uid,
    this.email,
    this.name,
    this.imageUrl,
    this.phoneNumber,
    this.isAdmin = false,
    this.setupComplete = false,
    List<UserAddress>? addresses,
    List<String>? wishlist,
  })  : addresses = addresses ?? [],
        wishlist = wishlist ?? [];

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    
    List<UserAddress> loadedAddresses = [];
    if (data['addresses'] is List) {
      loadedAddresses = (data['addresses'] as List)
          .map((addressMap) => UserAddress.fromMap(addressMap as Map<String, dynamic>))
          .toList();
    }

    return AppUser(
      uid: doc.id,
      email: data['email'] as String?, 
      name: data['name'] as String?,
      imageUrl: data['imageUrl'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      isAdmin: data['isAdmin'] as bool? ?? false,
      setupComplete: data['setupComplete'] as bool? ?? false,
      addresses: loadedAddresses,
      wishlist: List<String>.from(data['wishlist'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'imageUrl': imageUrl,
      'phoneNumber': phoneNumber,
      'isAdmin': isAdmin,
      'setupComplete': setupComplete,
      'addresses': addresses.map((addr) => addr.toMap()).toList(), 
      'wishlist': wishlist,
      'updatedAt': FieldValue.serverTimestamp(), // Necessary for Firestore Rules whitelist
    };
  }
}