import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/wishlist_provider.dart';
import 'package:eight_express/screens/home_screen.dart'; 

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlist = Provider.of<WishlistProvider>(context);
    final items = wishlist.items.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: items.isEmpty
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
                childAspectRatio: 0.68,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) => ProductGridItem(product: items[i]),
            ),
    );
  }
}