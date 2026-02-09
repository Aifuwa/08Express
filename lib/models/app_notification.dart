import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String type; // We use String instead of String? for easier UI logic
  final String? orderId;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.orderId,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    // Get data map or empty map if document is empty
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    
    // --- SAFE TIMESTAMP MAPPING ---
    // Firestore server timestamps can be null for a split second during local sync.
    // We check both 'timestamp' and 'sentAt' (fallback) from your broadcasts schema.
    DateTime ts;
    if (data['timestamp'] is Timestamp) {
      ts = (data['timestamp'] as Timestamp).toDate();
    } else if (data['sentAt'] is Timestamp) {
      ts = (data['sentAt'] as Timestamp).toDate();
    } else {
      // Fallback to current time if both are null/missing
      ts = DateTime.now(); 
    }

    return AppNotification(
      id: doc.id,
      title: data['title'] ?? 'Notification',
      body: data['body'] ?? '',
      timestamp: ts,
      // Map 'isRead' (default to false if the field is missing)
      isRead: data['isRead'] ?? false,
      // Map 'screen' (from your broadcasts schema) to 'type' (used in UI icons/colors)
      type: data['screen'] ?? data['type'] ?? 'system',
      orderId: data['orderId'],
    );
  }

  /// Converts the model back to a Map (Used for background saving)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'screen': type, // Matches 'screen' in your broadcasts collection
      'orderId': orderId,
    };
  }

  /// Helper to create a copy of a notification with updated fields
  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? orderId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      orderId: orderId ?? this.orderId,
    );
  }
}