import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String? type; // 'order', 'promo', 'system'
  final String? orderId; // Added to link notification to a specific order

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type,
    this.orderId,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Safety check for Timestamp: Firestore serverTimestamp() can be null for a 
    // split second before it reaches the server.
    DateTime ts;
    if (data['timestamp'] is Timestamp) {
      ts = (data['timestamp'] as Timestamp).toDate();
    } else {
      ts = DateTime.now(); // Fallback to current time
    }

    return AppNotification(
      id: doc.id,
      title: data['title'] ?? 'Notification',
      body: data['body'] ?? '',
      timestamp: ts,
      isRead: data['isRead'] ?? false,
      type: data['type'],
      orderId: data['orderId'],
    );
  }

  /// Converts the model into a Map for Firestore uploads
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type,
      'orderId': orderId,
    };
  }
}