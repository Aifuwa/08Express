// eight_express/lib/admin_panel/models/product.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  String? id; // Nullable for new products before they get an ID from Firestore
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final int stock;
  final String category;

  Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.stock,
    required this.category,
  });

  // Factory constructor to create a Product from a Firestore DocumentSnapshot
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      stock: (data['stock'] ?? 0).toInt(),
      category: data['category'] ?? 'Uncategorized',
    );
  }

  // Method to convert a Product object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'stock': stock,
      'category': category,
      'timestamp': FieldValue.serverTimestamp(), // Add a timestamp for creation/update
    };
  }
}