import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:eight_express/models/AppOrder.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/providers/cart_provider.dart';

class OrderService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserProvider _userProvider;
  final CartProvider _cartProvider;

  OrderService(this._userProvider, this._cartProvider);

  // UPDATED: Added parameters to match your AppOrder model requirements
  Future<void> placeOrder({
    required String address,
    required double deliveryFee,
    required String method,
  }) async {
    if (!_userProvider.isAuthenticated || _userProvider.firebaseUser == null) {
      throw Exception('Authentication required to place an order.');
    }
    if (_cartProvider.itemCount == 0) {
      throw Exception('Cart is empty.');
    }

    final String userId = _userProvider.firebaseUser!.uid;
    
    // Map cart items to order items
    final List<OrderItem> orderItemsList = _cartProvider.items.values
        .map((cartItem) => OrderItem.fromCartItem(cartItem))
        .toList();
        
    final double totalAmount = _cartProvider.totalAmount + deliveryFee;

    try {
      // 1. Create a document reference to get the ID first
      DocumentReference orderDocRef = _firestore.collection('orders').doc();

      // 2. Prepare the data using the EXACT keys from your AppOrder.fromFirestore
      final orderData = {
        'userId': userId,
        'totalAmount': totalAmount,
        'deliveryFee': deliveryFee,
        'shippingAddress': address,
        'deliveryMethod': method,
        'orderItems': orderItemsList.map((item) => item.toMap()).toList(), // FIX: changed 'items' to 'orderItems'
        'orderDate': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      // 3. Save to Firestore
      await orderDocRef.set(orderData);

      debugPrint('Order placed successfully! ID: ${orderDocRef.id}');

      // 4. Clear the cart
      _cartProvider.clearCart();
      notifyListeners();

    } catch (e) {
      debugPrint('Error placing order: $e');
      throw Exception('Failed to place order: $e');
    }
  }

  Stream<List<AppOrder>> getUserOrders() {
    if (!_userProvider.isAuthenticated || _userProvider.firebaseUser == null) {
      return Stream.value([]);
    }

    final String userId = _userProvider.firebaseUser!.uid;

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('orderDate', descending: true) // REMINDER: Create the Composite Index in Firebase Console
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => AppOrder.fromFirestore(doc)).toList();
        })
        .handleError((error) {
          debugPrint('Error fetching orders: $error');
          return <AppOrder>[];
        });
  }
}