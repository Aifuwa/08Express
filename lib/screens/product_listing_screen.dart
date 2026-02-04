import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/product_provider.dart';
import 'package:eight_express/widgets/product_grid_item.dart'; 
import 'package:eight_express/widgets/custom_loader.dart'; 
import 'package:eight_express/services/remote_config_service.dart';

class ProductListingScreen extends StatefulWidget {
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
    // Fetch initial 16 products for this category on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  /// Initial load resets the provider state for this specific category
  Future<void> _loadInitialData() async {
    await Provider.of<ProductProvider>(context, listen: false)
        .fetchProducts(categoryName: widget.categoryName, refresh: true);
  }

  /// Triggered when user clicks 'Load More'
  Future<void> _loadMoreData() async {
    await Provider.of<ProductProvider>(context, listen: false)
        .fetchProducts(categoryName: widget.categoryName, refresh: false);
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF8F9FA); 
    final primaryColor = RemoteConfigService.getPrimaryColor();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          
          // 1. INITIAL FULL-SCREEN LOADING STATE
          if (productProvider.isLoading && productProvider.products.isEmpty) {
            return const Center(child: CustomLoader(size: 70));
          }

          // 2. ERROR STATE
          if (productProvider.errorMessage != null && productProvider.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 50, color: Colors.red.shade300),
                  const SizedBox(height: 10),
                  Text(productProvider.errorMessage!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _loadInitialData,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          // 3. EMPTY STATE
          if (productProvider.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text("No items found in this category.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // 4. DATA LIST WITH PAGINATION
          return RefreshIndicator(
            onRefresh: _loadInitialData,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- THE PRODUCT GRID ---
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), // Scroll handled by Parent
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15.0,
                      mainAxisSpacing: 15.0,
                      childAspectRatio: 0.65, 
                    ),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      return ProductGridItem(
                        key: ValueKey(productProvider.products[index].id),
                        product: productProvider.products[index],
                      );
                    },
                  ),

                  const SizedBox(height: 25),

                  // --- PAGINATION CONTROL (LOAD MORE) ---
                  if (productProvider.hasMore)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: productProvider.isLoadingMore
                          ? const CustomLoader(size: 30) // Spinner when loading more
                          : ElevatedButton(
                              onPressed: _loadMoreData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryColor,
                                elevation: 0,
                                side: BorderSide(color: Colors.grey.shade300),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                "LOAD MORE PRODUCTS",
                                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                    ),
                  
                  // END OF LIST MESSAGE
                  if (!productProvider.hasMore && productProvider.products.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "You've reached the end of this category",
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                    
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}