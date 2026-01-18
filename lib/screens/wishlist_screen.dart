import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/widgets/product_grid_item.dart';
import 'package:eight_express/widgets/custom_loader.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Get the list of Hearted IDs from the UserProvider
    final userProv = Provider.of<UserProvider>(context);
    final List<String> wishlistIds = userProv.appUser?.wishlist ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- MINIMAL TEXT HEADER ---
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 70, 25, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Wishlist",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  "${wishlistIds.length} items saved",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // --- PRODUCT CONTENT ---
          Expanded(
            child: wishlistIds.isEmpty
                ? _buildEmptyState()
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('products').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CustomLoader(size: 50));
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      // Filter products matching IDs in the database wishlist
                      final allProducts = snapshot.data!.docs
                          .map((doc) => Product.fromFirestore(doc))
                          .toList();
                      
                      final wishlistedItems = allProducts
                          .where((p) => wishlistIds.contains(p.id))
                          .toList();

                      if (wishlistedItems.isEmpty) {
                        return _buildEmptyState();
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, 
                          childAspectRatio: 0.64, 
                          crossAxisSpacing: 15, 
                          mainAxisSpacing: 15
                        ),
                        itemCount: wishlistedItems.length,
                        itemBuilder: (ctx, i) => ProductGridItem(product: wishlistedItems[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(Icons.favorite_border_rounded, size: 70, color: Colors.grey[200]),
          const SizedBox(height: 20),
          const Text(
            "Empty Wishlist", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)
          ),
          const SizedBox(height: 8),
          const Text(
            "Items you heart will appear here.", 
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ]
      ),
    );
  }
}