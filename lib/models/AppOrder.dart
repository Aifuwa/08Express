import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/cart_item.dart'; 

class AppOrder {
  final String id;
  final String userId;
  final double totalAmount;
  final double deliveryFee;
  final String shippingAddress;
  final String deliveryMethod; 
  final List<OrderItem> items;
  final Timestamp orderDate;
  final String status;
  final String? receiptImageUrl;
  final int currentStep;
  final List<dynamic> trackingMilestones;

  AppOrder({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.deliveryFee,
    required this.shippingAddress,
    required this.deliveryMethod, 
    required this.items,
    required this.orderDate,
    required this.currentStep,
    required this.trackingMilestones,
    this.status = 'pending',
    this.receiptImageUrl,
  });

  factory AppOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Missing data for order with ID: ${doc.id}');
    }

    List<OrderItem> orderItems = [];
    // Matching the key 'orderItems' used in toFirestore and common in your DB
    if (data['orderItems'] != null && data['orderItems'] is List) {
      orderItems = (data['orderItems'] as List)
          .map((itemMap) => OrderItem.fromMap(itemMap as Map<String, dynamic>))
          .toList();
    }

    return AppOrder(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      shippingAddress: data['shippingAddress'] as String? ?? 'No Address',
      deliveryMethod: data['deliveryMethod'] as String? ?? 'delivery', 
      items: orderItems,
      // Handle null delay from server side timestamps
      orderDate: data['orderDate'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'pending',
      receiptImageUrl: data['receiptImageUrl'] as String?,
      currentStep: (data['currentStep'] as num?)?.toInt() ?? 0,
      // UPDATED: Default milestones now include "Cancelled" to match Admin Dashboard
      trackingMilestones: data['trackingMilestones'] as List<dynamic>? ?? [
        "Order Placed",
        "Payment Verified",
        "Processing",
        "In Transit",
        "Delivered",
        "Cancelled"
      ],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'totalAmount': totalAmount,
      'deliveryFee': deliveryFee,
      'shippingAddress': shippingAddress,
      'deliveryMethod': deliveryMethod, 
      'orderItems': items.map((item) => item.toMap()).toList(),
      'orderDate': orderDate,
      'status': status,
      'receiptImageUrl': receiptImageUrl,
      'currentStep': currentStep,
      'trackingMilestones': trackingMilestones,
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

  factory OrderItem.fromCartItem(CartItem cartItem) {
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
      // Supports both 'productName' and 'name' keys for flexibility
      name: data['productName'] as String? ?? data['name'] as String? ?? 'Unknown',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] as String? ?? '',
      quantity: (data['quantity'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': name,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }
}