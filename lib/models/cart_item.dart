// lib/models/cart_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/product.dart'; // Import Product model

class CartItem {
  final String productId; // The ID of the product
  final String name;
  final double price;
  final String imageUrl;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
  });

  // Convert Product to CartItem (for initial addition to cart)
  factory CartItem.fromProduct(Product product, {int quantity = 1}) {
    return CartItem(
      productId: product.id,
      name: product.name,
      price: product.price,
      imageUrl: product.imageUrl,
      quantity: quantity,
    );
  }

  // Convert a Firestore document snapshot to a CartItem
  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CartItem(
      productId: doc.id, // The doc ID in 'cart' sub-collection is the productId
      name: data['name'] ?? 'Unknown Product',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] ?? '',
      quantity: (data['quantity'] ?? 1).toInt(),
    );
  }

  // Convert CartItem to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'addedAt': FieldValue.serverTimestamp(), // Useful for ordering/tracking
    };
  }

  // Helper to update quantity
  void updateQuantity(int newQuantity) {
    if (newQuantity > 0) {
      quantity = newQuantity;
    }
  }
}