// lib/screens/product_listing_screen.dart
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/providers/product_provider.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/wishlist_provider.dart'; // ADDED
import 'package:eight_express/screens/product_detail_screen.dart';
import 'package:eight_express/widgets/custom_loader.dart'; // IMPORT LOADER

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false)
          .fetchProducts(categoryName: widget.categoryName);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color orangeColor = Color(0xFFFE7F2D);
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
          // --- UPDATED: Using Signature 08 Loader ---
          if (productProvider.isLoading) {
            return const Center(
              child: CustomLoader(size: 80), 
            );
          }

          if (productProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(productProvider.errorMessage!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => productProvider.fetchProducts(categoryName: widget.categoryName),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (productProvider.products.isEmpty) {
            return const Center(child: Text("No items found here."));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            cacheExtent: 500, // Optimization for scrolling
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 20.0,
              childAspectRatio: 0.65, 
            ),
            itemCount: productProvider.products.length,
            itemBuilder: (context, index) {
              final product = productProvider.products[index];
              return ProductGridItem(product: product);
            },
          );
        },
      ),
    );
  }
}

class ProductGridItem extends StatelessWidget {
  final Product product;
  const ProductGridItem({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color orangeColor = Color(0xFFFE7F2D);
    final bool isOutOfStock = product.stock <= 0;
    
    // Access Wishlist Provider
    final wishlist = Provider.of<WishlistProvider>(context);
    final isFav = wishlist.isFavorite(product.id);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => ProductDetailScreen(product: product)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03), 
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE SECTION
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Hero(
                      tag: 'productImage${product.id}',
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 400, // RAM Optimization
                        placeholder: (context, url) => const Center(child: CustomLoader(size: 30)),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                      ),
                    ),
                  ),

                  // --- ACTIVE WISHLIST BUTTON ---
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => wishlist.toggleWishlist(product),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border, 
                              size: 18, 
                              color: isFav ? Colors.red : Colors.black54
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (isOutOfStock)
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                      child: const Center(child: Text("SOLD OUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900))),
                    ),
                ],
              ),
            ),
            
            // 2. DETAILS SECTION
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '\₦${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: orangeColor),
                          ),
                        ),
                        
                        // --- PREMIUM ADD BUTTON ---
                        GestureDetector(
                          onTap: !isOutOfStock
                              ? () {
                                  Provider.of<CartProvider>(context, listen: false).addItem(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${product.name} added!'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: !isOutOfStock 
                                ? const LinearGradient(colors: [orangeColor, Color(0xFFFFB347)])
                                : const LinearGradient(colors: [Colors.grey, Colors.grey]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}