// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/screens/checkout_screen.dart';
import 'package:eight_express/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/screens/home_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    const Color orangeColor = Color(0xFFFE7F2D);
    const Color backgroundColor = Color(0xFFF5F6F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. COMPACT HEADER (Less Space)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: backgroundColor,
              width: double.infinity,
              alignment: Alignment.center,
              child: const Text(
                'My Cart',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w900, 
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // 2. LIST OR EMPTY STATE
            Expanded(
              child: cart.items.isEmpty
                  ? _buildEmptyCartState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), // Top padding 0 to reduce gap
                      itemCount: cart.items.length,
                      itemBuilder: (ctx, i) {
                        String productId = cart.items.keys.elementAt(i);
                        CartItem cartItem = cart.items.values.elementAt(i);
                        return CartItemCard(
                          productId: productId,
                          cartItem: cartItem,
                        );
                      },
                    ),
            ),

            // 3. CHECKOUT SUMMARY (With Beautiful Button)
            if (cart.items.isNotEmpty)
              _buildCheckoutSummary(context, cart, orangeColor),
          ],
        ),
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyCartState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
              ]
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.orange[200]),
          ),
          const SizedBox(height: 25),
          const Text(
            'Your Cart is Empty',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add items to start shopping',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
               Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const HomeScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE7F2D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text('Start Shopping', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- CHECKOUT SUMMARY ---
  Widget _buildCheckoutSummary(BuildContext context, CartProvider cart, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -5),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              Text(
                '\₦${cart.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 25),
          
          // --- BEAUTIFUL GRADIENT BUTTON ---
          InkWell(
            onTap: cart.itemCount <= 0
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => CheckoutScreen(totalAmount: cart.totalAmount),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 55,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'PROCEED TO CHECKOUT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CART ITEM CARD ---
class CartItemCard extends StatelessWidget {
  final String productId;
  final CartItem cartItem;

  const CartItemCard({
    super.key,
    required this.productId,
    required this.cartItem,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Dismissible(
      key: ValueKey(productId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 30),
      ),
      onDismissed: (direction) => cart.removeItem(productId),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              offset: const Offset(0, 5),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            // IMAGE
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey[50],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: cartItem.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: cartItem.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.withOpacity(0.5))),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 15),
            
            // DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '\₦${cartItem.price.toStringAsFixed(0)}', // Rounded price
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFE7F2D)),
                  ),
                ],
              ),
            ),

            // QUANTITY CONTROLS (Vertical Layout for compactness)
            Column(
              children: [
                _buildQtyBtn(
                  icon: Icons.add, 
                  onTap: () {
                     cart.addItem(Product(
                       id: cartItem.productId,
                       name: cartItem.name,
                       description: '',
                       price: cartItem.price,
                       imageUrl: cartItem.imageUrl,
                       category: '',
                       stock: 999, 
                       createdAt: Timestamp.now(),
                     ));
                  },
                  isAdd: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${cartItem.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                _buildQtyBtn(
                  icon: Icons.remove, 
                  onTap: () => cart.removeSingleItem(productId),
                  isAdd: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyBtn({required IconData icon, required VoidCallback onTap, required bool isAdd}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isAdd ? const Color(0xFFFE7F2D) : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: isAdd ? Colors.white : Colors.black54),
      ),
    );
  }
}