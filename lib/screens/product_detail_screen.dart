import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/user_provider.dart'; 
import 'package:eight_express/screens/cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _currentImageIndex = 0; 

  // --- HELPER LOGIC ---

  /// Calculates the maximum allowed quantity based on both 
  /// warehouse stock and the product's maximum purchase limit.
  int get _effectiveLimit {
    int warehouseStock = widget.product.stock;
    int purchaseLimit = widget.product.maxPurchaseLimit;

    // If limit is 0 or invalid, only warehouse stock matters.
    if (purchaseLimit <= 0 || purchaseLimit >= warehouseStock) {
      return warehouseStock;
    }
    return purchaseLimit;
  }

  void _increaseQuantity() {
    // Check if current quantity is less than the effective limit
    if (_quantity < _effectiveLimit) {
      setState(() {
        _quantity++;
      });
    } else {
      // Logic for different warning messages
      String warning = _quantity >= widget.product.stock 
          ? 'Sorry, only ${widget.product.stock} items available.' 
          : 'Limit reached: You can only buy ${widget.product.maxPurchaseLimit} units of this item.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
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
            child: const Text('Set', style: TextStyle(color: Color(0xFFFE7F2D))),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      int? val = int.tryParse(result);
      if (val != null && val > 0) {
        // Validation: Cannot order more than effective limit
        if (val > _effectiveLimit) {
          val = _effectiveLimit;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Quantity adjusted to allowed limit ($val)'),
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

  // --- CART ADD LOGIC ---
  void _addToCart(CartProvider cart) {
    if (widget.product.stock <= 0) return;

    // Try adding to cart via provider logic
    bool success = cart.addItem(widget.product, quantity: _quantity);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text('$_quantity x ${widget.product.name} added!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } else {
       // This usually means adding more would exceed stock or limits inside the cart logic
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add more. Check cart or stock limits.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          duration: Duration(milliseconds: 2000),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    const Color orangeColor = Color(0xFFFE7F2D);
    final userProv = Provider.of<UserProvider>(context);
    final cart = Provider.of<CartProvider>(context); // Listen to cart for badge
    
    // Logic for Stock Display
    final bool isOutOfStock = widget.product.stock <= 0;
    final bool isLowStock = !isOutOfStock && widget.product.stock <= 10;
    
    // Check if we have reached max capacity for the + button
    final bool isMaxStockReached = _quantity >= _effectiveLimit;

    // Wishlist Status
    final bool isFavorite = userProv.appUser?.wishlist.contains(widget.product.id) ?? false;

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
            iconColor: Colors.black87,
            onTap: () => Navigator.pop(context),
          ),
        ),
        actions: [
          // --- WISHLIST GLASS ICON ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: _buildGlassIcon(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              iconColor: isFavorite ? Colors.red : Colors.black87,
              onTap: () => userProv.toggleWishlist(widget.product.id),
            ),
          ),
          // --- CART GLASS ICON ---
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 10, top: 8.0, bottom: 8.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildGlassIcon(
                  icon: Icons.shopping_cart_outlined,
                  iconColor: Colors.black87,
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
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${cart.itemCount}',
                        textAlign: TextAlign.center,
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
        ],
      ),
      
      // --- BODY ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            // 1. IMAGE CAROUSEL
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
                      String imgUrl = widget.product.images.isNotEmpty
                          ? widget.product.images[index]
                          : widget.product.imageUrl;

                      // Only use Hero for the first image to prevent tag conflicts
                      String heroTag = (index == 0) 
                          ? 'productImage${widget.product.id}' 
                          : 'productImage${widget.product.id}_detail_$index';

                      return Hero(
                        tag: heroTag,
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.contain, // Changed to contain so whole product shows
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[50],
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

                  // Gradient Overlay for visibility
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
                            Colors.black.withOpacity(0.05)
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Page Indicator
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
                            height: 6,
                            width: _currentImageIndex == index ? 20 : 6,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index 
                                  ? orangeColor 
                                  : Colors.grey.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. PRODUCT DETAILS SHEET
            Transform.translate(
              offset: const Offset(0, -20),
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
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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

                    // Category Tag
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
                    const SizedBox(height: 12),

                    // Name & Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          '₦${widget.product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: orangeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Stock Status
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
                                  ? 'Low Stock: Only ${widget.product.stock} left'
                                  : 'In Stock'),
                          style: TextStyle(
                            color: isOutOfStock
                                ? Colors.red
                                : (isLowStock
                                    ? Colors.orange
                                    : Colors.green[700]),
                            fontSize: 13,
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
                      widget.product.description.isEmpty 
                          ? "No description available." 
                          : widget.product.description,
                      style: TextStyle(
                          fontSize: 15, height: 1.6, color: Colors.grey[600]),
                    ),

                    const SizedBox(height: 30),

                    // Quantity Selector
                    if (!isOutOfStock) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Quantity",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _decreaseQuantity,
                                  icon: const Icon(Icons.remove, size: 18),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                ),
                                GestureDetector(
                                  onTap: _showManualQuantityDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      '$_quantity',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: isMaxStockReached ? null : _increaseQuantity,
                                  icon: Icon(Icons.add, 
                                      size: 18, 
                                      color: isMaxStockReached ? Colors.grey : Colors.black
                                  ),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // --- BOTTOM ACTION BAR ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), // Extra bottom padding for iOS home bar
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
        child: SizedBox(
          height: 55,
          child: ElevatedButton(
            onPressed: !isOutOfStock
                ? () => _addToCart(cart)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isOutOfStock ? Colors.grey : orangeColor,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              elevation: isOutOfStock ? 0 : 5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOutOfStock ? Icons.remove_shopping_cart : Icons.shopping_bag_outlined, 
                  color: Colors.white
                ),
                const SizedBox(width: 10),
                Text(
                  isOutOfStock ? 'Sold Out' : 'Add to Cart',
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- REUSABLE GLASS ICON HELPER ---
  Widget _buildGlassIcon(
      {required IconData icon, required VoidCallback onTap, Color? iconColor}) {
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
              color: Colors.white.withOpacity(0.8), // Slightly more opaque for better visibility
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
              ]
            ),
            child: Icon(icon, color: iconColor ?? Colors.black87, size: 20),
          ),
        ),
      ),
    );
  }
}