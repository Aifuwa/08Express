import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AppCategory>> getCategories() async {
    try {
      // We fetch the entire collection first. 
      // This bypasses the need for manual Composite Indexes in Firebase.
      QuerySnapshot snapshot = await _firestore.collection('categories').get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Convert Firestore documents to our AppCategory model
      List<AppCategory> categories = snapshot.docs
          .map((doc) => AppCategory.fromFirestore(doc))
          .toList();

      // We sort manually in the code based on the 'order' field
      categories.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

      return categories;
    } catch (e) {
      print('CategoryService Error: $e');
      throw Exception('Failed to fetch categories: $e');
    }
  }
}