import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:firebase_remote_config/firebase_remote_config.dart'; 
import 'package:shimmer/shimmer.dart'; 

// Model & Provider Imports
import 'package:eight_express/models/product.dart';
import 'package:eight_express/models/app_notification.dart'; 
import 'package:eight_express/models/app_user.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/providers/category_provider.dart';
import 'package:eight_express/services/remote_config_service.dart';
import 'package:eight_express/services/notification_service.dart'; 

// Screen & Widget Imports
import 'package:eight_express/screens/product_detail_screen.dart';
import 'package:eight_express/screens/product_listing_screen.dart'; 
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
  final bool isNewUser;
  const HomeScreen({super.key, this.isNewUser = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  bool _onboardingShown = false; 
  
  Color get _primaryColor => RemoteConfigService.getPrimaryColor();

  final List<Widget> _widgetOptions = <Widget>[
    Container(), // Placeholder for PaginatedHomeContent
    const CategoriesScreen(),
    const WishlistScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
      _checkVersion(); 
      _showPromoPopup();
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  // ============================================================
  // CRITICAL FIX: ONBOARDING MODAL LOGIC (WAIT FOR FIREBASE)
  // ============================================================
  void _checkOnboarding() async {
    if (_onboardingShown) return;
    
    final userProv = Provider.of<UserProvider>(context, listen: false);
    
    // 1. If it's a Guest, don't show the onboarding
    if (userProv.isGuest) return;

    // 2. If nobody is logged in to Firebase yet, don't show it
    if (FirebaseAuth.instance.currentUser == null) return;

    // 3. WAIT MECHANISM: Wait for the UserProvider to finish its async fetch
    int retryCount = 0;
    // Loop until loading is false, profile is marked as loaded, and appUser is hydrated
    while ((userProv.isLoading || !userProv.isProfileLoaded || userProv.appUser == null) && retryCount < 40) {
      await Future.delayed(const Duration(milliseconds: 400));
      retryCount++;
    }

    if (!mounted) return;

    // 4. Final check: Only show if the profile is definitely loaded and setup is incomplete
    final user = userProv.appUser;
    if (user != null && user.setupComplete == false) {
      _onboardingShown = true; 
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _showOnboardingModal();
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext modalContext, StateSetter setModalState) {
          bool isSaving = false;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 55),
                const SizedBox(height: 12),
                const Text("Delivery Setup", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Text("Please complete your profile to enable shopping.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                _buildDialogField(nameCtrl, "Full Name", Icons.person_outline),
                _buildDialogField(phoneCtrl, "Phone Number", Icons.phone_android_rounded),
                _buildDialogField(streetCtrl, "Delivery Street Address", Icons.home_outlined),
                _buildDialogField(cityCtrl, "City/Area", Icons.location_on_outlined),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor, 
                    minimumSize: const Size(double.infinity, 55), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: isSaving ? null : () async {
                    if (phoneCtrl.text.isEmpty || streetCtrl.text.isEmpty || nameCtrl.text.isEmpty || cityCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are mandatory")));
                      return;
                    }
                    setModalState(() => isSaving = true);
                    try {
                      await userProv.completeProfileSetup(
                        name: nameCtrl.text.trim(), 
                        phone: phoneCtrl.text.trim(), 
                        street: streetCtrl.text.trim(), 
                        city: cityCtrl.text.trim(), 
                        state: "Lagos"
                      );
                      if (mounted) {
                        Navigator.of(ctx).pop(); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Your profile is now active!"), 
                          behavior: SnackBarBehavior.floating, 
                          backgroundColor: Colors.green
                        ));
                      }
                    } catch (e) {
                      setModalState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  child: isSaving 
                    ? const CustomLoader(size: 25)
                    : const Text("SAVE AND CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 25),
              ]),
            ),
          );
        }
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12), 
      child: TextField(
        controller: ctrl, 
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _primaryColor, size: 20), 
          hintText: hint, 
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300))
        )
      )
    );
  }

  // --- VERSION & PROMO POPUPS ---
  Future<void> _checkVersion() async {
    final config = RemoteConfigService.forceUpdate;
    final packageInfo = await PackageInfo.fromPlatform();
    if (packageInfo.version.compareTo(config['min_version'] ?? "1.0.0") < 0) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(config['force_title'] ?? "App Update Required"),
          content: Text(config['force_message'] ?? "Please download the latest version to access new features and products."),
          actions: [
            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse(config['store_url'] ?? ""), mode: LaunchMode.externalApplication),
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
                child: CachedNetworkImage(
                  imageUrl: promo['popup_image'], 
                  fit: BoxFit.cover,
                  placeholder: (c, u) => const SizedBox(height: 200, child: Center(child: CustomLoader(size: 30))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(promo['popup_title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(promo['popup_body'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("DISMISS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // --- NAVIGATION LOGIC ---
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
          const Text("Identification Required", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text("Login to your account to save items and track deliveries.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
              child: const Text("PROCEED TO LOGIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
            )
          ),
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
        Expanded(child: _selectedIndex == 0 
          ? PaginatedHomeContent(searchQuery: _searchQuery) 
          : _widgetOptions[_selectedIndex]),
      ]),
      bottomNavigationBar: _buildVibrantBottomNav(),
    );
  }

  // --- APP BAR & HEADER (ENHANCED SEARCH) ---
  Widget _buildGradientHeader(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final user = Provider.of<UserProvider>(context).appUser;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, _primaryColor], 
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight
        ), 
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35))
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu_open_rounded, color: Colors.white, size: 35), onPressed: () => Scaffold.of(ctx).openDrawer())),
          const Text("08Express", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          Row(children: [
            _buildNotificationBell(context),
            _buildCartIcon(cart),
          ]),
        ]),

        if (_selectedIndex == 0) ...[
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getGreeting(), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                Text(user?.name ?? "Guest User", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          RepaintBoundary(
            child: AnimatedGradientBorder(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Stack(alignment: Alignment.centerLeft, children: [
                  if (_searchController.text.isEmpty) const Padding(padding: EdgeInsets.only(left: 48.0), child: RotatingSearchHint()),
                  TextField(
                    controller: _searchController, 
                    cursorColor: _primaryColor,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, color: _primaryColor), 
                      // --- SEARCH CANCEL BUTTON ---
                      suffixIcon: _searchController.text.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: Colors.grey), 
                              onPressed: () {
                                _searchController.clear();
                                setState(() { _searchQuery = ""; });
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none, 
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      filled: false, 
                    )
                  ),
                ]),
              )
            )
          ),
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
      if (cart.itemCount > 0) 
        Positioned(
          right: 8, top: 8, 
          child: Container(
            padding: const EdgeInsets.all(4), 
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), 
            child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
          )
        ),
    ]);
  }

  Widget _buildVibrantBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(25)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex, onTap: _onItemTapped, type: BottomNavigationBarType.fixed, backgroundColor: Colors.transparent, elevation: 0,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey.shade400, showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Wishlist'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_basket_rounded), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.person_pin_rounded), label: 'Account'),
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
        Container(
          width: double.infinity, 
          padding: const EdgeInsets.fromLTRB(25, 70, 25, 40), 
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue.shade900, _primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight), 
            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(50))
          ), 
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 35, backgroundColor: Colors.white24, backgroundImage: user?.imageUrl != null ? CachedNetworkImageProvider(user!.imageUrl!) : null, child: user?.imageUrl == null ? Icon(isGuest ? Icons.account_circle : Icons.person, color: Colors.white, size: 40) : null),
            const SizedBox(height: 15),
            Text(isGuest ? "Hello, Guest" : (user?.name ?? "User"), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(isGuest ? "Log in to track orders" : (user?.email ?? ""), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
          ])
        ),
        const SizedBox(height: 20),
        _buildDrawerTile(Icons.home_rounded, "Home", Colors.orange, () { Navigator.pop(context); _onItemTapped(0); }),
        _buildDrawerTile(Icons.grid_view_rounded, "Categories", Colors.blue, () { Navigator.pop(context); _onItemTapped(1); }),
        _buildDrawerTile(Icons.favorite_rounded, "My Wishlist", Colors.red, () { Navigator.pop(context); if (isGuest) _showLoginSheet(context); else _onItemTapped(2); }),
        _buildDrawerTile(Icons.notifications_active_rounded, "Notification Center", Colors.deepPurple, () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())); }),
        _buildDrawerTile(Icons.local_shipping_rounded, "Track Orders", Colors.green, () { Navigator.pop(context); if (isGuest) _showLoginSheet(context); else Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen())); }),
        if (isGuest) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20), 
            child: InkWell(
              onTap: () { Navigator.pop(context); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen())); }, 
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12), 
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFE7F2D), Color(0xFFFFB347)]), borderRadius: BorderRadius.circular(15)), 
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login_rounded, color: Colors.white, size: 20), SizedBox(width: 10), Text("SIGN IN / UP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])
              )
            )
          ),
        ],
        const Spacer(),
        const Divider(indent: 30, endIndent: 30),
        const Padding(padding: EdgeInsets.only(bottom: 30), child: Column(children: [Text("08Express", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black54)), Text("by 08Vic Enterprises © 2025", style: TextStyle(color: Colors.grey, fontSize: 11))])),
      ]),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 25), leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14));
  }
}

