// lib/providers/product_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/product.dart';

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- FETCH ALL PRODUCTS (OR BY CATEGORY) ---
  Future<void> fetchProducts({String? categoryName}) async {
    _isLoading = true;
    _errorMessage = null;
    // We don't notifyListeners here immediately to avoid unnecessary rebuilds 
    // before the async operation starts, but we do it if UI needs to show loader.
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
          
      _errorMessage = null;
    } on FirebaseException catch (e) {
      _errorMessage = 'Failed to load products: ${e.message}';
      debugPrint('Firestore Error: ${e.code} - ${e.message}');
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      debugPrint('General Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- NEW: FETCH SINGLE PRODUCT BY ID ---
  // Useful for Notifications and Deep Links
  Future<Product?> fetchProductById(String productId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      DocumentSnapshot doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return Product.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching product by ID: $e");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- HELPER: CLEAR ERRORS ---
  void clearErrors() {
    _errorMessage = null;
    notifyListeners();
  }
}