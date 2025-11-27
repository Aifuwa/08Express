// lib/screens/categories_screen.dart (CORRECTED)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eight_express/models/category_model.dart';
import 'package:eight_express/providers/category_provider.dart';
import 'package:eight_express/screens/product_listing_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  // It's a good practice to trigger the initial fetch here if not already done in the provider's constructor.
  // Although your CategoryProvider's constructor calls fetchCategories(),
  // adding it here makes sure the data is fresh if the screen is rebuilt or navigated back to.
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
            child: Text(
              'Categories',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[850],
              ),
            ),
          ),
          Expanded(
            child: Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                // If loading AND no categories are loaded yet, show indicator
                if (categoryProvider.isLoading && categoryProvider.categories.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: orangeColor));
                }

                // If there's an error message AND no categories are loaded
                if (categoryProvider.errorMessage != null && categoryProvider.categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          categoryProvider.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            categoryProvider.fetchCategories(); // Retry fetching
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

                // If categories list is empty after loading (and no error)
                if (categoryProvider.categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        const Text(
                          'No categories found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        if (categoryProvider.errorMessage != null) // Show error message even if retry didn't work
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Last error: ${categoryProvider.errorMessage!}',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            categoryProvider.fetchCategories();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orangeColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                // Display the grid of categories
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: categoryProvider.categories.length,
                    itemBuilder: (context, index) {
                      final category = categoryProvider.categories[index];
                      // Filter out inactive categories if desired
                      if (!category.active) {
                        return const SizedBox.shrink(); // Hide inactive categories
                      }
                      return CategoryGridItem(category: category, accentColor: orangeColor);
                    },
                  ),
                );
              },
            ),
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
        print('Tapped on ${category.name}, navigating to products...');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ProductListingScreen(
              categoryName: category.name, // Pass the category NAME
            ),
          ),
        );
      },
      child: Card(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
                  child: category.imageUrl.isNotEmpty // Check if imageUrl is not empty
                      ? CachedNetworkImage(
                          imageUrl: category.imageUrl,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(color: accentColor.withOpacity(0.7)),
                          ),
                          errorWidget: (context, url, error) => Center(
                            // Show fallback icon if image fails to load
                            child: category.icon != null
                                ? Icon(category.icon, size: 50, color: accentColor)
                                : const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                          fit: BoxFit.contain,
                        )
                      : Center(
                          // Show fallback icon if imageUrl is empty
                          child: category.icon != null
                              ? Icon(category.icon, size: 50, color: accentColor)
                              : const Icon(Icons.category, size: 50, color: Colors.grey), // Default category icon
                        ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text(
                    category.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}