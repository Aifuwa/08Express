import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/product.dart';

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Data List
  List<Product> _products = [];
  
  // Pagination State
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final int _limit = 16; // User requested 16 products per page
  
  // Loading States
  bool _isLoading = false;      // Initial full-screen load
  bool _isLoadingMore = false;  // Bottom-of-list "Load More" load
  String? _errorMessage;

  // Getters
  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  // --- FETCH PRODUCTS WITH PAGINATION ---
  /// [categoryName] - Optional filter by category
  /// [refresh] - If true, clears list and starts from page 1. If false, fetches the next page.
  Future<void> fetchProducts({String? categoryName, bool refresh = false}) async {
    // 1. Reset logic for fresh loads
    if (refresh) {
      _products = [];
      _lastDocument = null;
      _hasMore = true;
      _errorMessage = null;
    }

    // 2. Safety Guards: Don't fetch if already loading or no more data
    if (_isLoadingMore || (_isLoading && !refresh) || !_hasMore) return;

    try {
      // 3. Set proper loading state
      if (_products.isEmpty) {
        _isLoading = true; // Large central spinner
      } else {
        _isLoadingMore = true; // Small button spinner
      }
      notifyListeners();

      // 4. Build the Query
      Query<Map<String, dynamic>> query = _firestore.collection('products');

      if (categoryName != null && categoryName.isNotEmpty) {
        query = query.where('category', isEqualTo: categoryName);
      }

      // Important: Must order for pagination to work with startAfterDocument
      query = query.orderBy('name').limit(_limit);

      // Start after the last document if we are paginating
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();

      // 5. Determine if we reached the end of the collection
      if (querySnapshot.docs.length < _limit) {
        _hasMore = false; 
      }

      // 6. Process results
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        
        final List<Product> newItems = querySnapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();

        _products.addAll(newItems);
      }
          
      _errorMessage = null;
    } on FirebaseException catch (e) {
      _errorMessage = 'Failed to load products: ${e.message}';
      debugPrint('Firestore Error: ${e.code} - ${e.message}');
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      debugPrint('General Error: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // --- FETCH SINGLE PRODUCT BY ID ---
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