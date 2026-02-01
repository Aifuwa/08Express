// lib/models/product.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl; // Primary thumbnail (backward compatibility)
  final List<String> images; // NEW: List of all images
  final String category; 
  final int stock;
  final Timestamp createdAt;
  final bool active;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.images,
    required this.category,
    required this.stock,
    required this.createdAt,
    this.active = true,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // 1. Handle Multiple Images Logic
    List<String> parsedImages = [];
    if (data['images'] != null) {
      // If 'images' array exists in Firebase, use it
      parsedImages = List<String>.from(data['images']);
    } 
    
    // 2. Fallback: If 'images' list is empty but 'imageUrl' exists, use that.
    if (parsedImages.isEmpty && data['imageUrl'] != null) {
      parsedImages.add(data['imageUrl']);
    }

    return Product(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      description: data['description'] ?? 'No Description',
      price: (data['price'] ?? 0.0).toDouble(),
      // Ensure imageUrl always has a valid string for thumbnails
      imageUrl: parsedImages.isNotEmpty ? parsedImages[0] : (data['imageUrl'] ?? ''),
      images: parsedImages,
      category: data['category'] ?? 'Uncategorized',
      stock: (data['stock'] ?? 0).toInt(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      active: data['active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'images': images, // Save the list back to Firestore
      'category': category,
      'stock': stock,
      'createdAt': createdAt,
      'active': active,
    };
  }
}