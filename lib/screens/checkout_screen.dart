// lib/screens/checkout_screen.dart
import 'dart:math';
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

// Imports
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/screens/user_addresses_screen.dart';
import 'package:eight_express/models/app_user.dart';
// ADDED: Import for your signature 08 loader
import 'package:eight_express/widgets/custom_loader.dart';

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

class _CheckoutScreenState extends State<CheckoutScreen> {
  File? _pickedReceiptImage;
  bool _isUploading = false;
  String? _uploadMessage;

  DeliveryMethod _selectedDeliveryMethod = DeliveryMethod.pickup;
  UserAddress? _selectedUserAddress;
  
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final addresses = userProvider.appUser?.addresses ?? [];
      
      if (addresses.isNotEmpty) {
        try {
          final defaultAddr = addresses.firstWhere(
            (a) => a.isDefault, 
            orElse: () => addresses.first
          );
          setState(() {
            _selectedUserAddress = defaultAddr;
          });
        } catch (e) {
          setState(() {
            _selectedUserAddress = null;
          });
        }
      }
    });
  }

  // --- LOGIC ---

  String _getDeliveryEstimate() {
    DateTime orderDate = DateTime.now();
    DateTime start = orderDate.add(const Duration(days: 1));
    DateTime end = orderDate.add(const Duration(days: 3));
    final DateFormat formatter = DateFormat('MMM d');
    return "${formatter.format(start)} - ${formatter.format(end)}";
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('$label copied!'),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (mounted) {
      setState(() {
        if (pickedFile != null) {
          _pickedReceiptImage = File(pickedFile.path);
          _uploadMessage = null;
        }
      });
    }
  }

  int _getTotalItemCount(CartProvider cart) {
    int totalCount = 0;
    cart.items.forEach((key, item) {
      totalCount += item.quantity;
    });
    return totalCount;
  }

  double _calculateDeliveryFee(CartProvider cart) {
    if (_selectedDeliveryMethod == DeliveryMethod.pickup) return 0.0;
    int totalItems = _getTotalItemCount(cart);
    return totalItems <= 50 ? 3000.0 : 5000.0;
  }

  Future<String?> _uploadReceiptImage() async {
    if (_pickedReceiptImage == null) {
      if (mounted) setState(() => _uploadMessage = '⚠ Please attach your payment receipt.');
      return null;
    }

    setState(() {
      _isUploading = true;
      _uploadMessage = 'Uploading receipt...';
    });

    try {
      final String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}_${_pickedReceiptImage!.path.split('/').last}';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(_pickedReceiptImage!);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (mounted) setState(() => _uploadMessage = 'Error: ${e.message}');
      return null;
    } 
  }

  Future<void> _placeOrder() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (cartProvider.items.isEmpty) return;
    
    if (_selectedDeliveryMethod == DeliveryMethod.delivery && _selectedUserAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address'), backgroundColor: Colors.red),
      );
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }

    setState(() => _isUploading = true);

    final receiptImageUrl = await _uploadReceiptImage();
    if (receiptImageUrl == null) {
      setState(() => _isUploading = false);
      return;
    }

    if (!mounted) return;

    try {
      final double deliveryFee = _calculateDeliveryFee(cartProvider);
      final double grandTotal = widget.totalAmount + deliveryFee;

      final orderItems = cartProvider.items.values.map((cartItem) => {
        'productId': cartItem.productId,
        'productName': cartItem.name,
        'price': cartItem.price,
        'quantity': cartItem.quantity,
        'imageUrl': cartItem.imageUrl,
      }).toList();

      String shippingAddress;
      if (_selectedDeliveryMethod == DeliveryMethod.pickup) {
        shippingAddress = "STORE PICKUP";
      } else {
        final addr = _selectedUserAddress!;
        shippingAddress = "${addr.street}, ${addr.city}, ${addr.state} ${addr.zipCode}, ${addr.country}";
      }

      await FirebaseFirestore.instance.collection('orders').add({
        'userId': currentUser.uid,
        'status': 'pending_receipt_verification',
        'orderDate': Timestamp.now(),
        'subtotal': widget.totalAmount,
        'deliveryFee': deliveryFee,
        'totalAmount': grandTotal,
        'deliveryMethod': _selectedDeliveryMethod.toString().split('.').last,
        'shippingAddress': shippingAddress,
        'receiptImageUrl': receiptImageUrl,
        'orderItems': orderItems,
      });

      cartProvider.clearCart();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const OrderSuccessScreen()),
        );
      }
    } catch (e) {
      _logger.e(e);
      if (mounted) setState(() => _uploadMessage = 'Failed to place order.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final List<UserAddress> userAddresses = userProvider.appUser?.addresses ?? [];

    final double deliveryFee = _calculateDeliveryFee(cart);
    final double grandTotal = widget.totalAmount + deliveryFee;
    final String deliveryText = _getDeliveryEstimate();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Checkout", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                const SectionTitle(title: "1. Delivery Method"),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildModernRadioTile(
                        value: DeliveryMethod.pickup,
                        title: 'Store Pickup',
                        subtitle: 'Ready in 24-72 hours',
                        icon: Icons.storefront_rounded,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 1, color: Colors.grey[200]),
                      ),
                      _buildModernRadioTile(
                        value: DeliveryMethod.delivery,
                        title: 'Door Delivery',
                        subtitle: 'Est. $deliveryText',
                        icon: Icons.local_shipping_rounded,
                        fee: deliveryFee,
                      ),
                    ],
                  ),
                ),

                if (_selectedDeliveryMethod == DeliveryMethod.delivery) ...[
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionTitle(title: "Shipping Address", bottomPadding: 0),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAddressesScreen()));
                        },
                        child: Text("Manage", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: userAddresses.isEmpty
                      ? Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAddressesScreen())),
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text("Add New Address"),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<UserAddress>(
                            isExpanded: true,
                            value: userAddresses.contains(_selectedUserAddress) ? _selectedUserAddress : null,
                            hint: const Text("Select address"),
                            onChanged: (UserAddress? newValue) => setState(() => _selectedUserAddress = newValue),
                            items: userAddresses.map((addr) => DropdownMenuItem(
                              value: addr,
                              child: Text("${addr.street}, ${addr.city}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            )).toList(),
                          ),
                        ),
                  ),
                ],

                const SizedBox(height: 30),
                const SectionTitle(title: "Order Summary"),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Subtotal', widget.totalAmount),
                      const SizedBox(height: 10),
                      _buildSummaryRow('Delivery Fee', deliveryFee, isHighlighted: true),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL PAYABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                          Text('₦${grandTotal.toStringAsFixed(2)}', 
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Theme.of(context).primaryColor)
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const StepHeader(number: "1", title: "Make Bank Transfer"),
                const SizedBox(height: 10),
                BankDetailsCard(
                  bankName: 'Moniepoint',
                  accountNumber: '5449707683',
                  accountName: '#08Vic Enterprise',
                  onCopy: _copyToClipboard,
                ),

                const SizedBox(height: 25),
                const StepHeader(number: "2", title: "Upload Receipt"),
                const SizedBox(height: 10),
                
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _pickedReceiptImage != null ? Colors.white : const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(16),
                      image: _pickedReceiptImage != null 
                          ? DecorationImage(image: FileImage(_pickedReceiptImage!), fit: BoxFit.cover)
                          : null
                    ),
                    child: _pickedReceiptImage == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file, color: Theme.of(context).primaryColor, size: 28),
                            const SizedBox(height: 12),
                            Text('Tap to upload Screenshot', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : null,
                  ),
                ),
                
                if (_uploadMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Text(_uploadMessage!, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ),

                const SizedBox(height: 40),

                // --- CONFIRM BUTTON WITH CUSTOM LOADER ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isUploading
                        // --- UPDATED: Using signature 08 loader inside the button ---
                        ? const CustomLoader(size: 40) 
                        : const Text('CONFIRM PAYMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildModernRadioTile({
    required DeliveryMethod value,
    required String title,
    required String subtitle,
    required IconData icon,
    double? fee,
  }) {
    final bool isSelected = _selectedDeliveryMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedDeliveryMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey, size: 24),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300])
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.black54)),
        Text('₦${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final double bottomPadding;
  const SectionTitle({super.key, required this.title, this.bottomPadding = 10});
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: bottomPadding, left: 5), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
}

class StepHeader extends StatelessWidget {
  final String number;
  final String title;
  const StepHeader({super.key, required this.number, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [CircleAvatar(radius: 12, backgroundColor: Colors.black, child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12))), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))]);
}

class BankDetailsCard extends StatelessWidget {
  final String bankName;
  final String accountNumber;
  final String accountName;
  final Function(String, String) onCopy;

  const BankDetailsCard({super.key, required this.bankName, required this.accountNumber, required this.accountName, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blueGrey.shade900, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bankName.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(accountNumber, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => onCopy(accountNumber, 'Account Number'), icon: const Icon(Icons.copy, color: Colors.cyan))
            ],
          ),
          const SizedBox(height: 5),
          Text(accountName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text('Order Submitted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text("BACK TO HOME")),
          ],
        ),
      ),
    );
  }
}