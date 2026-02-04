import 'package:flutter/material.dart';
import 'package:eight_express/models/cart_item.dart';
import 'package:eight_express/models/product.dart';

class CartProvider with ChangeNotifier {
  // Internal map of items where key is Product ID
  Map<String, CartItem> _items = {};

  // --- GETTERS ---

  /// Returns a copy of the items in the cart
  Map<String, CartItem> get items {
    return {..._items};
  }

  /// Returns the total number of items (sum of quantities)
  int get itemCount {
    var total = 0;
    _items.forEach((key, item) {
      total += item.quantity;
    });
    return total;
  }

  /// Returns the total price of all items in the cart
  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  // --- HELPER LOGIC ---

  /// Calculates the maximum allowed quantity for a product.
  /// It picks the smaller value between Warehouse Stock and the Customer Purchase Limit.
  int _calculateEffectiveLimit(Product product) {
    int warehouseStock = product.stock;
    int purchaseLimit = product.maxPurchaseLimit;

    // If purchaseLimit is 0 or greater than stock, the only limit is warehouse stock.
    if (purchaseLimit <= 0 || purchaseLimit >= warehouseStock) {
      return warehouseStock;
    }
    
    // Otherwise, the customer is restricted by the specific purchase limit.
    return purchaseLimit;
  }

  // --- LOGIC METHODS ---

  /// Adds an item to the cart with strict stock and purchase limit validation.
  /// Returns [true] if added successfully, [false] if any limit is reached.
  bool addItem(Product product, {int quantity = 1}) {
    // 1. Calculate the tighter limit (Stock vs Customer Limit)
    int effectiveLimit = _calculateEffectiveLimit(product);

    // 2. Basic validation: Is the product available at all?
    if (effectiveLimit <= 0) {
      return false; 
    }

    if (_items.containsKey(product.id)) {
      // 3. Item already exists in the bag
      final existingCartItem = _items[product.id]!;
      int currentQty = existingCartItem.quantity;
      
      // Safety Check: Are we already at the maximum allowed limit?
      if (currentQty >= effectiveLimit) {
        return false; 
      }

      // Calculate new quantity but cap it at the effective limit
      int newTotal = currentQty + quantity;
      if (newTotal > effectiveLimit) {
        newTotal = effectiveLimit;
      }

      _items.update(
        product.id,
        (existing) => CartItem(
          productId: existing.productId,
          name: existing.name,
          price: existing.price,
          imageUrl: existing.imageUrl,
          // We store the 'effectiveLimit' as maxStock so the Cart Screen knows the boundary
          maxStock: effectiveLimit, 
          quantity: newTotal,
        ),
      );
    } else {
      // 4. Adding a new product to the bag for the first time
      int initialQuantity = quantity;
      
      // Ensure we don't start with more than allowed
      if (initialQuantity > effectiveLimit) {
        initialQuantity = effectiveLimit;
      }

      _items.putIfAbsent(
        product.id,
        () => CartItem(
          productId: product.id,
          name: product.name,
          price: product.price,
          imageUrl: product.imageUrl,
          maxStock: effectiveLimit,
          quantity: initialQuantity,
        ),
      );
    }
    
    notifyListeners();
    return true;
  }

  /// Decrements quantity by 1. If quantity becomes 0, removes item from cart.
  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) {
      return;
    }
    
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => CartItem(
          productId: existing.productId,
          name: existing.name,
          price: existing.price,
          imageUrl: existing.imageUrl,
          maxStock: existing.maxStock, 
          quantity: existing.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  /// Increments quantity by 1 with validation against Effective Limit.
  /// Used primarily by the "+" button on the Cart Screen.
  bool incrementItem(String productId) {
    if (!_items.containsKey(productId)) return false;

    final existing = _items[productId]!;

    // Validate against the stored Effective Limit (maxStock)
    if (existing.quantity >= existing.maxStock) {
      return false; // User hit either warehouse stock limit or customer purchase limit
    }

    _items.update(
      productId,
      (existing) => CartItem(
        productId: existing.productId,
        name: existing.name,
        price: existing.price,
        imageUrl: existing.imageUrl,
        maxStock: existing.maxStock,
        quantity: existing.quantity + 1,
      ),
    );
    notifyListeners();
    return true;
  }

  /// Removes a product entirely from the bag regardless of quantity.
  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  /// Manually sets the quantity (used for the Direct Input/Dialog feature).
  /// Validates input against the calculated Effective Limit.
  void setQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;

    // If user enters 0 or less, remove the item
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final existing = _items[productId]!;

    // Validate manual input against stored limit snapshot
    int finalQuantity = quantity;
    if (finalQuantity > existing.maxStock) {
      finalQuantity = existing.maxStock;
    }

    _items.update(
      productId,
      (existing) => CartItem(
        productId: existing.productId,
        name: existing.name,
        price: existing.price,
        imageUrl: existing.imageUrl,
        maxStock: existing.maxStock,
        quantity: finalQuantity,
      ),
    );
    notifyListeners();
  }

  /// Resets the cart to empty. 
  /// Called automatically after a successful Order Placement.
  void clearCart() {
    _items = {};
    notifyListeners();
  }
}