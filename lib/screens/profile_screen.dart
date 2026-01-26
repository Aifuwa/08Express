// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:eight_express/widgets/custom_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/user_addresses_screen.dart';
import 'package:eight_express/screens/my_orders_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/screens/auth_screen.dart';
import 'package:eight_express/screens/support_screen.dart'; 
import 'package:eight_express/constants/legal_texts.dart';
import 'package:eight_express/services/remote_config_service.dart';

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
  
  Color get primaryColor => RemoteConfigService.getPrimaryColor();

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _nameController.text = userProvider.appUser?.name ?? '';
    _phoneNumberController.text = userProvider.appUser?.phoneNumber ?? '';
  }

  // --- 1. LOGOUT CONFIRMATION DIALOG ---
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 10),
            Text("Log Out"),
          ],
        ),
        content: const Text("Are you sure you want to leave? Your cart items will be saved."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Stay")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<UserProvider>(context, listen: false).signOut();
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 2. DELETE ACCOUNT DIALOG ---
  void _showDeleteAccountDialog() {
    final TextEditingController passwordController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 80),
              const SizedBox(height: 20),
              const Text(
                "PERMANENT DELETION",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 15),
              const Text(
                "Warning: This action is irreversible. All your history will be erased forever.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 15),
              if (!isDeleting) ...[
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Enter Password to Confirm",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ] else ...[
                const CustomLoader(size: 50),
                const SizedBox(height: 15),
                const Text(
                  "Processing deletion...",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
          actions: [
            if (!isDeleting) ...[
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (passwordController.text.isEmpty) return;
                  setDialogState(() => isDeleting = true);
                  try {
                    await Provider.of<UserProvider>(context, listen: false).deleteAccount(passwordController.text);
                    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
                  } catch (e) {
                    setDialogState(() => isDeleting = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Incorrect Password"), backgroundColor: Colors.red));
                  }
                },
                child: const Text("Delete Forever", style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 3. CHANGE PASSWORD DIALOG ---
  void _showChangePasswordDialog() {
    final TextEditingController currentPass = TextEditingController();
    final TextEditingController newPass = TextEditingController();
    final TextEditingController confirmNewPass = TextEditingController();
    final GlobalKey<FormState> key = GlobalKey<FormState>();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text("Update Password"),
          content: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Current Password", prefixIcon: Icon(Icons.lock_open)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: newPass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "New Password", prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: confirmNewPass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Confirm New Password", prefixIcon: Icon(Icons.verified_user_outlined)),
                    validator: (v) => v != newPass.text ? "Passwords do not match" : null,
                  ),
                  if (isProcessing) const Padding(padding: EdgeInsets.only(top: 15), child: CustomLoader(size: 40)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: isProcessing ? null : () async {
                if (key.currentState!.validate()) {
                  setDialogState(() => isProcessing = true);
                  try {
                    await Provider.of<UserProvider>(context, listen: false).changePassword(currentPass.text, newPass.text);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password Updated"), backgroundColor: Colors.green));
                  } catch (e) {
                    setDialogState(() => isProcessing = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Check current password"), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text("Update", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // --- 4. LEGAL TEXT HELPERS ---
  void _showPrivacyPolicy() => _showLegalBottomSheet("Privacy Policy", LegalTexts.privacyPolicy);
  void _showTermsAndConditions() => _showLegalBottomSheet("Terms & Conditions", LegalTexts.termsAndConditions);
  void _showRefundPolicy() => _showLegalBottomSheet("Refund & Return Policy", LegalTexts.refundPolicy);

  void _showLegalBottomSheet(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            Expanded(child: ListView(physics: const BouncingScrollPhysics(), children: _buildFormattedLegalText(content))),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormattedLegalText(String text) {
    List<Widget> widgets = [];
    List<String> lines = text.split('\n');
    for (var line in lines) {
      bool isHeader = RegExp(r'^(\d+\.|[A-Z\s]+:)').hasMatch(line.trim());
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(line, style: TextStyle(fontSize: isHeader ? 17 : 14, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, color: isHeader ? primaryColor : Colors.black87, height: 1.5)),
      ));
    }
    return widgets;
  }

  // --- 5. CORE BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final appUser = userProvider.appUser;

    if (appUser == null) {
      return Scaffold(backgroundColor: Colors.white, body: _buildLoggedOutState());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 25),
              width: double.infinity,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade800, primaryColor]), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => _isEditing ? _saveProfileChanges() : setState(() => _isEditing = true),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(_isEditing ? 1 : 0.2), borderRadius: BorderRadius.circular(20)), child: Text(_isEditing ? 'Save' : 'Edit', style: TextStyle(color: _isEditing ? primaryColor : Colors.white, fontWeight: FontWeight.bold))),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                _buildAvatar(appUser.imageUrl),
                const SizedBox(height: 10),
                if (!_isEditing) ...[
                  Text(appUser.name ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(appUser.email ?? "", style: TextStyle(color: Colors.white.withOpacity(0.9))),
                ]
              ]),
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
              _buildTile(Icons.support_agent_rounded, Colors.orange, "Contact Support Hub", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
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
              _buildTile(Icons.assignment_return, Colors.amber.shade800, "Refund & Return Policy", _showRefundPolicy),
              _buildDivider(),
              _buildTile(Icons.headset_mic, Colors.pink, "Contact Us", _showContactUs),
            ]),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutDialog,
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

  Widget _buildLoggedOutState() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(30),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.person_outline_rounded, size: 80, color: primaryColor)),
        const SizedBox(height: 25),
        const Text("Join the Family", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text("Sign in to track orders, save addresses, and enjoy a personalized shopping experience.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5)),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen())), style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("LOGIN / SIGN UP", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))),
      ]),
    );
  }

  Widget _buildAvatar(String? url) {
    return GestureDetector(
      onTap: _isEditing ? () => _showImageSourceActionSheet(context) : null,
      child: Stack(children: [
        CircleAvatar(radius: 50, backgroundColor: Colors.white, backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null, child: _isLoadingImage ? const CustomLoader(size: 70) : (url == null || url.isEmpty ? const Icon(Icons.person, size: 50) : null)),
        if (_isEditing) Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 15, backgroundColor: primaryColor, child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
      ]),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { Navigator.pop(ctx); _pickAndUploadImage(ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () { Navigator.pop(ctx); _pickAndUploadImage(ImageSource.gallery); }),
    ])));
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      setState(() => _isLoadingImage = true);
      try {
        await Provider.of<UserProvider>(context, listen: false).uploadProfileImage(File(image.path));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      } finally {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    await Provider.of<UserProvider>(context, listen: false).updateAppUserProfile(name: _nameController.text.trim(), phoneNumber: _phoneNumberController.text.trim());
    setState(() => _isEditing = false);
  }

  void _showContactUs() {
    final support = RemoteConfigService.support;
    final String supportEmail = support['email'] ?? "admin@08vicenterprises.com";
    final String supportPhone = support['phone'] ?? "+2348100172239";
    final String supportWhatsapp = support['whatsapp'] ?? supportPhone;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 20),
        const Text("Contact Us", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Text("Our team is here to assist you", style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 25),
        _buildContactMethodCard(icon: Icons.email_rounded, color: Colors.orange, title: "Email Support", subtitle: supportEmail, onPrimaryTap: () => launchUrl(Uri.parse("mailto:$supportEmail")), onCopyTap: () => _copyToClipboard(supportEmail, "Email"), primaryActionIcon: Icons.send_rounded),
        const SizedBox(height: 12),
        _buildContactMethodCard(icon: Icons.phone_rounded, color: Colors.blue, title: "Call Hotline", subtitle: supportPhone, onPrimaryTap: () => launchUrl(Uri.parse("tel:$supportPhone")), onCopyTap: () => _copyToClipboard(supportPhone, "Phone number"), primaryActionIcon: Icons.call_rounded),
        const SizedBox(height: 20),
      ]),
    ));
  }

  Widget _buildContactMethodCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onPrimaryTap, required VoidCallback onCopyTap, required IconData primaryActionIcon}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(subtitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))])),
        IconButton(onPressed: onPrimaryTap, icon: Icon(primaryActionIcon, color: color)),
        IconButton(onPressed: onCopyTap, icon: const Icon(Icons.copy_rounded, color: Colors.grey, size: 20)),
      ]),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: _isEditing ? Column(children: [_buildField(_nameController, "Name", Icons.person), const SizedBox(height: 15), _buildField(_phoneNumberController, "Phone", Icons.phone, TextInputType.phone)])
      : Row(children: [const Icon(Icons.phone, color: Colors.green), const SizedBox(width: 15), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Phone Number", style: TextStyle(color: Colors.grey, fontSize: 12)), Text(_phoneNumberController.text.isEmpty ? "Not set" : _phoneNumberController.text, style: const TextStyle(fontWeight: FontWeight.bold))])]),
    );
  }

  Widget _buildField(TextEditingController c, String l, IconData i, [TextInputType t = TextInputType.text]) => TextField(controller: c, keyboardType: t, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))));
  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8), child: Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))));
  Widget _buildCard(List<Widget> children) => Container(margin: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]), child: Column(children: children));
  Widget _buildTile(IconData i, Color c, String t, VoidCallback onTap) => ListTile(onTap: onTap, leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(i, color: c, size: 20)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: const Icon(Icons.arrow_forward_ios, size: 14));
  Widget _buildDivider() => Divider(height: 1, color: Colors.grey.shade100, indent: 60);
  void _copyToClipboard(String text, String label) { Clipboard.setData(ClipboardData(text: text)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied to clipboard!'), behavior: SnackBarBehavior.floating)); }
}