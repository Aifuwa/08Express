import 'package:flutter/material.dart';
import 'package:eight_express/models/cart_item.dart'; // IMPORT THE MODEL
import 'package:eight_express/models/product.dart';

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {}; 

  Map<String, CartItem> get items {
    return {..._items}; 
  }

  int get itemCount {
    // Sum of all quantities
    var total = 0;
    _items.forEach((key, item) {
      total += item.quantity;
    });
    return total;
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  // 1. Add Item (Standard)
  void addItem(Product product, {int quantity = 1}) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existingCartItem) => CartItem(
          productId: existingCartItem.productId,
          name: existingCartItem.name,
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
          quantity: existingCartItem.quantity + quantity,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => CartItem.fromProduct(product, quantity: quantity),
      );
    }
    notifyListeners();
  }

  // 2. Set Exact Quantity (For Manual Input Dialog)
  void setQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;

    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    _items.update(
      productId,
      (existing) => CartItem(
        productId: existing.productId,
        name: existing.name,
        price: existing.price,
        imageUrl: existing.imageUrl,
        quantity: quantity,
      ),
    );
    notifyListeners();
  }

  // 3. Remove Single Unit (Minus button)
  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          productId: existingCartItem.productId,
          name: existingCartItem.name,
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
          quantity: existingCartItem.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  // 4. Remove Item Completely
  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  // 5. Clear Cart
  void clearCart() {
    _items = {};
    notifyListeners();
  }
}