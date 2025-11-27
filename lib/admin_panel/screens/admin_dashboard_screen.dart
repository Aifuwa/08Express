// eight_express/lib/admin_panel/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:eight_express/admin_panel/screens/product_list_screen.dart';
import 'package:eight_express/admin_panel/screens/user_management_screen.dart';
import 'package:eight_express/admin_panel/screens/notification_screen.dart';
import 'package:eight_express/admin_panel/screens/order_list_screen.dart'; // Import Order Screen
import 'package:eight_express/admin_panel/screens/admin_login_screen.dart';
import 'package:eight_express/admin_panel/services/admin_firestore_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final AdminFirestoreService _adminService = AdminFirestoreService();

  // Updated Widget Options to include Orders
  static final List<Widget> _widgetOptions = <Widget>[
    const ProductListScreen(),
    const OrderListScreen(), // Add Orders here (Index 1)
    const UserManagementScreen(), // Shifted to Index 2
    const NotificationScreen(), // Shifted to Index 3
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await _adminService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eight Express Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width > 700)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag),
                  label: Text('Products'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined), // Icon for Orders
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Orders'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outlined),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Users'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: Text('Notifications'),
                ),
              ],
            ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _widgetOptions.elementAt(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.dashboard, color: Colors.white, size: 40),
                SizedBox(height: 10),
                Text(
                  'Eight Express Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text('Products'),
            selected: _selectedIndex == 0,
            onTap: () {
              _onItemTapped(0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2), // Icon for Orders
            title: const Text('Orders'),
            selected: _selectedIndex == 1,
            onTap: () {
              _onItemTapped(1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Users'),
            selected: _selectedIndex == 2,
            onTap: () {
              _onItemTapped(2);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            selected: _selectedIndex == 3,
            onTap: () {
              _onItemTapped(3);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}