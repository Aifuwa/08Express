import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/models/app_notification.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. GET Real-time Stream of Notifications ---
  // Matches Index: Collection: broadcasts | target (Asc) + timestamp (Desc)
  Stream<List<AppNotification>> getNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('broadcasts')
        .where('target', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          // IMPORTANT: We filter out documents where the server timestamp hasn't 
          // propagated yet to prevent null-pointer errors in the UI.
          return snap.docs
              .where((doc) {
                try {
                  return doc.get('timestamp') != null;
                } catch (e) {
                  return false;
                }
              })
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList();
        })
        .handleError((error) {
          if (error.toString().contains('failed-precondition') || error.toString().contains('index')) {
            debugPrint("=================================================");
            debugPrint("🚨 FIRESTORE INDEX MISSING OR MISMATCHED!");
            debugPrint("Collection: broadcasts");
            debugPrint("Required: target (Asc) + timestamp (Desc)");
            debugPrint("Link: ${error.toString().split('here: ').last}");
            debugPrint("=================================================");
          } else {
            debugPrint("❌ Notification Stream Error: $error");
          }
          return <AppNotification>[];
        });
  }

  // --- 2. SAVE Notification ---
  Future<void> saveNotification({
    required String title,
    required String body,
    String type = 'home', 
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
        'target': uid,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(), // Critical for ordering
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'screen': type,
        'orderId': orderId,
        'status': 'sent',
        'senderEmail': 'system@eightexpress.com',
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
      final snapshots = await _firestore
          .collection('broadcasts')
          .where('target', isEqualTo: user.uid)
          .get();

      if (snapshots.docs.isEmpty) return;

      // Using WriteBatch for performance
      final batch = _firestore.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint("✅ Notification history cleared.");
    } catch (e) {
      debugPrint("❌ Error clearing history: $e");
    }
  }
}