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

import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/home_screen.dart';
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
    
    final config = RemoteConfigService.delivery;
    int totalItems = _getTotalItemCount(cart);
    int threshold = config['threshold_items'] ?? 50;
    double standard = (config['standard_fee'] ?? 3000).toDouble();
    double large = (config['large_fee'] ?? 5000).toDouble();

    return totalItems <= threshold ? standard : large;
  }

  // --- UPDATED ORDER LOGIC WITH STOCK DEDUCTION ---
  Future<void> _placeOrder() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (cartProvider.items.isEmpty) return;
    
    // 1. Validations
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

    if (_pickedReceiptImage == null) {
      setState(() => _uploadMessage = '⚠ Please attach your payment receipt.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 2. Upload Receipt to Storage
      final String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}_${_pickedReceiptImage!.path.split('/').last}';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(_pickedReceiptImage!);
      final TaskSnapshot snapshot = await uploadTask;
      final String receiptImageUrl = await snapshot.ref.getDownloadURL();

      if (!mounted) return;

      // 3. Prepare Order Data
      final double deliveryFee = _calculateDeliveryFee(cartProvider);
      final double grandTotal = widget.totalAmount + deliveryFee;
      final String method = _selectedDeliveryMethod.toString().split('.').last;

      String shippingAddress;
      if (_selectedDeliveryMethod == DeliveryMethod.pickup) {
        shippingAddress = "STORE PICKUP: #08Vic Enterprise HQ";
      } else {
        final addr = _selectedUserAddress!;
        shippingAddress = "${addr.street}, ${addr.city}, ${addr.state} ${addr.zipCode}, ${addr.country}";
      }

      final orderItems = cartProvider.items.values.map((cartItem) => {
        'productId': cartItem.productId,
        'productName': cartItem.name,
        'price': cartItem.price,
        'quantity': cartItem.quantity,
        'imageUrl': cartItem.imageUrl,
      }).toList();

      // 4. RUN TRANSACTION: Deduct Stock AND Create Order atomically
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Step A: Verify Stock Availability for ALL items
        for (var cartItem in cartProvider.items.values) {
          DocumentReference productRef = FirebaseFirestore.instance.collection('products').doc(cartItem.productId);
          DocumentSnapshot productSnapshot = await transaction.get(productRef);

          if (!productSnapshot.exists) {
            throw Exception("Product '${cartItem.name}' no longer exists.");
          }

          int currentStock = productSnapshot.get('stock') ?? 0;
          if (currentStock < cartItem.quantity) {
             throw Exception("Stock Issue: '${cartItem.name}' only has $currentStock left.");
          }

          // Step B: Deduct Stock
          transaction.update(productRef, {
            'stock': currentStock - cartItem.quantity,
          });
        }

        // Step C: Create Order Document
        DocumentReference orderRef = FirebaseFirestore.instance.collection('orders').doc();
        transaction.set(orderRef, {
          'userId': currentUser.uid,
          'status': 'pending_receipt_verification',
          'orderDate': Timestamp.now(),
          'subtotal': widget.totalAmount,
          'deliveryFee': deliveryFee,
          'totalAmount': grandTotal,
          'deliveryMethod': method,
          'shippingAddress': shippingAddress,
          'receiptImageUrl': receiptImageUrl,
          'orderItems': orderItems,
          'trackingMilestones': method == 'pickup' 
              ? ['Order Placed', 'Payment Verified', 'Processing', 'Ready for Pickup', 'Collected']
              : ['Order Placed', 'Payment Verified', 'Processing', 'In Transit', 'Delivered'],
          'currentStep': 0, 
          'estimatedCompletion': _getDeliveryEstimate(),
        });
      });

      // 5. Success
      cartProvider.clearCart();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const OrderSuccessScreen()),
        );
      }

    } catch (e) {
      _logger.e(e);
      String errorMsg = 'Failed to place order. Please try again.';

      // Display friendly stock error
      if (e.toString().contains("Stock Issue")) {
        errorMsg = e.toString().replaceAll("Exception: ", "");
      }

      if (mounted) {
        setState(() => _uploadMessage = errorMsg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
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
    
    final bank = RemoteConfigService.bank;

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
                  bankName: bank['bank_name'] ?? 'Moniepoint',
                  accountNumber: bank['account_number'] ?? '5449707683',
                  accountName: bank['account_name'] ?? '#08Vic Enterprise',
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