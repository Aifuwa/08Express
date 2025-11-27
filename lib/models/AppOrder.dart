// lib/models/AppOrder.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/providers/cart_provider.dart';
// If your CartItem is defined in cart_provider.dart, it's implicitly available.
// If CartItem is in a separate model file, you might need to import it explicitly:
// import 'package:eight_express/models/cart_item_model.dart'; // Example if CartItem is its own model

// Renamed from Order to AppOrder to avoid conflict with `Order` keyword if any.
class AppOrder {
  final String id; // Firestore document ID for the order
  final String userId;
  final double totalAmount;
  final List<OrderItem> items; // Using 'items' to match the constructor parameter name
  final Timestamp orderDate;
  final String status; // Added status field
  final String? receiptImageUrl; // Added for orders with receipt uploads

  AppOrder({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.items, // Parameter name
    required this.orderDate,
    this.status = 'pending', // Default status
    this.receiptImageUrl,
  });

  // Factory constructor to create an AppOrder from a Firestore DocumentSnapshot
  factory AppOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Missing data for order with ID: ${doc.id}');
    }

    List<OrderItem> orderItems = [];
    // Prioritize 'orderItems' field (from checkout_screen.dart), fallback to 'items'
    if (data['orderItems'] is List) {
      orderItems = (data['orderItems'] as List)
          .map((itemMap) => OrderItem.fromMap(itemMap as Map<String, dynamic>))
          .toList();
    } else if (data['items'] is List) { // Fallback for 'items' if 'orderItems' not present
      orderItems = (data['items'] as List)
          .map((itemMap) => OrderItem.fromMap(itemMap as Map<String, dynamic>))
          .toList();
    }


    return AppOrder(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      items: orderItems, // Assigning to 'items'
      orderDate: data['orderDate'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'pending',
      receiptImageUrl: data['receiptImageUrl'] as String?,
    );
  }

  // Method to convert an AppOrder object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'totalAmount': totalAmount,
      'orderItems': items.map((item) => item.toMap()).toList(), // Using 'orderItems' for Firestore field name
      'orderDate': orderDate,
      'status': status,
      'receiptImageUrl': receiptImageUrl,
    };
  }
}

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final String imageUrl;
  final int quantity;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
  });

  // CORRECTED: Access properties directly from CartItem
  factory OrderItem.fromCartItem(CartItem cartItem) {
    // This is where the error likely originated.
    // We assume CartItem has these properties directly, not nested under 'product'.
    return OrderItem(
      productId: cartItem.productId,
      name: cartItem.name,
      price: cartItem.price,
      imageUrl: cartItem.imageUrl,
      quantity: cartItem.quantity,
    );
  }

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId'] as String? ?? '',
      // Use 'productName' from Firestore if available, fallback to 'name' or 'Unknown'
      name: data['productName'] as String? ?? data['name'] as String? ?? 'Unknown',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] as String? ?? '',
      quantity: (data['quantity'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': name, // Store as 'productName' for consistency with Firestore
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }
}