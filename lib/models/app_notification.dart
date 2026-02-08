import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String? type; 
  final String? orderId;

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
    
    // Safety check for Timestamp
    DateTime ts;
    if (data['timestamp'] is Timestamp) {
      ts = (data['timestamp'] as Timestamp).toDate();
    } else if (data['sentAt'] is Timestamp) {
      // Fallback to sentAt if timestamp is missing (both seen in screenshot)
      ts = (data['sentAt'] as Timestamp).toDate();
    } else {
      ts = DateTime.now(); 
    }

    return AppNotification(
      id: doc.id,
      title: data['title'] ?? 'Notification',
      body: data['body'] ?? '',
      timestamp: ts,
      // Map 'isRead' (default to false because it's usually missing in admin broadcasts)
      isRead: data['isRead'] ?? false,
      // Mapping 'screen' from your screenshot to 'type'
      type: data['screen'] ?? data['type'] ?? 'system',
      orderId: data['orderId'],
    );
  }

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