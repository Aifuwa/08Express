import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/screens/cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _currentImageIndex = 0; // Tracks the current slide

  void _increaseQuantity() {
    // Check if current quantity is less than available stock
    if (_quantity < widget.product.stock) {
      setState(() {
        _quantity++;
      });
    } else {
      // Show warning if user tries to exceed stock
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sorry, only ${widget.product.stock} items available.'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  void _decreaseQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  // --- Manual Input Dialog ---
  Future<void> _showManualQuantityDialog() async {
    TextEditingController qtyController =
        TextEditingController(text: _quantity.toString());

    String? result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Quantity'),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, qtyController.text),
            child:
                const Text('Set', style: TextStyle(color: Color(0xFFFE7F2D))),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      int? val = int.tryParse(result);
      if (val != null && val > 0) {
        // Validation: Cannot order more than stock
        if (val > widget.product.stock) {
          val = widget.product.stock;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Quantity adjusted to maximum stock (${widget.product.stock})'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        setState(() {
          _quantity = val!;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    const Color orangeColor = Color(0xFFFE7F2D);
    
    // Logic for Stock Display
    final bool isOutOfStock = widget.product.stock <= 0;
    final bool isLowStock = !isOutOfStock && widget.product.stock <= 10;
    
    // Check if we have reached max capacity for the + button
    final bool isMaxStockReached = _quantity >= widget.product.stock;

    return Scaffold(
      backgroundColor: Colors.white,
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CartScreen()),
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
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
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
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            // 1. IMAGE CAROUSEL (Updated for Multiple Images)
            SizedBox(
              height: size.height * 0.45,
              width: double.infinity,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: widget.product.images.isNotEmpty 
                        ? widget.product.images.length 
                        : 1,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      // Logic: Use the list if available, else fallback to single imageUrl
                      String imgUrl = widget.product.images.isNotEmpty
                          ? widget.product.images[index]
                          : widget.product.imageUrl;

                      // Hero Tag Logic: Only match the Grid tag on the first image to avoid errors
                      String heroTag = (index == 0) 
                          ? 'productImage${widget.product.id}' 
                          : 'productImage${widget.product.id}_$index';

                      return Hero(
                        tag: heroTag,
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: orangeColor,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Bottom Gradient
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
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1)
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Dot Indicators (Only show if more than 1 image)
                  if (widget.product.images.length > 1)
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.product.images.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentImageIndex == index ? 20 : 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index 
                                  ? orangeColor 
                                  : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. CONTENT
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, -5))
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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

                    // --- STOCK STATUS ROW UPDATED ---
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOutOfStock
                                ? Colors.red
                                : (isLowStock ? Colors.orange : Colors.green),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOutOfStock
                              ? 'Out of Stock'
                              : (isLowStock
                                  ? 'Only ${widget.product.stock} left!'
                                  : 'In Stock'),
                          style: TextStyle(
                            color: isOutOfStock
                                ? Colors.red
                                : (isLowStock
                                    ? Colors.orange
                                    : Colors.green[700]),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 25),

                    const Text(
                      "Description",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.product.description,
                      style: TextStyle(
                          fontSize: 15, height: 1.6, color: Colors.grey[600]),
                    ),

                    const SizedBox(height: 30),

                    // Quantity Section
                    if (!isOutOfStock) ...[
                      const Text(
                        "Quantity",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        width: 140,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
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

                            // --- CLICKABLE QUANTITY TEXT ---
                            GestureDetector(
                              onTap: _showManualQuantityDialog,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            GestureDetector(
                              onTap: isMaxStockReached ? null : _increaseQuantity,
                              child: Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  // Change color if max stock reached
                                  color: isMaxStockReached ? Colors.grey : Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 18),
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

      // --- FIXED GRADIENT BUTTON SECTION ---
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
          child: Container(
            height: 55,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: !isOutOfStock
                  ? const LinearGradient(
                      colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Colors.grey, Colors.grey]),
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
            child: ElevatedButton.icon(
              onPressed: !isOutOfStock
                  ? () {
                      bool success = Provider.of<CartProvider>(context, listen: false)
                          .addItem(widget.product, quantity: _quantity);

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_quantity x ${widget.product.name} added!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot add. Maximum stock reached in cart.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  : null,
              icon: Icon(isOutOfStock
                  ? Icons.remove_shopping_cart
                  : Icons.shopping_bag_outlined),
              label: Text(isOutOfStock ? 'Sold Out' : 'Add to Cart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIcon(
      {required IconData icon, required VoidCallback onTap}) {
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
              color: Colors.black.withOpacity(0.1),
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