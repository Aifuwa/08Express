import 'dart:io';
import 'package:eight_express/widgets/custom_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// Import your project files
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/user_addresses_screen.dart';
import 'package:eight_express/screens/my_orders_screen.dart';
import 'package:eight_express/screens/home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  bool _isEditing = false;
  bool _isLoadingImage = false;
  final Color primaryColor = const Color(0xFFFE7F2D);

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

  // --- UTILITY METHODS ---

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.black87,
      ),
    );
  }

  // FIXED: Improved launch methods to prevent permission crashes
  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch dialer';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to open phone dialer"))
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch email app';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to open email app"))
        );
      }
    }
  }

  // --- INTERACTIVE SHEETS ---

  void _showContactUs() {
    const String supportEmail = "admin@08vicenterprises.com";
    const String supportPhone = "+2348100172239";

    _showStyledBottomSheet(
      title: "Contact Us",
      subtitle: "Our team is here to assist you",
      children: [
        _buildContactMethodCard(
          icon: Icons.email_rounded,
          color: Colors.orange,
          title: "Email Support",
          subtitle: supportEmail,
          onPrimaryTap: () => _sendEmail(supportEmail),
          onCopyTap: () => _copyToClipboard(supportEmail, "Email"),
          primaryActionIcon: Icons.send_rounded,
        ),
        const SizedBox(height: 12),
        _buildContactMethodCard(
          icon: Icons.phone_rounded,
          color: Colors.blue,
          title: "Call Hotline",
          subtitle: supportPhone,
          onPrimaryTap: () => _makeCall(supportPhone),
          onCopyTap: () => _copyToClipboard(supportPhone, "Phone number"),
          primaryActionIcon: Icons.call_rounded,
        ),
      ],
    );
  }

  void _showPrivacyPolicy() {
    _showStyledBottomSheet(
      title: "Privacy Policy",
      subtitle: "Last updated: December 2025",
      children: [
        _buildPolicyText("1. Information Collection", "We collect personal information such as your name, email, and location to provide seamless delivery services."),
        _buildPolicyText("2. Data Usage", "Your data is used to process orders, improve our app experience, and communicate updates."),
        _buildPolicyText("3. Data Protection", "We use industry-standard encryption to protect your data."),
      ],
    );
  }

  void _showTermsAndConditions() {
    _showStyledBottomSheet(
      title: "Terms & Conditions",
      subtitle: "Usage agreement for 08Express",
      children: [
        _buildPolicyText("1. Service Eligibility", "Users must be at least 18 years old to create an account and place orders."),
        _buildPolicyText("2. Delivery Terms", "Delivery times are estimates. 08Express is not liable for delays caused by traffic."),
      ],
    );
  }

  // --- DELETE ACCOUNT ---

  void _showDeleteAccountDialog() {
    final TextEditingController passwordController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Account?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("This is permanent. Enter your password to confirm:"),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Current Password", border: OutlineInputBorder()),
              ),
              if (isDeleting) const Padding(padding: EdgeInsets.only(top: 15), child: CircularProgressIndicator()),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: isDeleting ? null : () async {
                if (passwordController.text.isEmpty) return;
                setDialogState(() => isDeleting = true);
                try {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  await userProvider.deleteAccount(passwordController.text);
                  if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
                } catch (e) {
                  setDialogState(() => isDeleting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                }
              },
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- CORE LOGIC ---

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      setState(() => _isLoadingImage = true);
      try {
        await Provider.of<UserProvider>(context, listen: false).uploadProfileImage(File(image.path));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      } finally {
        if (mounted) setState(() => _isLoadingImage = false);
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    await Provider.of<UserProvider>(context, listen: false).updateAppUserProfile(
      name: _nameController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
    );
    setState(() => _isEditing = false);
  }

  void _showChangePasswordDialog() {
    final TextEditingController currentPass = TextEditingController();
    final TextEditingController newPass = TextEditingController();
    final GlobalKey<FormState> key = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Change Password"),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: currentPass, obscureText: true, decoration: const InputDecoration(labelText: "Current Password"), validator: (v) => v!.isEmpty ? "Required" : null),
              TextFormField(controller: newPass, obscureText: true, decoration: const InputDecoration(labelText: "New Password"), validator: (v) => v!.length < 6 ? "Min 6 chars" : null),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (key.currentState!.validate()) {
                try {
                  await Provider.of<UserProvider>(context, listen: false).changePassword(currentPass.text, newPass.text);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Success"), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  void _showStyledBottomSheet({required String title, required String subtitle, required List<Widget> children}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 25),
            ...children,
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyText(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(color: Colors.grey[700], height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildContactMethodCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onPrimaryTap, required VoidCallback onCopyTap, required IconData primaryActionIcon}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(subtitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))])),
          IconButton(onPressed: onPrimaryTap, icon: Icon(primaryActionIcon, color: color)),
          IconButton(onPressed: onCopyTap, icon: const Icon(Icons.copy_rounded, color: Colors.grey, size: 20)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final appUser = userProvider.appUser;
    if (appUser == null) return const Center(child: Text('Please log in.'));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 25),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue.shade800, primaryColor]),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => _isEditing ? _saveProfileChanges() : setState(() => _isEditing = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(_isEditing ? 1 : 0.2), borderRadius: BorderRadius.circular(20)),
                            child: Text(_isEditing ? 'Save' : 'Edit', style: TextStyle(color: _isEditing ? primaryColor : Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAvatar(appUser.imageUrl),
                  const SizedBox(height: 10),
                  if (!_isEditing) ...[
                    Text(appUser.name ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(appUser.email ?? "", style: TextStyle(color: Colors.white.withOpacity(0.8))),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileSection(),
            const SizedBox(height: 30),
            _buildSectionLabel("Account Settings"),
            _buildCard([
              _buildTile(Icons.location_on, Colors.blue, "My Addresses", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAddressesScreen()))),
              _buildDivider(),
              _buildTile(Icons.shopping_bag, primaryColor, "My Orders", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen()))),
              _buildDivider(),
              _buildTile(Icons.lock, Colors.purple, "Change Password", _showChangePasswordDialog),
              _buildDivider(),
              _buildTile(Icons.delete_forever, Colors.red, "Delete Account", _showDeleteAccountDialog),
            ]),
            const SizedBox(height: 30),
            _buildSectionLabel("Help & Support"),
            _buildCard([
              _buildTile(Icons.privacy_tip, Colors.teal, "Privacy Policy", _showPrivacyPolicy),
              _buildDivider(),
              _buildTile(Icons.description, Colors.indigo, "Terms & Conditions", _showTermsAndConditions),
              _buildDivider(),
              _buildTile(Icons.headset_mic, Colors.pink, "Contact Us", _showContactUs),
            ]),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => userProvider.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text("Log Out"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.all(15), side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url) {
    return GestureDetector(
      onTap: _isEditing ? () => _showImageSourceActionSheet(context) : null,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
            child: _isLoadingImage ? const CustomLoader(size: 70) : (url == null || url.isEmpty ? const Icon(Icons.person, size: 50) : null),
          ),
          if (_isEditing) Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 15, backgroundColor: primaryColor, child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
        ],
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { Navigator.pop(ctx); _pickAndUploadImage(ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () { Navigator.pop(ctx); _pickAndUploadImage(ImageSource.gallery); }),
    ])));
  }

  Widget _buildProfileSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: _isEditing 
        ? Column(children: [
            _buildField(_nameController, "Name", Icons.person),
            const SizedBox(height: 15),
            _buildField(_phoneNumberController, "Phone", Icons.phone, TextInputType.phone),
          ])
        : Row(children: [
            const Icon(Icons.phone, color: Colors.green),
            const SizedBox(width: 15),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Phone Number", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(_phoneNumberController.text.isEmpty ? "Not set" : _phoneNumberController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
            ])
          ]),
    );
  }

  Widget _buildField(TextEditingController c, String l, IconData i, [TextInputType t = TextInputType.text]) {
    return TextField(controller: c, keyboardType: t, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))));
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8), child: Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))));

  Widget _buildCard(List<Widget> children) => Container(margin: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]), child: Column(children: children));

  Widget _buildTile(IconData i, Color c, String t, VoidCallback onTap) => ListTile(onTap: onTap, leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(i, color: c, size: 20)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: const Icon(Icons.arrow_forward_ios, size: 14));

  Widget _buildDivider() => Divider(height: 1, color: Colors.grey.shade100, indent: 60);
}