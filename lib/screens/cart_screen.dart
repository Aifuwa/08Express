import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/checkout_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/models/cart_item.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final userProv = Provider.of<UserProvider>(context);
    
    // Get wishlist IDs
    final List<String> wishlistIds = userProv.appUser?.wishlist ?? [];
    
    const Color primaryColor = Color(0xFFFE7F2D);
    const Color bgColor = Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () {
            // --- FIXED: SMART POP LOGIC TO PREVENT BLACK SCREEN ---
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => const HomeScreen())
              );
            }
          },
        ),
        title: Column(
          children: [
            const Text(
              "My Bag",
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (cart.itemCount > 0)
              Text(
                "${cart.itemCount} items",
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          if (cart.itemCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.black54),
              tooltip: "Clear Bag",
              onPressed: () => _showClearCartDialog(context, cart),
            )
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- SECTION 1: CART ITEMS WITH REAL-TIME LISTENER ---
          if (cart.items.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyState(context),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final String productId = cart.items.keys.elementAt(i);
                    final CartItem item = cart.items.values.elementAt(i);
                    
                    // --- REAL-TIME SYNC WRAPPER ---
                    // This listens to the specific product in Firestore
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('products').doc(productId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final prodData = Product.fromFirestore(snapshot.data!);
                          
                          // Calculate the new effective limit (Stock vs maxPurchaseLimit)
                          int effectiveLimit = prodData.stock;
                          if (prodData.maxPurchaseLimit > 0 && prodData.maxPurchaseLimit < prodData.stock) {
                            effectiveLimit = prodData.maxPurchaseLimit;
                          }

                          // IF ADMIN REDUCED LIMIT: Automatically shrink the user's cart item
                          if (item.quantity > effectiveLimit) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              cart.setQuantity(productId, effectiveLimit);
                            });
                          }
                        }
                        
                        return _StylishCartItem(
                          productId: productId,
                          item: item,
                          primaryColor: primaryColor,
                        );
                      },
                    );
                  },
                  childCount: cart.items.length,
                ),
              ),
            ),

          // --- SECTION 2: WISHLIST HEADER (ALWAYS VISIBLE) ---
          if (wishlistIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 15),
                child: Row(
                  children: [
                    Container(width: 4, height: 20, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    const Text(
                      "Saved for Later",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),

          // --- SECTION 3: WISHLIST GRID (ALWAYS VISIBLE) ---
          if (wishlistIds.isNotEmpty)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where(FieldPath.documentId, whereIn: wishlistIds.take(10).toList())
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                final wishItems = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.70, 
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _WishlistCard(product: wishItems[i], primaryColor: primaryColor),
                      childCount: wishItems.length,
                    ),
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
      
      // --- FLOATING CHECKOUT BAR ---
      bottomSheet: cart.items.isEmpty 
        ? null 
        : _buildStylishCheckoutBar(context, cart, primaryColor),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)]
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 60, color: Color(0xFFFE7F2D)),
            ),
            const SizedBox(height: 25),
            const Text("Your bag is empty", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Looks like you haven't added\nanything to your cart yet.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE7F2D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 5,
                shadowColor: const Color(0xFFFE7F2D).withOpacity(0.4),
              ),
              child: const Text("START SHOPPING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStylishCheckoutBar(BuildContext context, CartProvider cart, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, -5))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
              Text(
                "₦${cart.totalAmount.toStringAsFixed(0)}", 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(totalAmount: cart.totalAmount))),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 8,
                shadowColor: color.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("CHECKOUT", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Bag"),
        content: const Text("Remove all items from your shopping bag?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(ctx);
            },
            child: const Text("Yes, Clear", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StylishCartItem extends StatelessWidget {
  final String productId;
  final CartItem item;
  final Color primaryColor;

  const _StylishCartItem({required this.productId, required this.item, required this.primaryColor});

  void _showManualQuantityDialog(BuildContext context, CartProvider cart) {
    final TextEditingController controller = TextEditingController(text: item.quantity.toString());
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Edit Quantity", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter number",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Allowed Limit: ${item.maxStock}",
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final int? val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                if (val > item.maxStock) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Cannot exceed allowed limit (${item.maxStock})"),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  cart.setQuantity(productId, item.maxStock);
                } else {
                  cart.setQuantity(productId, val);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Dismissible(
      key: ValueKey(productId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 20),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE5E5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 30),
      ),
      onDismissed: (_) {
        cart.removeItem(productId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${item.name} removed"),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: primaryColor,
              onPressed: () {
                // FIXED: Snapped product state for Undo including maxPurchaseLimit
                cart.addItem(
                  Product(
                    id: productId, name: item.name, price: item.price, imageUrl: item.imageUrl,
                    images: [item.imageUrl], 
                    category: '', description: '', 
                    stock: 999, 
                    maxPurchaseLimit: item.maxStock, 
                    createdAt: Timestamp.now()
                  ),
                  quantity: item.quantity
                );
              },
            ),
          )
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))
          ]
        ),
        child: Row(
          children: [
            Hero(
              tag: 'cartImg$productId',
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[50],
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(item.imageUrl),
                    fit: BoxFit.cover
                  )
                ),
              ),
            ),
            const SizedBox(width: 15),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name, 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₦${item.price.toStringAsFixed(0)}", 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryColor),
                  ),
                ],
              ),
            ),

            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove, 
                    onTap: () => cart.removeSingleItem(productId)
                  ),
                  
                  GestureDetector(
                    onTap: () => _showManualQuantityDialog(context, cart),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 30),
                      color: Colors.transparent, 
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}', 
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted
                        )
                      ),
                    ),
                  ),
                  
                  _QtyButton(
                    icon: Icons.add, 
                    color: item.quantity >= item.maxStock ? Colors.grey[400] : Colors.black87,
                    onTap: () {
                      bool success = cart.incrementItem(productId);
                      if (!success) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Reached allowed limit of ${item.maxStock} units."),
                            duration: const Duration(seconds: 2),
                          )
                        );
                      }
                    }
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _QtyButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 16, color: color ?? Colors.black87),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final Product product;
  final Color primaryColor;
  const _WishlistCard({required this.product, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final userProv = Provider.of<UserProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: product.imageUrl, 
                    width: double.infinity, height: double.infinity, fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[50]),
                  ),
                  Positioned(
                    right: 8, top: 8,
                    child: GestureDetector(
                      onTap: () => userProv.toggleWishlist(product.id),
                      child: const CircleAvatar(
                        radius: 12, backgroundColor: Colors.white,
                        child: Icon(Icons.close, size: 14, color: Colors.black),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("₦${product.price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    
                    InkWell(
                      onTap: () {
                        bool success = cart.addItem(product);
                        if (success) {
                           userProv.toggleWishlist(product.id);
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("Moved to cart"), duration: Duration(seconds: 1)),
                           );
                        } else {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                               content: const Text("Limit reached or Out of stock."), 
                               backgroundColor: Colors.red,
                               duration: const Duration(seconds: 1)
                             ),
                           );
                        }
                      },
                      child: Icon(Icons.add_circle, color: primaryColor, size: 24),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}