import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eight_express/models/category_model.dart';
import 'package:eight_express/providers/category_provider.dart';
import 'package:eight_express/screens/product_listing_screen.dart';
import 'package:eight_express/widgets/custom_loader.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      if (provider.categories.isEmpty) {
        provider.fetchCategories();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Logic for pull-to-refresh
  Future<void> _refreshCategories() async {
    await Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
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
          // --- HEADER & SEARCH SECTION ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            color: backgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explore',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Search for your favorite categories',
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                
                // --- SEARCH BAR WITH CANCEL BUTTON ---
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search categories...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
                      prefixIcon: const Icon(Icons.search_rounded, color: orangeColor),
                      // CLEAR BUTTON
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- MAIN LIST SECTION ---
          Expanded(
            child: Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                // 1. Loading State
                if (categoryProvider.isLoading && categoryProvider.categories.isEmpty) {
                  return const Center(child: CustomLoader(size: 70));
                }

                // 2. Error State
                if (categoryProvider.errorMessage != null && categoryProvider.categories.isEmpty) {
                  return _buildErrorView(categoryProvider, orangeColor);
                }

                // 3. Filter active categories AND search query
                final displayCategories = categoryProvider.categories.where((c) {
                  final matchesSearch = c.name.toLowerCase().contains(_searchQuery);
                  return c.active && matchesSearch;
                }).toList();

                // 4. Empty State (No search results)
                if (displayCategories.isEmpty) {
                  return _buildEmptyView(categoryProvider, orangeColor);
                }

                // 5. Data Grid with Refresh Indicator
                return RefreshIndicator(
                  onRefresh: _refreshCategories,
                  color: orangeColor,
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15.0,
                      mainAxisSpacing: 15.0,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: displayCategories.length,
                    itemBuilder: (context, index) {
                      final category = displayCategories[index];
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

  Widget _buildErrorView(CategoryProvider provider, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 50, color: Colors.red[300]),
          const SizedBox(height: 15),
          const Text('Connection Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => provider.fetchCategories(),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('TRY AGAIN', style: TextStyle(color: Colors.white)),
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
          Icon(Icons.search_off_rounded, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            _searchQuery.isEmpty ? 'No categories found' : 'No matches for "$_searchQuery"',
            style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isEmpty)
            TextButton.icon(
              onPressed: () => provider.fetchCategories(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('REFRESH LIST'),
              style: TextButton.styleFrom(foregroundColor: accentColor),
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
        // Navigation results in Listing Screen which filters stock and newest first
        Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => ProductListingScreen(categoryName: category.name)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 4),
              blurRadius: 15,
            ),
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
                      padding: const EdgeInsets.all(18.0),
                      child: category.imageUrl.isNotEmpty
                          ? Hero(
                              tag: 'catImg${category.name}',
                              child: CachedNetworkImage(
                                imageUrl: category.imageUrl, // Field name: imageUrl
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(child: CustomLoader(size: 25)),
                                errorWidget: (context, url, error) => const Icon(Icons.category, size: 40, color: Colors.grey),
                              ),
                            )
                          : const Icon(Icons.category, size: 50, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        category.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 15,
                right: 15,
                child: Container(
                  width: 28,
                  height: 28,
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