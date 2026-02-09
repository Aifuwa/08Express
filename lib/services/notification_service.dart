import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/models/app_notification.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. GET Real-time Stream of Notifications ---
  // IMPORTANT: This query REQUIRES a Composite Index in Firestore:
  // Collection: broadcasts | Fields: target (Ascending), timestamp (Descending)
  Stream<List<AppNotification>> getNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('broadcasts')
        .where('target', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          // We map each document through the fromFirestore factory
          final docs = snap.docs.where((doc) => doc.get('timestamp') != null).toList();
          return snap.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
        })
        .handleError((error) {
          if (error.toString().contains('failed-precondition') || error.toString().contains('index')) {
            debugPrint("=================================================");
            debugPrint("🚨 FIRESTORE INDEX MISSING!");
            debugPrint("To see notifications, click the link in the error below:");
            debugPrint(error.toString());
            debugPrint("=================================================");
          } else {
            debugPrint("❌ Notification Stream Error: $error");
          }
          return <AppNotification>[];
        });
  }

  // --- 2. SAVE Notification ---
  // This saves to the 'broadcasts' collection using your schema
  Future<void> saveNotification({
    required String title,
    required String body,
    String type = 'home', // This will be saved as 'screen' in Firestore
    String? orderId,
    String? manualUserId, 
  }) async {
    final uid = manualUserId ?? _auth.currentUser?.uid;

    if (uid == null) {
      debugPrint("❌ Cannot save notification: No User ID available.");
      return;
    }

    try {
      await _firestore.collection('broadcasts').add({
        'target': uid,            // Who receives it
        'title': title,           // Notification title
        'body': body,             // Notification text
        'timestamp': FieldValue.serverTimestamp(), // Used for ordering
        'sentAt': FieldValue.serverTimestamp(),    // Audit timestamp
        'isRead': false,          // Default state
        'screen': type,           // Maps to 'type' in your UI logic
        'orderId': orderId,       // Optional order reference
        'status': 'sent',         // Delivery status
        'senderEmail': 'system@eightexpress.com', // System ID
      });
      debugPrint("✅ Notification saved to broadcasts for target: $uid");
    } catch (e) {
      debugPrint("❌ Error saving notification: $e");
    }
  }

  // --- 3. Mark a Specific Notification as Read ---
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('broadcasts')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("❌ Error marking notification read: $e");
    }
  }

  // --- 4. Mark ALL as Read ---
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('broadcasts')
          .where('target', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadNotifications.docs.isEmpty) return;

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
      debugPrint("✅ All notifications marked as read.");
    } catch (e) {
      debugPrint("❌ Error marking all read: $e");
    }
  }

  // --- 5. Delete All Notifications (Clear History) ---
  Future<void> clearAll() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final userNotifications = await _firestore
          .collection('broadcasts')
          .where('target', isEqualTo: user.uid)
          .get();

      if (userNotifications.docs.isEmpty) return;

      for (var doc in userNotifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint("✅ Notification history cleared.");
    } catch (e) {
      debugPrint("❌ Error clearing history: $e");
    }
  }
}