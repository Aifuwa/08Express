import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String userId;
  final double totalAmount;
  final String status; // 'Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'
  final DateTime date;
  final Map<String, dynamic> shippingAddress;
  final List<Map<String, dynamic>> items;

  OrderModel({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.status,
    required this.date,
    required this.shippingAddress,
    required this.items,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'Pending',
      date: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shippingAddress: Map<String, dynamic>.from(data['shippingAddress'] ?? {}),
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
    );
  }
}