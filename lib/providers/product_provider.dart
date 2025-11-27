// lib/providers/product_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/product.dart'; // Import your Product model

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // No initial fetch here unless you want ALL products on app start
  // ProductProvider() {
  //   fetchProducts();
  // }

  Future<void> fetchProducts({String? categoryName}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('products');

      if (categoryName != null && categoryName.isNotEmpty) {
        query = query.where('category', isEqualTo: categoryName);
      }

      final querySnapshot = await query.get();
      _products = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      _errorMessage = 'Failed to load products: ${e.message}';
      print('Firestore Error (fetchProducts): ${e.code} - ${e.message}');
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      print('General Error (fetchProducts): $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // You can add methods for adding, updating, deleting products if needed
}