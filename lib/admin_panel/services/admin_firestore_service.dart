import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:eight_express/admin_panel/models/product.dart';
// Ensure you have created the OrderModel file from Step 1
import 'package:eight_express/admin_panel/models/order_model.dart';

class AdminFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Authentication Methods ---
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('An unknown error occurred during sign-in: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- Product Management Methods ---
  Stream<List<Product>> getProducts() {
    return _firestore.collection('products')
        .orderBy('timestamp', descending: true) // Order by latest added/updated
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList());
  }

  Future<void> addProduct(Product product) async {
    await _firestore.collection('products').add(product.toFirestore());
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) {
      throw Exception('Product ID cannot be null for update.');
    }
    // Only update fields that are part of toFirestore(), ID is not part of it.
    await _firestore.collection('products').doc(product.id).update(product.toFirestore());
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).delete();
  }

  // --- Order Management Methods (NEW) ---
  
  // Stream all orders, typically ordered by latest first
  Stream<List<OrderModel>> getOrders() {
    return _firestore.collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  // Update the status of a specific order
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
    });
  }

  // --- User Management Methods ---
  Stream<List<Map<String, dynamic>>> getUsers() {
    return _firestore.collection('users')
        .orderBy('email', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          Timestamp? timestamp = data['timestamp'] as Timestamp?;
          return {
            'id': doc.id,
            'email': data['email'] ?? 'N/A',
            'name': data['name'] ?? 'N/A',
            'isAdmin': data['isAdmin'] ?? false,
            'registrationDate': timestamp?.toDate().toLocal().toString().split(' ')[0] ?? 'N/A',
          };
        }).toList());
  }

  Future<void> updateUserRole(String userId, bool isAdmin) async {
    await _firestore.collection('users').doc(userId).update({'isAdmin': isAdmin});
  }

  Future<void> deleteUserByAdmin(String uid) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('deleteUserAccount');
      final result = await callable.call(<String, dynamic>{
        'uid': uid,
      });
      print('Delete user result: ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      print('Cloud Function Error deleting user: ${e.code} - ${e.message}');
      if (e.details != null) {
        print('Details: ${e.details}');
      }
      rethrow;
    } catch (e) {
      print('Generic error deleting user: $e');
      rethrow;
    }
  }

  // --- Push Notification Methods ---
  Future<void> sendPushNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, String>? data,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('sendNotification');
      final result = await callable.call(<String, dynamic>{
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'data': data,
      });
      print('Notification sent result: ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      print('Cloud Function Error: ${e.code} - ${e.message}');
      if (e.details != null) {
        print('Details: ${e.details}');
      }
      rethrow;
    } catch (e) {
      print('Generic error sending notification: $e');
      rethrow;
    }
  }
}