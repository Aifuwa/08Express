// lib/providers/category_provider.dart (UPDATED)
import 'package:flutter/material.dart';
import 'package:eight_express/models/category_model.dart'; // Our AppCategory model
import 'package:eight_express/services/category_service.dart'; // Our new CategoryService

class CategoryProvider with ChangeNotifier {
  final CategoryService _categoryService = CategoryService(); // Instantiate the new service
  List<AppCategory> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AppCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  CategoryProvider() {
    fetchCategories(); // Initial fetch when provider is created
  }

  Future<void> fetchCategories() async {
    if (_isLoading) return; // Prevent multiple simultaneous fetches

    _isLoading = true;
    _errorMessage = null;

    try {
      _categories = await _categoryService.getCategories(); // Use the new service method
    } catch (e) {
      _errorMessage = 'Failed to load categories: $e';
      debugPrint('Error fetching categories: $_errorMessage'); // Use debugPrint
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify listeners of state change
    }
  }

  AppCategory? getCategoryByName(String name) {
    // Added a null check and more robust error handling
    try {
      return _categories.firstWhere((category) => category.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      debugPrint('Category with name "$name" not found: $e'); // Use debugPrint
      return null;
    }
  }
}