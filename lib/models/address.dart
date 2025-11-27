// lib/models/address.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  String? id; // Optional: if you want to store multiple addresses and identify them
  String street;
  String city;
  String state;
  String zipCode;
  String country;
  bool isDefault;

  Address({
    this.id,
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    this.isDefault = false,
  });

  // Factory constructor to create Address from a Map (e.g., from Firestore)
  factory Address.fromMap(Map<String, dynamic> data, {String? docId}) {
    return Address(
      id: docId,
      street: data['street'] as String? ?? '',
      city: data['city'] as String? ?? '',
      state: data['state'] as String? ?? '',
      zipCode: data['zipCode'] as String? ?? '',
      country: data['country'] as String? ?? '',
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  // Method to convert Address to a Map for Firestore storage
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