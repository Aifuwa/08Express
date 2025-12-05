import 'dart:async';
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
    Container(), // Placeholder for Home (Product Listing) - rendered dynamically in build
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Check if we are on the profile screen (Index 3)
    bool isProfileScreen = _selectedIndex == 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      drawer: _buildCustomDrawer(context),
      body: Column(
        children: [
          // 1. Custom Gradient Header (08Express)
          // CONDITION: Only show this header if we are NOT on the Profile Screen
          if (!isProfileScreen) 
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
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
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

  // --- WIDGET: Gradient Header (08Express Branding) ---
  Widget _buildGradientHeader(BuildContext context) {
    final List<IconData> icons = [Icons.shopping_bag, Icons.local_offer, Icons.card_giftcard, Icons.watch, Icons.phone_iphone];
    final Random random = Random();
    
    final bool isHome = _selectedIndex == 0;

    return Container(
      // Dynamic padding
      padding: EdgeInsets.fromLTRB(16, 50, 16, isHome ? 20 : 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade800, 
            Colors.blue.shade800.withOpacity(0.9), 
            _primaryColor 
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: Colors.blue.shade900.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Pattern
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row
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
                    "08Express",
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
                        onPressed: () => _onItemTapped(2), // Go to Cart
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
              
              // Search Bar (Only on Home)
              if (isHome) ...[
                const SizedBox(height: 20),
                AnimatedGradientBorder(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (_searchController.text.isEmpty)
                         const Padding(
                          padding: EdgeInsets.only(left: 48.0),
                          child: RotatingSearchHint(),
                        ),
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: '', 
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
                    ],
                  ),
                ),
              ],
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
    final String? safeImage = user?.imageUrl;

    return Drawer(
      child: Column(
        children: [
          Container(
            height: 220,
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      backgroundImage: safeImage != null && safeImage.isNotEmpty
                          ? NetworkImage(safeImage) 
                          : null,
                      child: safeImage == null || safeImage.isEmpty
                          ? Text(
                              displayInitial,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryColor),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    displayEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                
                // --- NEW LIST ITEM ---
                _buildDrawerItem(Icons.settings_suggest_rounded, 'Profile & Account Settings', () { 
                   Navigator.pop(context); // Close Drawer
                   _onItemTapped(3); // Switch Tab to Profile
                }),
                
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

// ... (Search Hint, Gradient Border, Product Listing classes remain same as previous) ...
class RotatingSearchHint extends StatefulWidget {
  const RotatingSearchHint({Key? key}) : super(key: key);
  @override
  State<RotatingSearchHint> createState() => _RotatingSearchHintState();
}

class _RotatingSearchHintState extends State<RotatingSearchHint> {
  final List<String> _searchSuggestions = ["Search for 'Indomie'", "Search for 'NAN'", "Search for 'Maggi'", "Search for 'PRE NAN'", "Search for 'Diapers'", "Search for 'Milk'"];
  int _currentIndex = 0;
  Timer? _timer;
  @override
  void initState() { super.initState(); _startRotation(); }
  void _startRotation() { _timer = Timer.periodic(const Duration(seconds: 3), (timer) { if (mounted) { setState(() { _currentIndex = (_currentIndex + 1) % _searchSuggestions.length; }); } }); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(anim), child: child)),
      child: Text(_searchSuggestions[_currentIndex], key: ValueKey<String>(_searchSuggestions[_currentIndex]), style: TextStyle(color: Colors.grey[400], fontSize: 16)),
    );
  }
}

class AnimatedGradientBorder extends StatefulWidget {
  final Widget child;
  const AnimatedGradientBorder({super.key, required this.child});
  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() { super.initState(); _controller = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(2.5), 
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: SweepGradient(
              colors: const [Color(0xFFFE7F2D), Colors.purpleAccent, Colors.cyanAccent, Color(0xFFFE7F2D)],
              stops: const [0.0, 0.45, 0.75, 1.0],
              transform: GradientRotation(_controller.value * 2 * pi),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
            child: widget.child,
          ),
        );
      },
    );
  }
}

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
                  childAspectRatio: 0.65, 
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

class ProductGridItem extends StatelessWidget {
  final Product product;
  const ProductGridItem({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    const Color orangeColor = Color(0xFFFE7F2D);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ProductDetailScreen(product: product)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15), 
              spreadRadius: 2, 
              blurRadius: 15, 
              offset: const Offset(0, 5)
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        errorBuilder: (c, e, s) => Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
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
                  const SizedBox(height: 6),
                  Text(
                    '\₦${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: orangeColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      Provider.of<CartProvider>(context, listen: false).addItem(product);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Added to cart!'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green,
                          duration: const Duration(milliseconds: 1000),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      height: 40,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)], 
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFE7F2D).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'ADD', 
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white,
                              letterSpacing: 0.5
                            )
                          ),
                        ],
                      ),
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