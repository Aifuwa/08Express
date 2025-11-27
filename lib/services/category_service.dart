// lib/services/category_service.dart (NEW FILE)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/category_model.dart'; // Our new AppCategory model

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AppCategory>> getCategories() async {
    try {
      // Fetch documents from the 'categories' collection
      QuerySnapshot snapshot = await _firestore
          .collection('categories')
          .where('active', isEqualTo: true) // Only fetch active categories (if you use 'active' field)
          .orderBy('order', descending: false) // Order by 'order' field (if you use 'order' field)
          .get();

      List<AppCategory> categories = snapshot.docs
          .map((doc) => AppCategory.fromFirestore(doc))
          .toList();

      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Failed to fetch categories'); // Re-throw for provider to catch
    }
  }
}