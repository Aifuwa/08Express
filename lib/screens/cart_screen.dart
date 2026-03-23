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
    
    // Get wishlist IDs from user profile
    final List<String> wishlistIds = userProv.appUser?.wishlist ?? [];
    
    const Color primaryColor = Color(0xFFFE7F2D);
    const Color bgColor = Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () {
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
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              tooltip: "Clear Bag",
              onPressed: () => _showClearCartDialog(context, cart),
            )
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- SECTION 1: CART ITEMS WITH AUTOMATIC CLEANUP ---
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
                    
                    // --- REAL-TIME SYNC & VALIDATION WRAPPER ---
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('products').doc(productId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _StylishCartItem(productId: productId, item: item, primaryColor: primaryColor);
                        }

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final prodData = Product.fromFirestore(snapshot.data!);
                          
                          // --- CRITICAL: AUTO-REMOVAL LOGIC ---
                          // 1. If Price is set to 0 or less on backend
                          // 2. If Product Stock is completely depleted (0)
                          if (prodData.price <= 0 || prodData.stock <= 0) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              cart.removeItem(productId);
                              _showAutoRemoveToast(context, item.name, prodData.price <= 0 ? "unavailable" : "out of stock");
                            });
                            return const SizedBox.shrink(); 
                          }

                          // Calculate latest purchase limits
                          int warehouseStock = prodData.stock;
                          int purchaseLimit = prodData.maxPurchaseLimit;
                          int effectiveLimit = (purchaseLimit <= 0 || purchaseLimit >= warehouseStock) 
                                               ? warehouseStock 
                                               : purchaseLimit;

                          // Sync data if price or stock limit changed on backend
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            cart.syncProductData(productId, prodData.price, effectiveLimit);
                          });
                        } 
                        // If product is deleted from Database entirely
                        else if (snapshot.hasData && !snapshot.data!.exists) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            cart.removeItem(productId);
                          });
                          return const SizedBox.shrink();
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

          // --- SECTION 2: ORDER SUMMARY (Visible only when cart has items) ---
          if (cart.items.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildOrderSummary(cart),
            ),

          // --- SECTION 3: WISHLIST HEADER ---
          if (wishlistIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 15),
                child: Row(
                  children: [
                    Container(width: 4, height: 22, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    const Text(
                      "Saved for Later",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
            ),

          // --- SECTION 4: WISHLIST GRID ---
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
                      childAspectRatio: 0.72, 
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _WishlistCard(product: wishItems[i], primaryColor: primaryColor),
                      childCount: wishItems.length,
                    ),
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
      
      bottomSheet: cart.items.isEmpty 
        ? null 
        : _buildStylishCheckoutBar(context, cart, primaryColor),
    );
  }

  void _showAutoRemoveToast(BuildContext context, String name, String reason) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("'$name' was removed because it is $reason."),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100)
      ),
      child: Column(
        children: [
          _summaryRow("Subtotal", "₦${cart.totalAmount.toStringAsFixed(0)}"),
          const SizedBox(height: 12),
          _summaryRow("Delivery Fee", "Calculated at checkout", isValueGrey: true),
          const Divider(height: 30, thickness: 0.5),
          _summaryRow("Total Amount", "₦${cart.totalAmount.toStringAsFixed(0)}", isBold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isValueGrey = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isBold ? Colors.black : Colors.grey[600], fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        Text(value, style: TextStyle(color: isValueGrey ? Colors.grey : Colors.black, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: isBold ? 17 : 14)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 100),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 80, color: Color(0xFFFE7F2D)),
            ),
            const SizedBox(height: 30),
            const Text("Your bag is empty", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 12),
            const Text("Items added to your bag will appear here.\nStart exploring our products today!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.4, fontSize: 15)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE7F2D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 10,
                shadowColor: const Color(0xFFFE7F2D).withOpacity(0.4),
              ),
              child: const Text("DISCOVER PRODUCTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 40, offset: const Offset(0, -10))],
      ),
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Price", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
                  SizedBox(height: 2),
                  Text("Incl. of all taxes", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Text(
                "₦${cart.totalAmount.toStringAsFixed(0)}", 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1)
              ),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(totalAmount: cart.totalAmount))),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("PROCEED TO CHECKOUT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16)
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
        title: const Text("Empty Bag?"),
        content: const Text("This will remove all items from your bag. Are you sure?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Stay", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(ctx);
            },
            child: const Text("Empty Now", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Quantity", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("How many units would you like?", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                hintText: "E.g. 5",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Allowed unit limit: ${item.maxStock}",
              style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
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
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final int? val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                if (val > item.maxStock) {
                  cart.setQuantity(productId, item.maxStock);
                } else {
                  cart.setQuantity(productId, val);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save Change", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        padding: const EdgeInsets.only(right: 30),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 35),
      ),
      onDismissed: (_) {
        cart.removeItem(productId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
          ]
        ),
        child: Row(
          children: [
            Container(
              width: 95, height: 95,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey[50],
                image: DecorationImage(
                  image: CachedNetworkImageProvider(item.imageUrl),
                  fit: BoxFit.cover
                )
              ),
            ),
            const SizedBox(width: 18),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name, 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.2, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₦${item.price.toStringAsFixed(0)}", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: -0.5),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade100)
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.add, 
                    onTap: () {
                      bool success = cart.incrementItem(productId);
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Limit of ${item.maxStock} reached."))
                        );
                      }
                    }
                  ),
                  
                  GestureDetector(
                    onTap: () => _showManualQuantityDialog(context, cart),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${item.quantity}', 
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)
                      ),
                    ),
                  ),
                  
                  _QtyButton(
                    icon: Icons.remove, 
                    onTap: () => cart.removeSingleItem(productId)
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

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 18, color: Colors.black),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: product.imageUrl, 
                    width: double.infinity, height: double.infinity, fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 10, top: 10,
                    child: GestureDetector(
                      onTap: () => userProv.toggleWishlist(product.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.black),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("₦${product.price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    GestureDetector(
                      onTap: () {
                        if (product.price > 0 && product.stock > 0) {
                          cart.addItem(product);
                          userProv.toggleWishlist(product.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 16),
                      ),
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