// lib/screens/checkout_screen.dart
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/user_addresses_screen.dart';
import 'package:eight_express/models/app_user.dart';
import 'package:eight_express/widgets/custom_loader.dart';
import 'package:eight_express/services/remote_config_service.dart';

final _logger = Logger(
  printer: PrettyPrinter(methodCount: 0, colors: true, printEmojis: true),
);

enum DeliveryMethod { pickup, delivery }

class CheckoutScreen extends StatefulWidget {
  final double totalAmount;
  const CheckoutScreen({super.key, required this.totalAmount});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with TickerProviderStateMixin {
  File? _pickedReceiptImage;
  bool _isUploading = false;
  String? _uploadMessage;

  DeliveryMethod? _selectedDeliveryMethod;
  UserAddress? _selectedUserAddress;
  Map<String, dynamic>? _selectedLocation;
  
  // Dynamic Locations from Remote Config
  List<Map<String, dynamic>> _remoteLocations = [];

  @override
  void initState() {
    super.initState();
    _initRemoteConfigData();
    _loadInitialAddress();
  }

  // --- STEP 1: INITIALIZE DYNAMIC DATA ---
  void _initRemoteConfigData() {
    try {
      final String jsonStr = RemoteConfigService.getRegionsJson();
      if (jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        setState(() {
          _remoteLocations = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      _logger.e("Error parsing Remote Config: $e");
      // Safety Fallback
      _remoteLocations = [
        {'name': 'Ring Road / Oba Palace Area', 'fee': 3000.0},
        {'name': 'GRA / Airport Road', 'fee': 3000.0},
      ];
    }
  }

  void _loadInitialAddress() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProv = Provider.of<UserProvider>(context, listen: false);
      final addresses = userProv.appUser?.addresses ?? [];
      if (addresses.isNotEmpty) {
        setState(() {
          _selectedUserAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        });
      }
    });
  }

  double _getDeliveryFee() => _selectedDeliveryMethod == DeliveryMethod.delivery ? (_selectedLocation?['fee'] ?? 0.0) : 0.0;

  String _getDeliveryEstimate() {
    final DateFormat formatter = DateFormat('MMM d');
    return "${formatter.format(DateTime.now().add(const Duration(days: 1)))} - ${formatter.format(DateTime.now().add(const Duration(days: 3)))}";
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text('$label copied to clipboard!')]),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.blueAccent.shade700,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ));
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (mounted && pickedFile != null) {
      setState(() {
        _pickedReceiptImage = File(pickedFile.path);
        _uploadMessage = null;
      });
    }
  }

  // --- STEP 2: PROFESSIONAL ORDER LOGIC (READ-BEFORE-WRITE) ---
  Future<void> _placeOrder() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) return;
    
    // Validations
    if (_selectedDeliveryMethod == null) return _showError('Please select a Logistics method');
    if (_selectedDeliveryMethod == DeliveryMethod.delivery) {
      if (_selectedLocation == null) return _showError('Please choose your region');
      if (_selectedUserAddress == null) return _showError('Shipping address is required');
    }
    if (_pickedReceiptImage == null) return _showError('Payment proof (screenshot) is mandatory');

    setState(() => _isUploading = true);

    try {
      // 1. Upload to Storage
      final String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putFile(_pickedReceiptImage!);
      final String receiptUrl = await storageRef.getDownloadURL();

      // 2. Transaction (Atomic Stock Management)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        List<Map<String, dynamic>> stockUpdates = [];

        // PHASE 1: ALL READS
        for (var i in cartProvider.items.values) {
          DocumentReference pRef = FirebaseFirestore.instance.collection('products').doc(i.productId);
          DocumentSnapshot pSnap = await transaction.get(pRef);
          if (!pSnap.exists) throw Exception("Product '${i.name}' no longer exists.");
          
          int currentStock = pSnap.get('stock') ?? 0;
          if (currentStock < i.quantity) throw Exception("Only $currentStock items left for ${i.name}");

          stockUpdates.add({'ref': pRef, 'newStock': currentStock - i.quantity});
        }

        // PHASE 2: ALL WRITES
        for (var u in stockUpdates) {
          transaction.update(u['ref'] as DocumentReference, {'stock': u['newStock']});
        }

        final double fee = _getDeliveryFee();
        final String methodStr = _selectedDeliveryMethod.toString().split('.').last;

        transaction.set(FirebaseFirestore.instance.collection('orders').doc(), {
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'status': 'pending_receipt_verification',
          'orderDate': Timestamp.now(),
          'subtotal': widget.totalAmount,
          'deliveryFee': fee,
          'totalAmount': widget.totalAmount + fee,
          'deliveryMethod': methodStr,
          'shippingAddress': methodStr == 'pickup' 
              ? "STORE PICKUP: HQ" 
              : "${_selectedUserAddress!.street}, ${_selectedUserAddress!.city} (${_selectedLocation!['name']})",
          'receiptImageUrl': receiptUrl,
          'orderItems': cartProvider.items.values.map((e) => {
            'productId': e.productId, 'productName': e.name, 'price': e.price, 'quantity': e.quantity, 'imageUrl': e.imageUrl
          }).toList(),
          'currentStep': 0,
          'estimatedCompletion': _getDeliveryEstimate(),
        });
      });

      cartProvider.clearCart();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OrderSuccessScreen()));
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  void _showRegionPicker() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _ModernRegionPicker(locations: _remoteLocations, onSelected: (loc) => setState(() => _selectedLocation = loc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = RemoteConfigService.getPrimaryColor();
    final userProv = Provider.of<UserProvider>(context);
    final List<UserAddress> addresses = userProv.appUser?.addresses ?? [];
    final bank = RemoteConfigService.bank;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Order Checkout", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.8), elevation: 0, centerTitle: true,
        flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 110),
          _buildStepper(primaryColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeader(title: "Step 1: Choose Logistics"),
              Row(children: [
                _MethodCard(title: "Pickup", subtitle: "Free", icon: Icons.storefront_outlined, isSelected: _selectedDeliveryMethod == DeliveryMethod.pickup, onTap: () => setState(() { _selectedDeliveryMethod = DeliveryMethod.pickup; _selectedLocation = null; }), color: primaryColor),
                const SizedBox(width: 15),
                _MethodCard(title: "Delivery", subtitle: "Benin City", icon: Icons.local_shipping_outlined, isSelected: _selectedDeliveryMethod == DeliveryMethod.delivery, onTap: () => setState(() => _selectedDeliveryMethod = DeliveryMethod.delivery), color: primaryColor),
              ]),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedDeliveryMethod == DeliveryMethod.delivery 
                  ? Column(children: [
                      const SizedBox(height: 25),
                      const SectionHeader(title: "Step 2: Region & Address"),
                      GestureDetector(
                        onTap: _showRegionPicker,
                        child: _ModernInputBox(icon: Icons.map_outlined, text: _selectedLocation?['name'] ?? "Select Region", isSelected: _selectedLocation != null, color: primaryColor),
                      ),
                      const SizedBox(height: 15),
                      _AddressSelectorCard(
                        selectedAddress: _selectedUserAddress,
                        addresses: addresses,
                        primaryColor: primaryColor,
                        onRefresh: () => setState(() {}),
                      ),
                    ])
                  : const SizedBox.shrink(),
              ),

              const SizedBox(height: 30),
              const SectionHeader(title: "Step 3: Transfer Payment"),
              _ModernBankCard(bankName: bank['bank_name'] ?? 'Moniepoint', accountNumber: bank['account_number'] ?? '5449707683', accountName: bank['account_name'] ?? '#08Vic Enterprise', onCopy: _copyToClipboard),
              
              const SizedBox(height: 30),
              const SectionHeader(title: "Step 4: Upload Proof"),
              _buildImagePicker(primaryColor),

              const SizedBox(height: 30),
              _DigitalReceipt(subtotal: widget.totalAmount, fee: _getDeliveryFee(), color: primaryColor),
              
              const SizedBox(height: 40),
              _buildOrderButton(primaryColor),
              const SizedBox(height: 60),
            ]),
          )
        ]),
      ),
    );
  }

  Widget _buildStepper(Color color) {
    int step = _selectedDeliveryMethod == null ? 0 : (_pickedReceiptImage == null ? 1 : 2);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Row(children: [
      Container(width: 35, height: 35, decoration: BoxDecoration(color: i <= step ? color : Colors.white, shape: BoxShape.circle, border: Border.all(color: i <= step ? color : Colors.grey.shade300, width: 2), boxShadow: i <= step ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)] : null), child: Center(child: i < step ? const Icon(Icons.check, size: 18, color: Colors.white) : Text("${i + 1}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: i <= step ? Colors.white : Colors.grey)))),
      if (i < 2) Container(width: 50, height: 2, color: i < step ? color : Colors.grey.shade300)
    ]))));
  }

  Widget _buildImagePicker(Color color) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: color.withOpacity(0.2), width: 2, style: BorderStyle.solid), image: _pickedReceiptImage != null ? DecorationImage(image: FileImage(_pickedReceiptImage!), fit: BoxFit.cover) : null),
        child: _pickedReceiptImage == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size: 45, color: color), const SizedBox(height: 10), Text("Click to upload Transfer Receipt", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13))]) : null,
      ),
    );
  }

  Widget _buildOrderButton(Color color) {
    return SizedBox(
      width: double.infinity, height: 65,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _placeOrder,
        style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 8, shadowColor: color.withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        child: _isUploading ? const CustomLoader(size: 30) : const Text("PLACE SECURE ORDER", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }
}

// --- PROFESSIONAL ADDRESS CARD ---
class _AddressSelectorCard extends StatelessWidget {
  final UserAddress? selectedAddress;
  final List<UserAddress> addresses;
  final Color primaryColor;
  final VoidCallback onRefresh;

  const _AddressSelectorCard({required this.selectedAddress, required this.addresses, required this.primaryColor, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final bool hasData = addresses.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("SHIPPING DESTINATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.2)),
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAddressesScreen())).then((_) => onRefresh()),
            child: Text(hasData ? "CHANGE / ADD" : "ADD NEW", style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 12)),
          )
        ]),
        const SizedBox(height: 12),
        if (hasData) ...[
          Row(children: [
            Icon(Icons.home_outlined, color: primaryColor),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(selectedAddress?.street ?? addresses.first.street, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)),
              Text("${selectedAddress?.city ?? addresses.first.city}, Edo State", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ]))
          ])
        ] else ...[
          const Center(child: Text("No delivery address found in your profile", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)))
        ]
      ]),
    );
  }
}

