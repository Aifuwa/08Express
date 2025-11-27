// lib/providers/cart_provider.dart
import 'package:flutter/material.dart';
import 'package:eight_express/models/product.dart'; // Ensure Product model is imported

// Assuming you have a CartItem model
class CartItem {
  final String id; // Unique ID for this cart item instance
  final String productId; // ID of the product itself
  final String name;
  int quantity; // Quantity can change
  final double price;
  final String imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.imageUrl,
  });

  // Helper method to update quantity
  void updateQuantity(int newQuantity) {
    if (newQuantity < 1) {
      quantity = 1; // Prevent quantity from going below 1
    } else {
      quantity = newQuantity;
    }
  }
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {}; // Key: productId, Value: CartItem

  Map<String, CartItem> get items {
    return {..._items}; // Return a copy to prevent external modification
  }

  int get itemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity); // Sum of all quantities
  }

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  void addItem(Product product, {int quantity = 1}) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existingCartItem) => CartItem(
          id: existingCartItem.id, // Keep existing cart item ID
          productId: existingCartItem.productId,
          name: existingCartItem.name,
          quantity: existingCartItem.quantity + quantity, // Add the new quantity
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => CartItem(
          id: DateTime.now().toString(), // Unique ID for this cart item
          productId: product.id,
          name: product.name,
          quantity: quantity, // Use the provided quantity
          price: product.price,
          imageUrl: product.imageUrl,
        ),
      );
    }
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          productId: existingCartItem.productId,
          name: existingCartItem.name,
          quantity: existingCartItem.quantity - 1,
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
        ),
      );
    } else {
      _items.remove(productId); // Remove completely if quantity is 1
    }
    notifyListeners();
  }

  void removeItem(String productId) { // Removes all instances of a product
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}