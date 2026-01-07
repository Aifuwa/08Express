import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/providers/product_provider.dart'; // Ensure this exists
import 'package:eight_express/widgets/product_grid_item.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    
    // Get product IDs from UserProvider (Loaded from Firestore)
    final wishlistIds = userProvider.appUser?.wishlist ?? [];
    
    // Find matching products in ProductProvider
    final wishlistItems = productProvider.products
        .where((p) => wishlistIds.contains(p.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("My Wishlist", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: wishlistItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text("Wishlist is empty", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("Save items you love here!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: wishlistItems.length,
              itemBuilder: (ctx, i) => ProductGridItem(product: wishlistItems[i]),
            ),
    );
  }
}