// --- UI COMPONENTS ---
class _ModernInputBox extends StatelessWidget {
  final IconData icon; final String text; final bool isSelected; final Color color;
  const _ModernInputBox({required this.icon, required this.text, required this.isSelected, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: 2)), child: Row(children: [Icon(icon, color: color), const SizedBox(width: 15), Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.black : Colors.grey))), const Icon(Icons.expand_more_rounded, color: Colors.grey)]));
}

class _MethodCard extends StatelessWidget {
  final String title, subtitle; final IconData icon; final bool isSelected; final VoidCallback onTap; final Color color;
  const _MethodCard({required this.title, required this.subtitle, required this.icon, required this.isSelected, required this.onTap, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 25), decoration: BoxDecoration(color: isSelected ? color : Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: isSelected ? color.withOpacity(0.3) : Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 10))]), child: Column(children: [Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 35), const SizedBox(height: 10), Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? Colors.white : Colors.black87)), Text(subtitle, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey))]))));
}

class _ModernBankCard extends StatelessWidget {
  final String bankName, accountNumber, accountName; final Function(String, String) onCopy;
  const _ModernBankCard({required this.bankName, required this.accountNumber, required this.accountName, required this.onCopy});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(25), decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(bankName.toUpperCase(), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)), const Icon(Icons.nfc_rounded, color: Colors.white24)]), const SizedBox(height: 25), GestureDetector(onTap: () => onCopy(accountNumber, "Account Number"), child: Row(children: [Expanded(child: Text(accountNumber, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4, fontFamily: 'monospace'))), const Icon(Icons.copy_rounded, color: Colors.white38, size: 22)])), const SizedBox(height: 20), Text(accountName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))]));
}

