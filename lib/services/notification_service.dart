import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/models/app_notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. SAVE notification to user's history
  Future<void> saveNotification({required String title, required String body, String type = 'system'}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': type,
    });
  }

  // 2. GET real-time stream of notifications
  Stream<List<AppNotification>> getNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
  }

  // 3. Mark as read
  Future<void> markAsRead(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).collection('notifications').doc(id).update({'isRead': true});
  }

  // 4. Delete all
  Future<void> clearAll() async {
    final user = _auth.currentUser;
    if (user == null) return;
    var snapshots = await _firestore.collection('users').doc(user.uid).collection('notifications').get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}