import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:firebase_remote_config/firebase_remote_config.dart'; 

import 'package:eight_express/models/product.dart';
import 'package:eight_express/models/app_notification.dart'; 
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/services/remote_config_service.dart';
import 'package:eight_express/services/notification_service.dart'; 

import 'package:eight_express/screens/product_detail_screen.dart';
import 'package:eight_express/screens/cart_screen.dart';
import 'package:eight_express/screens/categories_screen.dart';
import 'package:eight_express/screens/wishlist_screen.dart';
import 'package:eight_express/screens/profile_screen.dart';
import 'package:eight_express/screens/my_orders_screen.dart';
import 'package:eight_express/screens/auth_screen.dart';
import 'package:eight_express/screens/notification_screen.dart'; 
import 'package:eight_express/widgets/custom_loader.dart';
import 'package:eight_express/widgets/product_grid_item.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  Color get _primaryColor => RemoteConfigService.getPrimaryColor();

  final List<Widget> _widgetOptions = <Widget>[
    Container(), // 0: Home (Listing built in body)
    const CategoriesScreen(),
    const WishlistScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
      _checkVersion(); 
      _showPromoPopup();
    });
  }

  // --- LOGIC: ONBOARDING SHIELD ---
  void _checkOnboarding() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    
    int retry = 0;
    while (!userProv.isProfileLoaded && retry < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retry++;
    }

    if (userProv.isAuthenticated && userProv.isProfileLoaded) {
      final user = userProv.appUser;
      
      // SHIELD: Do not show modal for existing users (check phone number)
      bool isActuallyNew = (user?.setupComplete == false) && 
                           (user?.phoneNumber == null || user!.phoneNumber!.isEmpty);
      
      if (isActuallyNew) {
        _showOnboardingModal();
      }
    }
  }

  void _showOnboardingModal() {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final nameCtrl = TextEditingController(text: userProv.appUser?.name);
    final phoneCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final cityCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.celebration_rounded, color: Colors.orange, size: 50),
            const SizedBox(height: 10),
            const Text("Welcome to 08Express!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("Let's set up your delivery profile.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            const Text("💡 Note: Please remember your password for future logins!", 
                style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 25),
            _buildDialogField(nameCtrl, "Full Name", Icons.person),
            _buildDialogField(phoneCtrl, "Phone Number", Icons.phone),
            _buildDialogField(streetCtrl, "Shipping Street", Icons.home),
            _buildDialogField(cityCtrl, "City", Icons.location_city),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () async {
                if (phoneCtrl.text.isEmpty || streetCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required")));
                  return;
                }
                
                await userProv.completeProfileSetup(
                  name: nameCtrl.text, phone: phoneCtrl.text, street: streetCtrl.text, city: cityCtrl.text, state: "Lagos",
                );
                
                if (mounted) {
                   Navigator.pop(ctx);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Welcome onboard!"), behavior: SnackBarBehavior.floating));
                }
              },
              child: const Text("FINISH SETUP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String hint, IconData icon) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, decoration: InputDecoration(prefixIcon: Icon(icon, color: _primaryColor), hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))));
  }

  Future<void> _checkVersion() async {
    final config = RemoteConfigService.forceUpdate;
    final packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;
    String minVersion = config['min_version'] ?? "1.0.0";

    if (currentVersion.compareTo(minVersion) < 0) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(config['force_title'] ?? "Update Required"),
          content: Text(config['force_message'] ?? "Please update the app to continue."),
          actions: [
            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse(config['store_url'] ?? "")),
              child: const Text("UPDATE NOW"),
            )
          ],
        ),
      );
    }
  }

  void _showPromoPopup() {
    final promo = RemoteConfigService.promo;
    if (promo['show_popup'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                child: CachedNetworkImage(imageUrl: promo['popup_image'], fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(promo['popup_title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(promo['popup_body'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("GET OFFER", style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
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
        padding: const EdgeInsets.all(30), height: 350,
        child: Column(children: [
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 30),
          Icon(Icons.lock_person_rounded, size: 60, color: _primaryColor),
          const SizedBox(height: 20),
          const Text("Login Required", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text("Sign in to manage your wishlist and tracking.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const Spacer(),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("GO TO LOGIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isProfileScreen = _selectedIndex == 4;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: _buildCustomDrawer(context),
      body: Column(children: [
        if (!isProfileScreen) _buildGradientHeader(context),
        Expanded(child: _selectedIndex == 0 ? ProductListingScreen(searchQuery: _searchQuery) : _widgetOptions[_selectedIndex]),
      ]),
      bottomNavigationBar: _buildVibrantBottomNav(),
    );
  }

  Widget _buildGradientHeader(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade900, _primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.short_text_rounded, color: Colors.white, size: 35), onPressed: () => Scaffold.of(ctx).openDrawer())),
          const Text("08Express", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Row(children: [
            _buildNotificationBell(context),
            _buildCartIcon(cart),
          ]),
        ]),
        if (_selectedIndex == 0) ...[
          const SizedBox(height: 20),
          RepaintBoundary(child: AnimatedGradientBorder(child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Stack(alignment: Alignment.centerLeft, children: [
              if (_searchController.text.isEmpty) const Padding(padding: EdgeInsets.only(left: 48.0), child: RotatingSearchHint()),
              TextField(
                controller: _searchController, 
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: _primaryColor), 
                  border: InputBorder.none, 
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  filled: false, // Ensures rotating hint is visible behind
                )
              ),
            ]),
          ))),
        ]
      ]),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().getNotifications(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 12, top: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCartIcon(CartProvider cart) {
    return Stack(children: [
      IconButton(icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28), onPressed: () => _onItemTapped(3)),
      if (cart.itemCount > 0) Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
    ]);
  }

  Widget _buildVibrantBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(25)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex, onTap: _onItemTapped, type: BottomNavigationBarType.fixed, backgroundColor: Colors.transparent, elevation: 0,
        selectedItemColor: _selectedIndex == 0 ? Colors.orange : (_selectedIndex == 1 ? Colors.blue : (_selectedIndex == 2 ? Colors.red : (_selectedIndex == 3 ? Colors.green : Colors.indigo))),
        unselectedItemColor: Colors.grey.shade400, showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Wishlist'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_basket_rounded), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.face_rounded), label: 'Account'),
        ],
      ),
    );
  }

  Widget _buildCustomDrawer(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isGuest = userProvider.isGuest;
    final user = userProvider.appUser;
    return Drawer(
      backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(30))),
      child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(25, 70, 25, 40), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade900, _primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.only(bottomRight: Radius.circular(50))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 35, backgroundColor: Colors.white24, backgroundImage: user?.imageUrl != null ? NetworkImage(user!.imageUrl!) : null, child: user?.imageUrl == null ? Icon(isGuest ? Icons.account_circle : Icons.person, color: Colors.white, size: 40) : null),
          const SizedBox(height: 15),
          // RESTORED: NAME AND EMAIL Display
          Text(isGuest ? "Hello, Guest" : (user?.name ?? "User"), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(isGuest ? "Sign in to your account" : (user?.email ?? ""), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
        ])),
        const SizedBox(height: 20),
        _buildDrawerTile(Icons.home_rounded, "Home", Colors.orange, () { Navigator.pop(context); _onItemTapped(0); }),
        _buildDrawerTile(Icons.category_rounded, "Categories", Colors.blue, () { Navigator.pop(context); _onItemTapped(1); }),
        _buildDrawerTile(Icons.favorite_rounded, "Wishlist", Colors.red, () { Navigator.pop(context); if (isGuest) _showLoginSheet(context); else _onItemTapped(2); }),
        _buildDrawerTile(Icons.notifications_active_rounded, "Notifications", Colors.deepPurple, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())); }),
        _buildDrawerTile(Icons.local_mall_rounded, "My Orders", Colors.green, () { Navigator.pop(context); if (isGuest) _showLoginSheet(context); else Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen())); }),
        if (isGuest) ...[
          const SizedBox(height: 20),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: InkWell(onTap: () { Navigator.pop(context); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen())); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)]), borderRadius: BorderRadius.circular(15)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login_rounded, color: Colors.white, size: 20), SizedBox(width: 10), Text("LOGIN / SIGN UP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])))),
        ],
        const Spacer(),
        const Divider(indent: 30, endIndent: 30),
        const Padding(padding: EdgeInsets.only(bottom: 30), child: Column(children: [Text("08Express", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black54)), Text("by 08Vic Enterprises 2026", style: TextStyle(color: Colors.grey, fontSize: 11))])),
      ]),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 25), leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18));
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
        return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.64, crossAxisSpacing: 15, mainAxisSpacing: 15), itemCount: products.length, itemBuilder: (context, index) => ProductGridItem(key: ValueKey(products[index].id), product: products[index]));
      },
    );
  }
}

