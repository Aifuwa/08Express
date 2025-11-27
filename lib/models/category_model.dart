// lib/models/category_model.dart (Corrected and Refined)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Required for IconData

class AppCategory {
  final String id;
  final String name;
  final String imageUrl;
  final IconData? icon; // Optional: for a fallback icon
  final int? order; // Optional: for sorting
  final bool active; // Optional: to enable/disable category

  AppCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.icon,
    this.order,
    this.active = true, // Default to active
  });

  // Factory constructor to create an AppCategory object from a Firestore DocumentSnapshot
  factory AppCategory.fromFirestore(DocumentSnapshot doc) {
    // Ensure data exists and is a Map before casting
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      // Handle the case where the document data is null,
      // though Firestore typically doesn't return null data for existing docs.
      // This is more for safety if somehow doc.data() returned null.
      return AppCategory(
        id: doc.id,
        name: 'Invalid Category',
        imageUrl: 'https://via.placeholder.com/150',
        active: false, // Mark as inactive or invalid
      );
    }

    return AppCategory(
      id: doc.id,
      name: data['name'] as String? ?? 'Unknown Category', // Use `as String? ??` for safer type casting and default
      imageUrl: data['imageUrl'] as String? ?? 'https://via.placeholder.com/150',
      icon: data['iconName'] != null ? _getIconData(data['iconName'] as String) : null, // Ensure iconName is a String
      order: (data['order'] is int) ? data['order'] as int : (data['order'] as num?)?.toInt(), // Handle both int and num from Firestore
      active: data['active'] as bool? ?? true, // Use `as bool? ??` for safer type casting and default
    );
  }

  // Helper function to convert a string iconName from Firestore to a Flutter IconData
  static IconData? _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant;
      case 'devices_other': return Icons.devices_other;
      case 'watch': return Icons.watch;
      case 'book': return Icons.book;
      case 'ramen_dining': return Icons.ramen_dining;
      case 'local_grocery_store': return Icons.local_grocery_store;
      case 'fashion_handbag': return Icons.shopping_bag; // Example: if you have a fashion category
      case 'fastfood': return Icons.fastfood;
      case 'sports_esports': return Icons.sports_esports;
      case 'fitness_center': return Icons.fitness_center;
      case 'home_furniture': return Icons.chair; // Example for furniture
      case 'car_parts': return Icons.car_repair; // Example for automotive
      case 'pets': return Icons.pets;
      case 'baby_child': return Icons.child_care;
      case 'art_crafts': return Icons.palette;
      case 'garden': return Icons.yard;
      // Add more cases as needed for other icons that match your Firestore 'iconName' values
      default: return Icons.category; // Default fallback icon if name not recognized
    }
  }

  // Optional: Add a toFirestore method if you plan to save/update categories
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'iconName': icon != null ? _getIconName(icon!) : null, // Convert IconData back to string for saving
      'order': order,
      'active': active,
    };
  }

  // Helper to convert IconData back to its string name for Firestore (if needed)
  static String? _getIconName(IconData iconData) {
    // This is the reverse of _getIconData. You'll need to map your IconData back to its string representation.
    // This might be tricky if you have multiple IconData objects mapping to the same name or vice-versa.
    // A simpler approach might be to store the string name directly in the class and use it for both.
    if (iconData == Icons.restaurant) return 'restaurant';
    if (iconData == Icons.devices_other) return 'devices_other';
    // ... continue for all your icons ...
    if (iconData == Icons.category) return 'category'; // Default
    return null; // Or throw an error if icon not recognized
  }
}