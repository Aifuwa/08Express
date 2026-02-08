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

  /// Convert a standard Map to a CartItem.
  /// This is used by the Provider when fetching items from the Firestore collection.
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? 'Unknown Product',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
      maxStock: (map['maxStock'] ?? 0).toInt(), 
      quantity: (map['quantity'] ?? 1).toInt(),
    );
  }

  /// Convert a Firestore document snapshot to a CartItem.
  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    // We merge the document ID into the map to ensure productId is never empty
    return CartItem.fromMap({...data, 'productId': doc.id});
  }

  /// Convert CartItem to a Map for Firestore.
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