class _ModernRegionPicker extends StatefulWidget {
  final List<Map<String, dynamic>> locations; final Function(Map<String, dynamic>) onSelected;
  const _ModernRegionPicker({required this.locations, required this.onSelected});
  @override
  State<_ModernRegionPicker> createState() => _ModernRegionPickerState();
}

class _ModernRegionPickerState extends State<_ModernRegionPicker> {
  String query = "";
  @override
  Widget build(BuildContext context) {
    final filtered = widget.locations.where((l) => l['name'].toLowerCase().contains(query.toLowerCase())).toList();
    return Container(height: MediaQuery.of(context).size.height * 0.75, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))), padding: const EdgeInsets.all(25), child: Column(children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))), const SizedBox(height: 25), const Text("Search Delivery Area", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 20), TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(hintText: "Search Benin regions...", prefixIcon: const Icon(Icons.search_rounded), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))), const SizedBox(height: 15), Expanded(child: ListView.separated(itemCount: filtered.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (ctx, i) => ListTile(onTap: () { widget.onSelected(filtered[i]); Navigator.pop(context); }, title: Text(filtered[i]['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), trailing: Text("₦${filtered[i]['fee'].toInt()}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14)), leading: const Icon(Icons.location_on_outlined, color: Colors.redAccent)))) ]));
  }
}

class _DigitalReceipt extends StatelessWidget {
  final double subtotal, fee; final Color color;
  const _DigitalReceipt({required this.subtotal, required this.fee, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade100)), child: Column(children: [
    _row("Item Subtotal", "₦${subtotal.toStringAsFixed(2)}"), const SizedBox(height: 12),
    _row("Delivery Cost", "₦${fee.toStringAsFixed(2)}"), const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text("ORDER TOTAL", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
      Text("₦${(subtotal + fee).toStringAsFixed(2)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color))
    ]) 
  ]));
  Widget _row(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)), Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))]);
}

class SectionHeader extends StatelessWidget {
  final String title; const SectionHeader({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 5), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 1.5)));
}

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.check_circle_rounded, size: 120, color: Colors.greenAccent), const SizedBox(height: 25),
    const Text("ORDER SUBMITTED!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15), child: Text("Success! We are verifying your bank transfer. You will receive a notification shortly.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14))),
    const SizedBox(height: 40),
    ElevatedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 22), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text("BACK TO HOME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) 
  ])));
}