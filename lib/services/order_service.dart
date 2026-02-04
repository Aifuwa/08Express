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

  /// Places an order, reduces product stock, and generates a notification 
  /// all in a single ATOMIC batch to ensure data integrity.
  Future<void> placeOrder({
    required String address,
    required double deliveryFee,
    required String method,
  }) async {
    // 1. Validation Guards
    if (!_userProvider.isAuthenticated || _userProvider.firebaseUser == null) {
      throw Exception('Authentication required to place an order.');
    }
    if (_cartProvider.itemCount == 0) {
      throw Exception('Cart is empty.');
    }

    final String userId = _userProvider.firebaseUser!.uid;
    
    // 2. Prepare Order Items
    final List<OrderItem> orderItemsList = _cartProvider.items.values
        .map((cartItem) => OrderItem.fromCartItem(cartItem))
        .toList();
        
    final double totalAmount = _cartProvider.totalAmount + deliveryFee;

    // --- START WRITE BATCH ---
    // This makes the operation "All or Nothing". 
    // If the stock update fails, the order is not placed.
    WriteBatch batch = _firestore.batch();

    try {
      // 3. Create Order Document Reference
      DocumentReference orderDocRef = _firestore.collection('orders').doc();
      
      final orderData = {
        'userId': userId,
        'totalAmount': totalAmount,
        'deliveryFee': deliveryFee,
        'shippingAddress': address,
        'deliveryMethod': method,
        'orderItems': orderItemsList.map((item) => item.toMap()).toList(),
        'orderDate': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      // 4. ADD TO BATCH: Create the Order Document
      batch.set(orderDocRef, orderData);

      // 5. ADD TO BATCH: Reduce Stock for each product in the cart
      // This is Part 1 of your request: subtracting quantity from original stock.
      _cartProvider.items.forEach((productId, cartItem) {
        DocumentReference productRef = _firestore.collection('products').doc(productId);
        
        batch.update(productRef, {
          // Use negative value with FieldValue.increment to subtract from the server-side value
          'stock': FieldValue.increment(-cartItem.quantity),
        });
      });

      // 6. ADD TO BATCH: Generate Confirmation Notification
      DocumentReference notificationRef = _firestore.collection('notifications').doc();
      final notificationData = {
        'userId': userId,
        'title': 'Order Placed Successfully! 🎉',
        'body': 'Your order for ${orderItemsList.length} items (Total: ₦${totalAmount.toStringAsFixed(0)}) has been received.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'order_confirmation',
        'orderId': orderDocRef.id,
      };
      batch.set(notificationRef, notificationData);

      // 7. COMMIT THE ATOMIC BATCH
      // This sends all operations to Firebase to be executed simultaneously.
      await batch.commit();

      debugPrint('Order placed, stock reduced, and notification sent! ID: ${orderDocRef.id}');

      // 8. Clear the local cart and notify UI
      _cartProvider.clearCart();
      notifyListeners();

    } catch (e) {
      debugPrint('Transaction Error in placeOrder: $e');
      throw Exception('Failed to process order and update stock: $e');
    }
  }

  /// Streams the list of orders for the currently logged-in user
  Stream<List<AppOrder>> getUserOrders() {
    if (!_userProvider.isAuthenticated || _userProvider.firebaseUser == null) {
      return Stream.value([]);
    }

    final String userId = _userProvider.firebaseUser!.uid;

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('orderDate', descending: true) 
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