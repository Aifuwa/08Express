import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:eight_express/models/AppOrder.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/providers/cart_provider.dart';
// If OrderItem is in a separate file, make sure to import it:
// import 'package:eight_express/models/order_item.dart'; // OrderItem is defined in AppOrder.dart now

class OrderService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserProvider _userProvider;
  final CartProvider _cartProvider;

  OrderService(this._userProvider, this._cartProvider);

  Future<void> placeOrder() async {
    if (!_userProvider.isAuthenticated || _userProvider.firebaseUser == null) {
      debugPrint('Error: User not authenticated or user data missing. Cannot place order.');
      throw Exception('Authentication required to place an order.');
    }
    if (_cartProvider.itemCount == 0) {
      debugPrint('Error: Cart is empty. Cannot place order.');
      throw Exception('Cart is empty. Add items to cart before placing an order.');
    }

    final String userId = _userProvider.firebaseUser!.uid;
    final List<OrderItem> orderItems = _cartProvider.items.values
        .map((cartItem) => OrderItem.fromCartItem(cartItem))
        .toList();
    final double totalAmount = _cartProvider.totalAmount;

    try {
      // Add the order to the 'orders' collection
      DocumentReference orderDocRef = await _firestore.collection('orders').add({
        'userId': userId,
        'totalAmount': totalAmount,
        'items': orderItems.map((item) => item.toMap()).toList(),
        'orderDate': FieldValue.serverTimestamp(),
        // Default status is 'pending' from AppOrder constructor, but can be explicitly set here if needed
        'status': 'pending',
      });

      debugPrint('Order placed successfully! Order ID: ${orderDocRef.id}');

      // After placing the order, clear the user's cart
      // The original code had `await _cartProvider.clearCart();` twice.
      // I've kept only one as that's the correct way.
      _cartProvider.clearCart(); // Call clearCart without await, as it doesn't return Future<void> or isn't async
      debugPrint('Cart cleared after order placement.');

      notifyListeners();

    } catch (e) {
      debugPrint('Error placing order: $e');
      throw Exception('Failed to place order: $e');
    }
  }

  Stream<List<AppOrder>> getUserOrders() {
    if (!_userProvider.isAuthenticated || _userProvider.firebaseUser == null) {
      debugPrint('Warning: Attempted to get user orders while not authenticated.');
      return Stream.value([]);
    }
    final String userId = _userProvider.firebaseUser!.uid;
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('orderDate', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint('Error fetching user orders: $error');
          return <AppOrder>[];
        })
        .map((snapshot) {
          return snapshot.docs.map((doc) => AppOrder.fromFirestore(doc)).toList();
        });
  }
}