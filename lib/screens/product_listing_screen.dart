// lib/screens/product_listing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/product_provider.dart';
// IMPORT the standardized global widget
import 'package:eight_express/widgets/product_grid_item.dart'; 
import 'package:eight_express/widgets/custom_loader.dart'; 

class ProductListingScreen extends StatefulWidget {
  final String categoryName;

  const ProductListingScreen({
    Key? key,
    required this.categoryName,
  }) : super(key: key);

  @override
  State<ProductListingScreen> createState() => _ProductListingScreenState();
}

class _ProductListingScreenState extends State<ProductListingScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch products for this specific category on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false)
          .fetchProducts(categoryName: widget.categoryName);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF8F9FA); 

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          // --- LOADING STATE ---
          if (productProvider.isLoading) {
            return const Center(
              child: CustomLoader(size: 80), 
            );
          }

          // --- ERROR STATE ---
          if (productProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    productProvider.errorMessage!, 
                    style: const TextStyle(color: Colors.red)
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => productProvider.fetchProducts(
                      categoryName: widget.categoryName
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // --- EMPTY STATE ---
          if (productProvider.products.isEmpty) {
            return const Center(
              child: Text(
                "No items found here.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // --- DATA GRID ---
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            cacheExtent: 500, // Optimization for scrolling performance
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 20.0,
              childAspectRatio: 0.65, 
            ),
            itemCount: productProvider.products.length,
            itemBuilder: (context, index) {
              final product = productProvider.products[index];
              
              // USE THE GLOBAL STANDARDIZED PRODUCT CARD
              // This widget handles Hero, Firestore Wishlist, and Cart logic
              return ProductGridItem(product: product);
            },
          );
        },
      ),
    );
  }
}