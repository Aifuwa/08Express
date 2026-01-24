import 'package:flutter/material.dart';
import 'package:eight_express/models/category_model.dart';
import 'package:eight_express/services/category_service.dart';

class CategoryProvider with ChangeNotifier {
  final CategoryService _categoryService = CategoryService();
  List<AppCategory> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AppCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCategories() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Show loader immediately

    try {
      _categories = await _categoryService.getCategories();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners(); // Hide loader and show list or error
    }
  }

  AppCategory? getCategoryByName(String name) {
    try {
      return _categories.firstWhere(
        (category) => category.name.toLowerCase() == name.toLowerCase()
      );
    } catch (e) {
      return null;
    }
  }
}