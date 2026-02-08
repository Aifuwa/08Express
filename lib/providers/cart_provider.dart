import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:eight_express/models/cart_item.dart';
import 'package:eight_express/models/product.dart';

class CartProvider with ChangeNotifier {
  // Internal map of items where key is Product ID
  Map<String, CartItem> _items = {};
  
  // --- FIREBASE PROPERTIES ---
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;

  // --- INITIALIZATION ---

  /// Sets the current user ID and fetches their cart from Firestore.
  /// Call this when the user logs in.
  void setUserId(String? uid) {
    _userId = uid;
    if (_userId != null) {
      _fetchCartFromFirestore();
    } else {
      _items = {};
      notifyListeners();
    }
  }

  /// Helper to get the Firestore collection reference for the user's cart
  CollectionReference<Map<String, dynamic>>? get _cartRef {
    if (_userId == null) return null;
    return _db.collection('users').doc(_userId).collection('cart');
  }

  /// Loads cart data from Firestore on app startup/login
  Future<void> _fetchCartFromFirestore() async {
    if (_cartRef == null) return;
    try {
      final snapshot = await _cartRef!.get();
      final Map<String, CartItem> loadedItems = {};
      
      for (var doc in snapshot.docs) {
        // This assumes your CartItem model has a fromMap/fromFirestore method
        loadedItems[doc.id] = CartItem.fromMap(doc.data());
      }
      
      _items = loadedItems;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching cart: $e");
    }
  }

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

  // --- REAL-TIME SYNC LOGIC ---

  void syncProductData(String productId, double newPrice, int newMaxStock) {
    if (!_items.containsKey(productId)) return;

    final existing = _items[productId]!;
    bool needsUpdate = false;

    if (existing.price != newPrice) needsUpdate = true;
    if (existing.maxStock != newMaxStock) needsUpdate = true;

    if (needsUpdate) {
      int finalQty = existing.quantity;
      if (finalQty > newMaxStock) finalQty = newMaxStock;

      final updatedItem = CartItem(
        productId: existing.productId,
        name: existing.name,
        imageUrl: existing.imageUrl,
        price: newPrice,
        maxStock: newMaxStock,
        quantity: finalQty,
      );

      _items[productId] = updatedItem;
      notifyListeners();
      
      // Sync update to Firestore
      _cartRef?.doc(productId).set(updatedItem.toMap());
    }
  }

  // --- HELPER LOGIC ---

  int _calculateEffectiveLimit(Product product) {
    int warehouseStock = product.stock;
    int purchaseLimit = product.maxPurchaseLimit;

    if (purchaseLimit <= 0 || purchaseLimit >= warehouseStock) {
      return warehouseStock;
    }
    return purchaseLimit;
  }

  // --- LOGIC METHODS ---

  bool addItem(Product product, {int quantity = 1}) {
    int effectiveLimit = _calculateEffectiveLimit(product);
    if (effectiveLimit <= 0) return false; 

    CartItem itemToSave;

    if (_items.containsKey(product.id)) {
      final existingCartItem = _items[product.id]!;
      int currentQty = existingCartItem.quantity;
      if (currentQty >= effectiveLimit) return false; 

      int newTotal = currentQty + quantity;
      if (newTotal > effectiveLimit) newTotal = effectiveLimit;

      itemToSave = CartItem(
        productId: existingCartItem.productId,
        name: existingCartItem.name,
        price: product.price,
        imageUrl: existingCartItem.imageUrl,
        maxStock: effectiveLimit, 
        quantity: newTotal,
      );
    } else {
      int initialQuantity = quantity;
      if (initialQuantity > effectiveLimit) initialQuantity = effectiveLimit;

      itemToSave = CartItem(
        productId: product.id,
        name: product.name,
        price: product.price,
        imageUrl: product.imageUrl,
        maxStock: effectiveLimit,
        quantity: initialQuantity,
      );
    }
    
    _items[product.id] = itemToSave;
    notifyListeners();
    
    // Background sync to Firebase
    _cartRef?.doc(product.id).set(itemToSave.toMap());
    return true;
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    
    if (_items[productId]!.quantity > 1) {
      final updated = CartItem(
        productId: _items[productId]!.productId,
        name: _items[productId]!.name,
        price: _items[productId]!.price,
        imageUrl: _items[productId]!.imageUrl,
        maxStock: _items[productId]!.maxStock, 
        quantity: _items[productId]!.quantity - 1,
      );
      _items[productId] = updated;
      _cartRef?.doc(productId).set(updated.toMap());
    } else {
      _items.remove(productId);
      _cartRef?.doc(productId).delete();
    }
    notifyListeners();
  }

  bool incrementItem(String productId) {
    if (!_items.containsKey(productId)) return false;
    final existing = _items[productId]!;

    if (existing.quantity >= existing.maxStock) return false;

    final updated = CartItem(
      productId: existing.productId,
      name: existing.name,
      price: existing.price,
      imageUrl: existing.imageUrl,
      maxStock: existing.maxStock,
      quantity: existing.quantity + 1,
    );
    
    _items[productId] = updated;
    notifyListeners();
    
    _cartRef?.doc(productId).set(updated.toMap());
    return true;
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
    _cartRef?.doc(productId).delete();
  }

  void setQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;

    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final existing = _items[productId]!;
    int finalQuantity = quantity;
    if (finalQuantity > existing.maxStock) finalQuantity = existing.maxStock;

    final updated = CartItem(
      productId: existing.productId,
      name: existing.name,
      price: existing.price,
      imageUrl: existing.imageUrl,
      maxStock: existing.maxStock,
      quantity: finalQuantity,
    );

    _items[productId] = updated;
    notifyListeners();
    
    _cartRef?.doc(productId).set(updated.toMap());
  }

  void clearCart() {
    _items = {};
    notifyListeners();
    
    // Clear Firestore collection
    _cartRef?.get().then((snapshot) {
      for (DocumentSnapshot doc in snapshot.docs) {
        doc.reference.delete();
      }
    });
  }
}