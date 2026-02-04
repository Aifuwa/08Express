import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/product.dart';

class CartItem {
  final String productId;
  final String name;
  final double price;
  final String imageUrl;
  
  /// This field now holds the "Effective Limit".
  /// It is the minimum of (Available Warehouse Stock) and (Customer Purchase Limit).
  final int maxStock; 
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.maxStock,
    this.quantity = 1,
  });

  /// Convert a Product model to a CartItem.
  /// This factory calculates whether the user is restricted by stock or by a custom purchase limit.
  factory CartItem.fromProduct(Product product, {int quantity = 1}) {
    int warehouseStock = product.stock;
    int purchaseLimit = product.maxPurchaseLimit;

    // Logic: Calculate the Effective Limit
    // If purchaseLimit is 0 (unlimited) or higher than warehouse stock, use warehouse stock.
    // Otherwise, use the purchaseLimit.
    int effectiveLimit = warehouseStock;
    if (purchaseLimit > 0 && purchaseLimit < warehouseStock) {
      effectiveLimit = purchaseLimit;
    }

    return CartItem(
      productId: product.id,
      name: product.name,
      price: product.price,
      imageUrl: product.imageUrl,
      maxStock: effectiveLimit, 
      quantity: quantity,
    );
  }

  /// Convert a Firestore document snapshot to a CartItem.
  /// Useful if you are persisting the cart items in a 'carts' collection in Firestore.
  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return CartItem(
      productId: doc.id,
      name: data['name'] ?? 'Unknown Product',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] ?? '',
      maxStock: (data['maxStock'] ?? 0).toInt(), 
      quantity: (data['quantity'] ?? 1).toInt(),
    );
  }

  /// Convert CartItem to a Map for Firestore.
  /// We save the 'maxStock' limit snapshot so the app doesn't have to 
  /// check the main product document every time the user clicks "+".
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'maxStock': maxStock, 
      'addedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Helper method to convert to Firestore specifically (alias for toMap)
  Map<String, dynamic> toFirestore() => toMap();

  /// Helper to update quantity safely within the UI components.
  /// Returns [true] if update was successful, [false] if it hit the effective limit.
  bool updateQuantity(int newQuantity) {
    if (newQuantity > 0) {
      if (newQuantity <= maxStock) {
        quantity = newQuantity;
        return true; 
      } else {
        // Force the quantity to stay at the maximum allowed limit
        quantity = maxStock;
        return false; 
      }
    }
    return false;
  }
}