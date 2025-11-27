// lib/screens/product_listing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eight_express/models/product.dart'; // Import your Product model
import 'package:eight_express/providers/product_provider.dart'; // Import your ProductProvider
import 'package:eight_express/screens/product_detail_screen.dart'; // Import your ProductDetailScreen

class ProductListingScreen extends StatefulWidget {
  // This screen now expects a categoryName to filter products
  final String categoryName;

  const ProductListingScreen({
    Key? key,
    required this.categoryName,
  }) : super(key: key);

  @override
  State<ProductListingScreen> createState() => _ProductListingScreenState();
}

class _ProductListingScreenState extends State<ProductListingScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch products specifically for this category when the screen initializes
    // Using addPostFrameCallback to ensure context is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false)
          .fetchProducts(categoryName: widget.categoryName);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color orangeColor = Color(0xFFFE7F2D); // Consistent accent color

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Products'), // Display the category name
        backgroundColor: orangeColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          if (productProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: orangeColor),
            );
          }

          if (productProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    productProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      productProvider.fetchProducts(categoryName: widget.categoryName); // Retry fetch
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orangeColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (productProvider.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sentiment_dissatisfied, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text(
                    'No products found in this category.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Display products in a grid
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Two items per row
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.7, // Adjust ratio for better product card display
            ),
            itemCount: productProvider.products.length,
            itemBuilder: (context, index) {
              final product = productProvider.products[index];
              return ProductGridItem(product: product, accentColor: orangeColor);
            },
          );
        },
      ),
    );
  }
}

// Widget for a single product item in the grid
class ProductGridItem extends StatelessWidget {
  final Product product;
  final Color accentColor;

  const ProductGridItem({Key? key, required this.product, required this.accentColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        print('Tapped on product: ${product.name}');
        // Navigate to the ProductDetailScreen, passing the entire product object
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Card(
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Hero( // Added Hero widget for product image transition
                tag: 'productImage${product.id}', // Unique tag for Hero animation
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(color: accentColor.withOpacity(0.7)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey[400]),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                // --- FIX START ---
                child: SingleChildScrollView( // Wrap the inner Column with SingleChildScrollView
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[850],
                        ),
                        maxLines: 2, // Keep maxLines for visual control, but scrolling handles overflow
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\₦${product.price.toStringAsFixed(2)}', // Using Naira symbol
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // You can add more product details here if needed, like rating or stock info
                    ],
                  ),
                ),
                // --- FIX END ---
              ),
            ),
          ],
        ),
      ),
    );
  }
}