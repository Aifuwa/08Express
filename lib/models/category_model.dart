import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppCategory {
  final String id;
  final String name;
  final String imageUrl;
  final IconData? icon; 
  final int? order; 
  final bool active; 

  AppCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.icon,
    this.order,
    this.active = true,
  });

  factory AppCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppCategory(
      id: doc.id,
      name: data['name'] as String? ?? 'New Category',
      imageUrl: data['imageUrl'] as String? ?? '',
      icon: data['iconName'] != null ? _getIconData(data['iconName'] as String) : null,
      order: (data['order'] is int) ? data['order'] as int : (data['order'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }

  static IconData? _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'restaurant': return Icons.restaurant;
      case 'grocery': return Icons.local_grocery_store;
      case 'baby': return Icons.child_care;
      case 'drinks': return Icons.local_drink;
      case 'devices': return Icons.devices_other;
      case 'home': return Icons.chair;
      default: return Icons.category; 
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'order': order,
      'active': active,
    };
  }
}