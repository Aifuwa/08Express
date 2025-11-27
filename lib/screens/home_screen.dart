// lib/screens/home_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/screens/product_detail_screen.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/screens/cart_screen.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/categories_screen.dart';
import 'package:eight_express/screens/profile_screen.dart';
import 'package:eight_express/screens/my_orders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Theme Colors
  final Color _primaryColor = const Color(0xFFFE7F2D); // Orange
  final Color _darkColor = const Color.fromRGBO(57, 64, 83, 1); // Dark Blue/Grey

  // Navigation Options
  final List<Widget> _widgetOptions = <Widget>[
    Container(), // Placeholder for Home (Product Listing)
    const CategoriesScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Set Status Bar to transparent to show gradient
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light clean background for body
      drawer: _buildCustomDrawer(context),
      body: Column(
        children: [
          // 1. Custom Gradient Header with Search
          _buildGradientHeader(context),

          // 2. Main Content
          Expanded(
            child: _selectedIndex == 0
                ? ProductListingScreen(searchQuery: _searchQuery)
                : _widgetOptions.elementAt(_selectedIndex),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Categories'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_rounded), label: 'Cart'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: _primaryColor,
          unselectedItemColor: Colors.grey[400],
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  // --- WIDGET: Gradient Header ---
  Widget _buildGradientHeader(BuildContext context) {
    // Icons for background pattern
    final List<IconData> icons = [Icons.shopping_bag, Icons.local_offer, Icons.card_giftcard, Icons.watch, Icons.phone_iphone];
    final Random random = Random();

    return Container(
      // Height adjusts dynamically but keeps a minimum
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darkColor, _darkColor.withOpacity(0.9), _primaryColor],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: _darkColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Pattern (Faint Icons)
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Stack(
                children: List.generate(12, (index) {
                  return Positioned(
                    left: random.nextDouble() * 300,
                    top: random.nextDouble() * 100,
                    child: Transform.rotate(
                      angle: random.nextDouble() * pi,
                      child: Icon(icons[index % icons.length], color: Colors.white, size: 20 + random.nextDouble() * 30),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Header Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Menu + Title + Cart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const Text(
                    "Eight Express",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 28),
                        onPressed: () => _onItemTapped(2),
                      ),
                      Consumer<CartProvider>(
                        builder: (_, cart, ch) => cart.itemCount > 0
                            ? Positioned(
                                right: 5,
                                top: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    '${cart.itemCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : Container(),
                      )
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'What are you looking for?',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: _primaryColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Custom Drawer ---
  Widget _buildCustomDrawer(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.appUser;

    final String safeName = user?.name ?? '';
    final String displayInitial = safeName.isNotEmpty ? safeName[0].toUpperCase() : 'G';
    final String displayName = safeName.isNotEmpty ? safeName : 'Guest User';
    final String displayEmail = user?.email ?? 'Sign in to sync data';

    return Drawer(
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_darkColor, _primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      displayInitial,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    displayEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.home_rounded, 'Home', () { Navigator.pop(context); _onItemTapped(0); }),
                _buildDrawerItem(Icons.grid_view_rounded, 'Categories', () { Navigator.pop(context); _onItemTapped(1); }),
                _buildDrawerItem(Icons.shopping_bag_rounded, 'My Orders', () {
                   Navigator.pop(context);
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
                }),
                _buildDrawerItem(Icons.person_rounded, 'Profile', () { Navigator.pop(context); _onItemTapped(3); }),
                const Divider(),
                _buildDrawerItem(Icons.logout_rounded, 'Logout', () async {
                  Navigator.pop(context);
                  await userProvider.signOut();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: _darkColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

// --- PRODUCT LISTING SCREEN ---
class ProductListingScreen extends StatelessWidget {
  final String searchQuery;
  const ProductListingScreen({super.key, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No products found.'));

        List<Product> products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

        if (searchQuery.isNotEmpty) {
          products = products.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
        }

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text('No results for "$searchQuery"', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text('Results for ', style: TextStyle(color: Colors.grey)),
                    Text('"$searchQuery"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.70,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) => ProductGridItem(product: products[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- REDESIGNED PRODUCT ITEM WITH QUANTITY CONTROLS ---
class ProductGridItem extends StatelessWidget {
  final Product product;
  const ProductGridItem({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    // We used to simple return a container. Now we listen to CartProvider.
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ProductDetailScreen(product: product)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Hero(
                      tag: 'productImage${product.id}',
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (c, e, s) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            
            // Details Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '\₦${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFFE7F2D), // Orange
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // --- SMART CART BUTTON AREA ---
                  SizedBox(
                    width: double.infinity,
                    height: 35,
                    child: Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        // Check if item is in cart
                        final isInCart = cart.items.containsKey(product.id);
                        final quantity = isInCart ? cart.items[product.id]!.quantity : 0;

                        if (!isInCart) {
                          // STATE 1: Not in cart -> Show "ADD" button
                          return ElevatedButton(
                            onPressed: () {
                              cart.addItem(product);
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Added to cart!'),
                                  duration: const Duration(milliseconds: 800),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFFFE7F2D),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(57, 64, 83, 1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.zero,
                              elevation: 0,
                            ),
                            child: const Text('ADD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          );
                        } else {
                          // STATE 2: In cart -> Show [- Qty +] controls
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(57, 64, 83, 1), // Dark Blue
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Decrease Button
                                Expanded(
                                  child: IconButton(
                                    onPressed: () {
                                      cart.removeSingleItem(product.id);
                                    },
                                    icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                                // Quantity Text
                                Text(
                                  '$quantity',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                // Increase Button
                                Expanded(
                                  child: IconButton(
                                    onPressed: () {
                                      cart.addItem(product);
                                    },
                                    icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}