// ==========================================
// PAGINATED HOME CONTENT (SEARCH & SLIDERS)
// ==========================================

class PaginatedHomeContent extends StatefulWidget {
  final String searchQuery;
  const PaginatedHomeContent({super.key, this.searchQuery = ''});

  @override
  State<PaginatedHomeContent> createState() => _PaginatedHomeContentState();
}

class _PaginatedHomeContentState extends State<PaginatedHomeContent> {
  final List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage; 
  DocumentSnapshot? _lastDocument;
  static const int _limit = 20;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void didUpdateWidget(covariant PaginatedHomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _resetAndFetch();
    }
  }

  Future<void> _handleRefresh() async {
    _resetAndFetch();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _resetAndFetch() {
    if(!mounted) return;
    setState(() {
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
      _isLoading = false;
      _errorMessage = null; 
    });
    _fetchProducts();
  }

  /// THE SEARCH & FEED STRATEGY:
  /// 1. Only show products where stock > 0.
  /// 2. Always order by createdAt descending (newest first).
  Future<void> _fetchProducts() async {
    if (_isLoading || (!_hasMore && widget.searchQuery.isEmpty)) return;
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final collection = FirebaseFirestore.instance.collection('products');

      if (widget.searchQuery.trim().isNotEmpty) {
         // --- UPDATED SEARCH LOGIC FIXED ---
         final QuerySnapshot snap = await collection.where('stock', isGreaterThan: 0).get();
         final String queryText = widget.searchQuery.toLowerCase();
         final List<Product> results = snap.docs
             .map((doc) => Product.fromFirestore(doc))
             .where((p) => p.name.toLowerCase().contains(queryText) || p.category.toLowerCase().contains(queryText))
             .toList();

         // Sort search results: Newest arrival first
         results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

         if (mounted) {
           setState(() {
             _products.clear();
             _products.addAll(results);
             _hasMore = false; 
           });
         }
      } else {
        // --- GLOBAL FEED: Strictly In-Stock AND Newest First ---
        Query query = collection
            .where('stock', isGreaterThan: 0)
            .orderBy('stock') 
            .orderBy('createdAt', descending: true)
            .limit(_limit);

        if (_lastDocument != null) {
          query = query.startAfterDocument(_lastDocument!);
        }

        final QuerySnapshot snapshot = await query.get();

        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
          final newProducts = snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
          
          if (mounted) {
            setState(() {
              _products.addAll(newProducts);
              if (snapshot.docs.length < _limit) _hasMore = false;
            });
          }
        } else {
          if (mounted) setState(() => _hasMore = false);
        }
      }
    } catch (e) {
      debugPrint("Firestore Error: $e");
      if (mounted) setState(() => _errorMessage = "Error loading. Pull to refresh.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ENHANCED DYNAMIC TOP CATEGORY SLIDER ---
  Widget _buildEnhancedCategorySlider() {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.categories.isEmpty) {
          return const SizedBox(height: 120, child: Center(child: CustomLoader(size: 30)));
        }
        final cats = provider.categories.where((c) => c.active).toList();
        
        return Container(
          height: 155,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            physics: const BouncingScrollPhysics(),
            itemCount: cats.length,
            itemBuilder: (ctx, i) {
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 300 + (i * 100)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductListingScreen(categoryName: cats[i].name))),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 15),
                    child: Column(
                      children: [
                        // Glassmorphism inspired Category Circle
                        Container(
                          width: 85, height: 85,
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade400, Colors.blue.shade900, Colors.purple.shade400], 
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: cats[i].imageUrl, 
                                fit: BoxFit.cover,
                                placeholder: (c, u) => const Center(child: CustomLoader(size: 15)),
                                errorWidget: (c, u, e) => const Icon(Icons.category_outlined, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          cats[i].name, 
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900), 
                          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // NOTE: HeroMode disabled in row items to prevent "duplicate tag" crash
  Widget _buildProductWithEnhancedCheck(Product product, {bool isHeroEnabled = true}) {
    bool isLowStock = product.stock > 0 && product.stock <= 10;
    Widget content = HeroMode(
      enabled: isHeroEnabled,
      child: ProductGridItem(key: ValueKey(product.id), product: product),
    );

    if (isLowStock) {
      return Stack(
        children: [
          content,
          Positioned(
            top: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
              child: Text("Only ${product.stock} left!", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }
    return content;
  }

  Widget _buildCategorySection(BuildContext context, String title, Color themeColor) {
    // CATEGORY QUERY: Strictly In Stock AND Newest First
    Query q = FirebaseFirestore.instance.collection('products')
        .where('category', isEqualTo: title)
        .where('stock', isGreaterThan: 0)
        .orderBy('stock')
        .orderBy('createdAt', descending: true)
        .limit(10);
        
    final primaryColor = RemoteConfigService.getPrimaryColor();

    return FutureBuilder<QuerySnapshot>(
      future: q.get(), 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return _buildSectionSkeleton(primaryColor);
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        
        var displayProducts = snapshot.data!.docs.map((d) => Product.fromFirestore(d)).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(width: 5, height: 20, decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ]),
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => ProductListingScreen(categoryName: title))),
                    child: Text("Explore All", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 275,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: displayProducts.length,
                itemBuilder: (ctx, i) => Container(
                  width: 165,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildProductWithEnhancedCheck(displayProducts[i], isHeroEnabled: false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionSkeleton(Color brandColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 25, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: 150, height: 20, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              Container(width: 60, height: 15, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        SizedBox(
          height: 275,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: 165,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: ProductSkeletonItem(brandColor: brandColor),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = RemoteConfigService.getPrimaryColor();

    if (widget.searchQuery.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _products.isEmpty && _isLoading 
        ? const Center(child: CustomLoader(size: 60))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.64, crossAxisSpacing: 15, mainAxisSpacing: 15),
            itemCount: _products.length,
            itemBuilder: (ctx, i) => _buildProductWithEnhancedCheck(_products[i]),
          ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.orange,
      child: _products.isEmpty && _isLoading 
      ? FullHomeSkeleton(brandColor: brandColor)
      : SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP MODERN CATEGORY SLIDER ---
            _buildEnhancedCategorySlider(),

            // ALL CATEGORY SECTIONS
            _buildCategorySection(context, "Food & Beverages", Colors.orange.shade800),
            _buildCategorySection(context, "Nestle", Colors.blue.shade800),
            _buildCategorySection(context, "Household & Cleaning", Colors.teal.shade700),
            _buildCategorySection(context, "Promasidor", Colors.red.shade800),
            _buildCategorySection(context, "Multipro", Colors.indigo.shade800),
            _buildCategorySection(context, "Drinks & Wines", Colors.purple.shade800),
            _buildCategorySection(context, "Children Foods", Colors.pink.shade800),
            
            const Divider(height: 40, thickness: 8, color: Color(0xFFF2F2F2)),
            
            // FEED HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                Text("Recently Added", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.grey.shade800)),
              ]),
            ),
            
            // PAGINATED GRID
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 0.64, crossAxisSpacing: 12, mainAxisSpacing: 12
                ),
                itemCount: _products.length,
                itemBuilder: (ctx, i) => _buildProductWithEnhancedCheck(_products[i]),
              ),
            ),

            if (_hasMore)
              Padding(
                padding: const EdgeInsets.all(30),
                child: _isLoading 
                  ? const Center(child: CustomLoader(size: 30))
                  : OutlinedButton(
                      onPressed: _fetchProducts,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      child: const Text("SHOW MORE PRODUCTS", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
              ),
              
             const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ADDITIONAL WIDGETS (SKELETONS & ANIMATIONS)
// ==========================================

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
      _suggestions = ["Search for Milk...", "Search for Detergents...", "Looking for Snacks?"];
    }
    _startRotation();
  }

  void _startRotation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (mounted && _suggestions.isNotEmpty) { setState(() => _currentIndex = (_currentIndex + 1) % _suggestions.length); }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: Text(
        _suggestions[_currentIndex],
        key: ValueKey(_currentIndex),
        style: const TextStyle(color: Colors.black26, fontSize: 14),
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

class FullHomeSkeleton extends StatelessWidget {
  final Color brandColor;
  const FullHomeSkeleton({super.key, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 140),
          _skeletonRow(),
          _skeletonRow(),
          const Divider(height: 40, thickness: 8, color: Color(0xFFF2F2F2)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.64, crossAxisSpacing: 12, mainAxisSpacing: 12,
              ),
              itemCount: 4,
              itemBuilder: (_, __) => ProductSkeletonItem(brandColor: brandColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonRow() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 25, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: 150, height: 20, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              Container(width: 60, height: 15, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        SizedBox(
          height: 275,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: 165,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: ProductSkeletonItem(brandColor: brandColor),
            ),
          ),
        ),
      ],
    );
  }
}

class ProductSkeletonItem extends StatelessWidget {
  final Color brandColor;
  const ProductSkeletonItem({super.key, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: brandColor.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          children: [
            Expanded(flex: 3, child: Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(15))))),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 6),
                    Container(width: 60, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 40, height: 15, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                        Container(width: 25, height: 25, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}