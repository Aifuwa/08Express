import 'package:cloud_firestore/cloud_firestore.dart';

class UserAddress {
  String id; // Optional: for identifying specific addresses in Firestore subcollection
  String street;
  String city;
  String state;
  String zipCode;
  String country;
  bool isDefault;

  UserAddress({
    this.id = '', // Default to empty, will be set by Firestore
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    this.isDefault = false,
  });

  factory UserAddress.fromMap(Map<String, dynamic> data, {String? id}) {
    return UserAddress(
      id: id ?? data['id'] ?? '',
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
  final String uid; // Firebase User ID
  String? email; // Can be null if signed in with phone
  String? name;
  String? imageUrl; // For profile picture
  String? phoneNumber; // Can be null if signed in with email
  // List of addresses for the user
  List<UserAddress> addresses;

  AppUser({
    required this.uid,
    this.email,
    this.name,
    this.imageUrl,
    this.phoneNumber,
    this.addresses = const [], // Initialize with an empty list
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<UserAddress> loadedAddresses = [];
    if (data['addresses'] is List) {
      loadedAddresses = (data['addresses'] as List)
          .map((addressMap) => UserAddress.fromMap(addressMap as Map<String, dynamic>))
          .toList();
    }

    return AppUser(
      uid: doc.id,
      email: data['email'],
      name: data['name'],
      imageUrl: data['imageUrl'],
      phoneNumber: data['phoneNumber'],
      addresses: loadedAddresses,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (email != null && email!.isNotEmpty) 'email': email,
      if (name != null && name!.isNotEmpty) 'name': name,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (phoneNumber != null && phoneNumber!.isNotEmpty) 'phoneNumber': phoneNumber,
      'addresses': addresses.map((addr) => addr.toMap()).toList(), // Store addresses
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}