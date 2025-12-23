// lib/screens/categories_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eight_express/models/category_model.dart';
import 'package:eight_express/providers/category_provider.dart';
import 'package:eight_express/screens/product_listing_screen.dart';
// ADDED: Import for your signature 08 loader
import 'package:eight_express/widgets/custom_loader.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color orangeColor = Color(0xFFFE7F2D);
    const Color backgroundColor = Color(0xFFF5F6F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
            color: backgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Explore',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Browse by category',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                // --- UPDATED: Using Custom 08 Loader for Main List ---
                if (categoryProvider.isLoading && categoryProvider.categories.isEmpty) {
                  return const Center(child: CustomLoader(size: 70));
                }

                if (categoryProvider.errorMessage != null && categoryProvider.categories.isEmpty) {
                  return _buildErrorView(categoryProvider, orangeColor);
                }

                if (categoryProvider.categories.isEmpty) {
                  return _buildEmptyView(categoryProvider, orangeColor);
                }

                final activeCategories = categoryProvider.categories.where((c) => c.active).toList();

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15.0,
                    mainAxisSpacing: 15.0,
                    childAspectRatio: 0.9, 
                  ),
                  itemCount: activeCategories.length,
                  itemBuilder: (context, index) {
                    final category = activeCategories[index];
                    return CategoryGridItem(category: category, accentColor: orangeColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(CategoryProvider provider, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
          const SizedBox(height: 10),
          Text(provider.errorMessage!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () => provider.fetchCategories(),
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(CategoryProvider provider, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text('No categories available', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () => provider.fetchCategories(),
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class CategoryGridItem extends StatelessWidget {
  final AppCategory category;
  final Color accentColor;

  const CategoryGridItem({Key? key, required this.category, required this.accentColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ProductListingScreen(categoryName: category.name),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), offset: const Offset(0, 4), blurRadius: 15, spreadRadius: 2),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: category.imageUrl.isNotEmpty
                          ? Hero(
                              tag: 'catImg${category.name}',
                              child: CachedNetworkImage(
                                imageUrl: category.imageUrl,
                                fit: BoxFit.contain,
                                // --- UPDATED: Using Small Custom 08 Loader for Image Placeholder ---
                                placeholder: (context, url) => const Center(child: CustomLoader(size: 30)),
                                errorWidget: (context, url, error) => Icon(category.icon ?? Icons.category, size: 40, color: Colors.grey[300]),
                              ),
                            )
                          : Icon(category.icon ?? Icons.category, size: 50, color: accentColor.withOpacity(0.5)),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        category.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.grey[50], shape: BoxShape.circle),
                  child: Icon(Icons.arrow_outward_rounded, size: 14, color: accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}