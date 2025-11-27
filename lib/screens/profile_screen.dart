import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/user_addresses_screen.dart'; // Import the new address screen
import 'package:eight_express/screens/my_orders_screen.dart'; // Import the new orders screen

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _nameController.text = userProvider.appUser?.name ?? '';
    _phoneNumberController.text = userProvider.appUser?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileChanges() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.updateAppUserProfile(
      name: _nameController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
    );
    setState(() {
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final appUser = userProvider.appUser;

    if (appUser == null) {
      return const Center(child: Text('Please log in to view your profile.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfileChanges();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: appUser.imageUrl != null && appUser.imageUrl!.isNotEmpty
                        ? NetworkImage(appUser.imageUrl!) as ImageProvider
                        : const AssetImage('assets/default_profile.png'), // Add a default image in assets
                    child: appUser.imageUrl == null || appUser.imageUrl!.isEmpty
                        ? const Icon(Icons.person, size: 60, color: Colors.white70)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.deepOrange, size: 30),
                      onPressed: () {
                        // TODO: Implement image picking logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Upload profile picture (coming soon!)')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileSection(
              context,
              title: 'Personal Information',
              children: [
                _buildProfileField(
                  label: 'Name',
                  value: appUser.name,
                  controller: _nameController,
                  isEditable: _isEditing,
                  keyboardType: TextInputType.name,
                ),
                _buildProfileField(
                  label: 'Email',
                  value: appUser.email,
                  isEditable: false, // Email is generally not editable directly from profile
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildProfileField(
                  label: 'Phone Number',
                  value: appUser.phoneNumber,
                  controller: _phoneNumberController,
                  isEditable: _isEditing,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildProfileSection(
              context,
              title: 'Account Settings',
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.deepOrange),
                  title: const Text('My Addresses'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => const UserAddressesScreen(),
                    ));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.deepOrange),
                  title: const Text('My Orders'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => const MyOrdersScreen(),
                    ));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock, color: Colors.deepOrange),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Implement change password functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Change password (coming soon!)')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.deepOrange),
                  title: const Text('Logout'),
                  onTap: () async {
                    await userProvider.signOut();
                    // Optionally navigate to login screen or home
                    Navigator.of(context).popUntil((route) => route.isFirst); // Go to first route
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required String? value,
    TextEditingController? controller,
    bool isEditable = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          if (isEditable && controller != null)
            TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: 'Enter $label',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            )
          else
            Text(
              value ?? 'N/A',
              style: const TextStyle(fontSize: 18),
            ),
        ],
      ),
    );
  }
}