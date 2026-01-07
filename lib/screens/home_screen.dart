import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import project models and providers
import 'package:eight_express/models/product.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/wishlist_provider.dart';
import 'package:eight_express/providers/user_provider.dart';

// Import screens
import 'package:eight_express/screens/product_detail_screen.dart';
import 'package:eight_express/screens/cart_screen.dart';
import 'package:eight_express/screens/categories_screen.dart';
import 'package:eight_express/screens/wishlist_screen.dart';
import 'package:eight_express/screens/profile_screen.dart';
import 'package:eight_express/screens/my_orders_screen.dart';
import 'package:eight_express/screens/auth_screen.dart';

// Import signature loader
import 'package:eight_express/widgets/custom_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Color _primaryColor = const Color(0xFFFE7F2D);

  final List<Widget> _widgetOptions = <Widget>[
    Container(), // 0: Home (Listing handled in build)
    const CategoriesScreen(), // 1
    const WishlistScreen(), // 2
    const CartScreen(), // 3
    const ProfileScreen(), // 4
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Gatekeeping: Blocks Wishlist (2), Cart (3), and Profile (4) for guests
    if (index > 1 && userProvider.isGuest) {
      _showLoginSheet(context);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _showLoginSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(30),
        height: 350,
        child: Column(
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            Icon(Icons.lock_person_rounded, size: 60, color: _primaryColor),
            const SizedBox(height: 20),
            const Text("Login Required", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Sign in to manage your wishlist, cart and tracking.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("GO TO LOGIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide header only on Profile Screen (Index 4)
    bool isProfileScreen = _selectedIndex == 4;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: _buildCustomDrawer(context),
      body: Column(
        children: [
          if (!isProfileScreen) _buildGradientHeader(context),
          Expanded(
            child: _selectedIndex == 0
                ? ProductListingScreen(searchQuery: _searchQuery)
                : _widgetOptions.elementAt(_selectedIndex),
          ),
        ],
      ),
      bottomNavigationBar: _buildVibrantBottomNav(),
    );
  }

  Widget _buildVibrantBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Wishlist'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_basket_rounded), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.face_rounded), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        // Colorful Icons
        selectedItemColor: _selectedIndex == 0 
            ? Colors.orange 
            : (_selectedIndex == 1 
                ? Colors.blue 
                : (_selectedIndex == 2 
                    ? Colors.red 
                    : (_selectedIndex == 3 ? Colors.green : Colors.indigo))),
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildGradientHeader(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, _primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.short_text_rounded, color: Colors.white, size: 35), onPressed: () => Scaffold.of(ctx).openDrawer())),
              const Text("08Express", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
              _buildCartIcon(cart),
            ],
          ),
          if (_selectedIndex == 0) ...[
            const SizedBox(height: 20),
            RepaintBoundary(
              child: AnimatedGradientBorder(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (_searchController.text.isEmpty)
                      const Padding(padding: EdgeInsets.only(left: 48.0), child: RotatingSearchHint()),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, color: _primaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCartIcon(CartProvider cart) {
    return Stack(
      children: [
        IconButton(icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28), onPressed: () => _onItemTapped(3)),
        if (cart.itemCount > 0)
          Positioned(
            right: 8, top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          )
      ],
    );
  }

  Widget _buildCustomDrawer(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isGuest = userProvider.isGuest;
    final user = userProvider.appUser;

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(30))),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(25, 70, 25, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade900, _primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.only(bottomRight: Radius.circular(50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white24,
                  backgroundImage: user?.imageUrl != null ? NetworkImage(user!.imageUrl!) : null,
                  child: user?.imageUrl == null ? Icon(isGuest ? Icons.account_circle : Icons.person, color: Colors.white, size: 40) : null,
                ),
                const SizedBox(height: 15),
                Text(isGuest ? "Hello, Guest" : (user?.name ?? "User"), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(isGuest ? "Sign in to your account" : (user?.email ?? ""), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildDrawerTile(Icons.home_rounded, "Home", Colors.orange, () { Navigator.pop(context); _onItemTapped(0); }),
          _buildDrawerTile(Icons.category_rounded, "Categories", Colors.blue, () { Navigator.pop(context); _onItemTapped(1); }),
          _buildDrawerTile(Icons.favorite_rounded, "Wishlist", Colors.red, () { 
            Navigator.pop(context);
            if (isGuest) _showLoginSheet(context); else _onItemTapped(2);
          }),
          _buildDrawerTile(Icons.local_mall_rounded, "My Orders", Colors.green, () { 
            Navigator.pop(context);
            if (isGuest) _showLoginSheet(context); else Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
          }),

          // --- LOGIN BUTTON FOR GUESTS ---
          if (isGuest) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text("LOGIN / SIGN UP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const Spacer(),
          const Divider(indent: 30, endIndent: 30),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                const Text("08Express", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black54, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text("by 08Vic Enterprises 2026", style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CustomLoader(size: 70));
        if (!snapshot.hasData) return const Center(child: Text("No products found"));
        
        var products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();
        if (searchQuery.isNotEmpty) {
          products = products.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          cacheExtent: 500,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.64, crossAxisSpacing: 15, mainAxisSpacing: 15),
          itemCount: products.length,
          itemBuilder: (context, index) => ProductGridItem(key: ValueKey(products[index].id), product: products[index]),
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
    final wishlist = Provider.of<WishlistProvider>(context);
    final isFav = wishlist.isFavorite(product.id);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      memCacheWidth: 400,
                      placeholder: (context, url) => const Center(child: CustomLoader(size: 30)),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: () => wishlist.toggleWishlist(product),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                        child: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? Colors.red : Colors.grey, size: 18),
                      ),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text("₦${product.price.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFFFE7F2D), fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 10),
                  
                  // --- PREMIUM ADD BUTTON (TEXT + ICON) ---
                  InkWell(
                    onTap: () {
                      Provider.of<CartProvider>(context, listen: false).addItem(product);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to cart!"), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: const Color(0xFFFE7F2D).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text("ADD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class RotatingSearchHint extends StatefulWidget {
  const RotatingSearchHint({super.key});
  @override
  State<RotatingSearchHint> createState() => _RotatingSearchHintState();
}
class _RotatingSearchHintState extends State<RotatingSearchHint> {
  final List<String> _suggestions = ["Search 'Indomie'", "Search 'NAN'", "Search 'Milk'", "Search 'Diapers'"];
  int _currentIndex = 0;
  Timer? _timer;
  @override
  void initState() { super.initState(); _timer = Timer.periodic(const Duration(seconds: 3), (t) { if(mounted) setState(() => _currentIndex = (_currentIndex + 1) % _suggestions.length); }); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(duration: const Duration(milliseconds: 500), child: Text(_suggestions[_currentIndex], key: ValueKey(_suggestions[_currentIndex]), style: TextStyle(color: Colors.grey[400], fontSize: 15)));
  }
}

class AnimatedGradientBorder extends StatefulWidget {
  final Widget child;
  const AnimatedGradientBorder({super.key, required this.child});
  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}
class _AnimatedGradientBorderState extends State<AnimatedGradientBorder> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (_, __) => Container(padding: const EdgeInsets.all(1.5), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), gradient: SweepGradient(colors: const [Color(0xFFFE7F2D), Colors.blue, Colors.purple, Color(0xFFFE7F2D)], transform: GradientRotation(_c.value * 2 * pi))), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: widget.child)));
  }
}