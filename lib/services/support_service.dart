import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/models/app_user.dart';

class SupportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendTicket({
    required AppUser user,
    required String subject,
    required String message,
  }) async {
    try {
      await _firestore.collection('support_tickets').add({
        'userId': user.uid,
        'userName': user.name,
        'userEmail': user.email,
        'phoneNumber': user.phoneNumber,
        'subject': subject,
        'message': message,
        'status': 'new', // Matches the "New" badge in your React Dashboard
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Failed to send message: $e");
    }
  }
}