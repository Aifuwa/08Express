import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/checkout_screen.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/models/cart_item.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final userProv = Provider.of<UserProvider>(context);
    
    // 1. Get the IDs from the User's profile in the database
    final List<String> wishlistIds = userProv.appUser?.wishlist ?? [];
    
    const Color orangeColor = Color(0xFFFE7F2D);
    const Color backgroundColor = Color(0xFFF4F7F9); 

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // 1. HEADER
          _buildHeader(context),

          // 2. SCROLLABLE CONTENT
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- SECTION: ACTIVE CART ---
                if (cart.items.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => CartItemCard(
                          productId: cart.items.keys.elementAt(i),
                          cartItem: cart.items.values.elementAt(i),
                        ),
                        childCount: cart.items.length,
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(child: _buildEmptyCartState(context)),

                // --- SECTION: DYNAMIC WISHLIST (FROM DATABASE) ---
                if (wishlistIds.isNotEmpty)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .where(FieldPath.documentId, whereIn: wishlistIds.take(10).toList())
                        .snapshots(),
                    builder: (context, snapshot) {
                      // Handle loading or errors silently in the cart view
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      }

                      final wishItems = snapshot.data!.docs
                          .map((doc) => Product.fromFirestore(doc))
                          .toList();

                      return SliverMainAxisGroup(
                        slivers: [
                          // Demarcation bar
                          SliverToBoxAdapter(
                            child: _buildSectionDivider(wishItems.length),
                          ),
                          // Horizontal or Grid display for wishlist
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.64,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _WishlistItemSmallCard(product: wishItems[i]),
                                childCount: wishItems.length,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 140)), 
              ],
            ),
          ),
        ],
      ),
      
      // 3. PERSISTENT CHECKOUT BAR
      bottomSheet: cart.items.isNotEmpty 
          ? _buildCheckoutSummary(context, cart, orangeColor) 
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 15),
      width: double.infinity,
      color: Colors.white,
      child: const Center(
        child: Text(
          'Shopping Cart',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
    );
  }

  Widget _buildSectionDivider(int count) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          height: 8, 
          width: double.infinity,
          color: Colors.grey.withOpacity(0.1),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.redAccent, size: 22),
              const SizedBox(width: 10),
              const Text(
                "From your Wishlist",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Spacer(),
              Text("$count items", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCartState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 80, bottom: 20),
      child: Column(
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: InkWell(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)]),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: const Color(0xFFFE7F2D).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: const Center(
                  child: Text("START SHOPPING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSummary(BuildContext context, CartProvider cart, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 16)),
              Text('₦${cart.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(totalAmount: cart.totalAmount))),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("CHECKOUT NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistItemSmallCard extends StatelessWidget {
  final Product product;
  const _WishlistItemSmallCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final userProv = Provider.of<UserProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl, 
                fit: BoxFit.cover, 
                width: double.infinity,
                placeholder: (context, url) => Container(color: Colors.grey[100]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text("₦${product.price.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFFFE7F2D), fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 35,
                  child: ElevatedButton(
                    onPressed: () {
                      cart.addItem(product);
                      userProv.toggleWishlist(product.id); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Moved to cart"), behavior: SnackBarBehavior.floating, duration: Duration(milliseconds: 800)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text("Move to Cart", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class CartItemCard extends StatelessWidget {
  final String productId;
  final CartItem cartItem;

  const CartItemCard({super.key, required this.productId, required this.cartItem});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: CachedNetworkImage(
              imageUrl: cartItem.imageUrl, 
              width: 80, height: 80, 
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[50]),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cartItem.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1),
                const SizedBox(height: 5),
                Text("₦${cartItem.price.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFFFE7F2D), fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
          Column(
            children: [
              _qtyBtn(Icons.add, () {
                cart.addItem(Product(
                  id: cartItem.productId, 
                  name: cartItem.name, 
                  price: cartItem.price, 
                  imageUrl: cartItem.imageUrl,
                  description: '', 
                  category: '', 
                  stock: 99, 
                  createdAt: Timestamp.now()
                ));
              }, isMain: true),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${cartItem.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              _qtyBtn(Icons.remove, () => cart.removeSingleItem(productId), isMain: false),
            ],
          )
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {required bool isMain}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isMain ? const Color(0xFFFE7F2D) : Colors.grey[100], 
        borderRadius: BorderRadius.circular(10)
      ),
      child: Icon(icon, size: 16, color: isMain ? Colors.white : Colors.black),
    ),
  );
}