class RotatingSearchHint extends StatefulWidget {
  const RotatingSearchHint({super.key});
  @override
  State<RotatingSearchHint> createState() => _RotatingSearchHintState();
}

class _RotatingSearchHintState extends State<RotatingSearchHint> {
  List<String> _suggestions = [];
  int _currentIndex = 0; 
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initHints();
  }

  void _initHints() {
    _suggestions = List<String>.from(RemoteConfigService.searchHints);
    if (_suggestions.isEmpty) {
      Future.delayed(const Duration(milliseconds: 1500), () { if (mounted) _initHints(); });
    } else { _startRotation(); }
  }

  void _startRotation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (mounted && _suggestions.isNotEmpty) { setState(() => _currentIndex = (_currentIndex + 1) % _suggestions.length); }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_suggestions.isEmpty) { _suggestions = List<String>.from(RemoteConfigService.searchHints); if (_suggestions.isNotEmpty) _startRotation(); }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        _suggestions.isNotEmpty ? _suggestions[_currentIndex] : "Search Products...",
        key: ValueKey(_suggestions.isNotEmpty ? _suggestions[_currentIndex] : "empty"),
        style: const TextStyle(color: Colors.black38, fontSize: 14),
      ),
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
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return AnimatedBuilder(animation: _c, builder: (_, __) => Container(padding: const EdgeInsets.all(1.5), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), gradient: SweepGradient(colors: const [Color(0xFFFE7F2D), Colors.blue, Colors.purple, Color(0xFFFE7F2D)], transform: GradientRotation(_c.value * 2 * pi))), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: widget.child))); }
}