import 'package:flutter/material.dart';
import 'package:eight_express/models/cart_item.dart';
import 'package:eight_express/models/product.dart';

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};

  Map<String, CartItem> get items {
    return {..._items};
  }

  int get itemCount {
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

  // --- 1. Add Item with Stock Validation ---
  // Returns TRUE if added successfully, FALSE if stock limit reached/capped
  bool addItem(Product product, {int quantity = 1}) {
    // Safety check: Product invalid or no stock
    if (product.stock <= 0) return false;

    if (_items.containsKey(product.id)) {
      // Calculate current + new quantity
      int currentQty = _items[product.id]!.quantity;
      int newTotal = currentQty + quantity;

      // Check if we are already at max stock
      if (currentQty >= product.stock) {
        return false; // Cannot add more
      }

      // If adding new quantity exceeds stock, cap it at max stock
      if (newTotal > product.stock) {
        newTotal = product.stock;
      }

      _items.update(
        product.id,
        (existingCartItem) => CartItem(
          productId: existingCartItem.productId,
          name: existingCartItem.name,
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
          quantity: newTotal,
        ),
      );
    } else {
      // Adding for the first time
      // Ensure we don't start with more than available stock
      int finalQuantity = quantity;
      if (finalQuantity > product.stock) {
        finalQuantity = product.stock;
      }

      _items.putIfAbsent(
        product.id,
        () => CartItem.fromProduct(product, quantity: finalQuantity),
      );
    }
    notifyListeners();
    return true;
  }

  // --- 2. Remove Single Unit (Minus Button) ---
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

  // --- 3. Remove Item Completely (Trash Icon) ---
  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  // --- 4. Set Exact Quantity (Optional Manual Input) ---
  // Note: Since this doesn't pass the Product object, it assumes 
  // the UI (Cart Screen) has already checked the stock limit.
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

  // --- 5. Clear Cart ---
  void clearCart() {
    _items = {};
    notifyListeners();
  }
}