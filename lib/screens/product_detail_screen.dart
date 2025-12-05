// lib/screens/product_detail_screen.dart
import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/screens/cart_screen.dart'; // Import CartScreen

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  // Function to increase quantity (Unlimited)
  void _increaseQuantity() {
    setState(() {
      _quantity++;
    });
  }

  // Function to decrease quantity
  void _decreaseQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    const Color orangeColor = Color(0xFFFE7F2D);
    final bool isOutOfStock = widget.product.stock <= 0;

    return Scaffold(
      backgroundColor: Colors.white,
      // Extends body behind app bar for immersion
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: _buildGlassIcon(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: Consumer<CartProvider>(
              builder: (_, cart, ch) => Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildGlassIcon(
                    icon: Icons.shopping_cart_outlined,
                    onTap: () {
                      // --- FIX: Navigate to Cart Screen ---
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CartScreen()),
                      );
                    },
                  ),
                  if (cart.itemCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        // Padding bottom to account for the fixed bottom bar
        padding: const EdgeInsets.only(bottom: 100), 
        child: Column(
          children: [
            // 1. IMMERSIVE IMAGE SECTION
            SizedBox(
              height: size.height * 0.45, // 45% of screen height
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: 'productImage${widget.product.id}',
                      child: Image.network(
                        widget.product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey))),
                      ),
                    ),
                  ),
                  // Gradient overlay at bottom of image for text readability transition
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. CONTENT SHEET (Overlapping the image)
            Transform.translate(
              offset: const Offset(0, -30), // Pull up by 30 pixels
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar (Visual cue)
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Category Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: orangeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.product.category.toUpperCase(),
                        style: const TextStyle(
                          color: orangeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title and Price Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '\₦${widget.product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: orangeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Stock Status
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOutOfStock ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOutOfStock ? 'Out of Stock' : 'In Stock ',
                          //To add available Quantity//(${widget.product.stock} available)
                          style: TextStyle(
                            color: isOutOfStock ? Colors.red : Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 25),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 25),

                    // Description Title
                    const Text(
                      "Description",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    // Description Body
                    Text(
                      widget.product.description,
                      style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[600]),
                    ),

                    const SizedBox(height: 30),

                    // Quantity Section
                    if (!isOutOfStock) ...[
                      const Text(
                        "Quantity",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        width: 140, // Fixed width for pill
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Decrease
                            GestureDetector(
                              onTap: _decreaseQuantity,
                              child: Container(
                                width: 35,
                                height: 35,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.remove, size: 18),
                              ),
                            ),
                            
                            // Number
                            Text(
                              '$_quantity',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            
                            // Increase
                            GestureDetector(
                              onTap: _increaseQuantity,
                              child: Container(
                                width: 35,
                                height: 35,
                                decoration: const BoxDecoration(
                                  color: Colors.black, // High contrast for add
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      
      // 3. FIXED BOTTOM BAR (CTA)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: !isOutOfStock
                  ? () {
                      Provider.of<CartProvider>(context, listen: false)
                          .addItem(widget.product, quantity: _quantity);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$_quantity x ${widget.product.name} added!'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  : null,
              icon: Icon(isOutOfStock ? Icons.remove_shopping_cart : Icons.shopping_bag_outlined),
              label: Text(isOutOfStock ? 'Sold Out' : 'Add to Cart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, // Transparent to show gradient
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ).copyWith(
                // Gradient Background workaround for ElevatedButton
                backgroundBuilder: (context, states, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: !isOutOfStock
                          ? const LinearGradient(
                              colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : const LinearGradient(colors: [Colors.grey, Colors.grey]),
                      boxShadow: !isOutOfStock
                          ? [
                              BoxShadow(
                                color: orangeColor.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ]
                          : [],
                    ),
                    child: child,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget for Glassmorphism Buttons
  Widget _buildGlassIcon({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1), // Dark glass
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: Colors.red, size: 20),
          ),
        ),
      ),
    );
  }
}