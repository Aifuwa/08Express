import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/models/app_notification.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. GET Real-time Stream of Notifications ---
  // This is what powers the red dot on your Home Screen bell icon
  Stream<List<AppNotification>> getNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid) // Filter to only see own notifications
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
        })
        .handleError((error) {
          debugPrint("Notification Stream Error: $error");
          return <AppNotification>[];
        });
  }

  // --- 2. SAVE Manual Notification ---
  // Used for system alerts or promos created inside the app logic
  Future<void> saveNotification({
    required String title,
    required String body,
    String type = 'system',
    String? orderId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type,
        'orderId': orderId,
      });
    } catch (e) {
      debugPrint("Error saving notification: $e");
    }
  }

  // --- 3. Mark a Specific Notification as Read ---
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("Error marking notification read: $e");
    }
  }

  // --- 4. Mark ALL as Read ---
  // Useful for a "Mark all as read" button in the notification screen
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking all notifications read: $e");
    }
  }

  // --- 5. Delete All Notifications ---
  // Clears the user's notification history
  Future<void> clearAll() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final userNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in userNotifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint("Error clearing notifications: $e");
    }
  }
}