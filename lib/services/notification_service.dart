import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/models/app_notification.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. GET Real-time Stream of Notifications ---
  // Using 'broadcasts' collection and 'target' field as shown in your Firestore data.
  Stream<List<AppNotification>> getNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('broadcasts') // Matches your screenshot
        .where('target', isEqualTo: user.uid) // Matches 'target' UID in your screenshot
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
        })
        .handleError((error) {
          // CRITICAL: Captures Indexing errors
          if (error.toString().contains('failed-precondition') || error.toString().contains('index')) {
            debugPrint("=================================================");
            debugPrint("FIRESTORE INDEX MISSING!");
            debugPrint("You need a composite index for the 'broadcasts' collection.");
            debugPrint("Check the link in the error message below to create it:");
            debugPrint(error.toString());
            debugPrint("=================================================");
          } else {
            debugPrint("Notification Stream Error: $error");
          }
          return <AppNotification>[];
        });
  }

  // --- 2. SAVE Notification ---
  // Updated to match the 'broadcasts' schema
  Future<void> saveNotification({
    required String title,
    required String body,
    String type = 'home', // Using 'home' as default screen type
    String? orderId,
    String? manualUserId, 
  }) async {
    final uid = manualUserId ?? _auth.currentUser?.uid;

    if (uid == null) {
      debugPrint("Cannot save notification: No User ID available.");
      return;
    }

    try {
      await _firestore.collection('broadcasts').add({
        'target': uid, // Using 'target' instead of userId
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'screen': type, // Using 'screen' to match your schema
        'orderId': orderId,
        'status': 'sent',
        'senderEmail': 'system@eightexpress.com',
      });
      debugPrint("Notification saved to broadcasts for user: $uid");
    } catch (e) {
      debugPrint("Error saving notification: $e");
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
      debugPrint("Error marking broadcast read: $e");
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
    } catch (e) {
      debugPrint("Error marking all read: $e");
    }
  }

  // --- 5. Delete All Notifications ---
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
    } catch (e) {
      debugPrint("Error clearing broadcasts: $e");
    }
  }
}