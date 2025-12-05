// lib/screens/checkout_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:intl/intl.dart'; // REQUIRED FOR DATE FORMATTING
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
  
  // Track selected address object
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

  // --- LOGIC: Delivery Date Calculator ---
  String _getDeliveryEstimate() {
    DateTime orderDate = DateTime.now();
    // Start date = Today + 1 day
    DateTime start = orderDate.add(const Duration(days: 1));
    // End date = Today + 3 days
    DateTime end = orderDate.add(const Duration(days: 3));

    final DateFormat formatter = DateFormat('MMM d');
    return "Estimated between ${formatter.format(start)} and ${formatter.format(end)}";
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
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
      if (mounted) setState(() => _uploadMessage = '⚠ Select a receipt first.');
      return null;
    }

    setState(() {
      _isUploading = true;
      _uploadMessage = 'Uploading...';
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
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _placeOrder() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (cartProvider.items.isEmpty) return;
    
    if (_selectedDeliveryMethod == DeliveryMethod.delivery) {
      if (_selectedUserAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a delivery address'), 
            backgroundColor: Colors.red
          ),
        );
        return;
      }
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

    // Calculate dynamic delivery text
    final String deliveryText = _getDeliveryEstimate();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildCustomHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    children: [
                      // --- DELIVERY METHOD SECTION ---
                      _buildSectionHeader('Delivery Method'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                        ),
                        child: Column(
                          children: [
                            _buildRadioTile(
                              value: DeliveryMethod.pickup,
                              title: 'Store Pickup',
                              subtitle: 'Pickup within 3 days. Late fees apply after.',
                              icon: Icons.storefront,
                              warningColor: Colors.orange,
                            ),
                            const Divider(height: 1),
                            _buildRadioTile(
                              value: DeliveryMethod.delivery,
                              title: 'Home Delivery',
                              // Use the dynamic date string here
                              subtitle: '$deliveryText. Fees apply.',
                              icon: Icons.local_shipping,
                              warningColor: Colors.green,
                              feeInfo: 'Fee: ₦${deliveryFee.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                      ),
                      
                      // --- ADDRESS SELECTION LOGIC ---
                      if (_selectedDeliveryMethod == DeliveryMethod.delivery) ...[
                        const SizedBox(height: 15),
                        
                        if (userAddresses.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.location_off_outlined, color: Colors.grey, size: 40),
                                const SizedBox(height: 8),
                                const Text("No saved addresses found.", style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAddressesScreen()));
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text("Add New Address"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(context).primaryColor,
                                      side: BorderSide(color: Theme.of(context).primaryColor),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 5),
                                child: Text("Select Address", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<UserAddress>(
                                    isExpanded: true,
                                    hint: const Text("Select Delivery Address"),
                                    value: userAddresses.contains(_selectedUserAddress) ? _selectedUserAddress : null,
                                    onChanged: (UserAddress? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedUserAddress = newValue;
                                        });
                                      }
                                    },
                                    items: userAddresses.map((UserAddress address) {
                                      return DropdownMenuItem<UserAddress>(
                                        value: address,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.location_on, 
                                              size: 20, 
                                              color: address.isDefault ? Colors.orange : Colors.grey
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    address.street,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    "${address.city}, ${address.state}",
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAddressesScreen()));
                                  },
                                  child: const Text("Manage Addresses", style: TextStyle(fontSize: 12)),
                                ),
                              )
                            ],
                          )
                      ],

                      const SizedBox(height: 20),
                      
                      // --- SUMMARY SECTION ---
                      _buildSectionHeader('Summary'),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Subtotal', widget.totalAmount),
                            _buildSummaryRow('Delivery Fee', deliveryFee, isFee: true),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('₦${grandTotal.toStringAsFixed(2)}', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).primaryColor)
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // --- PAYMENT SECTION ---
                      _buildSectionHeader('Payment'),
                      AccountDetailCard(
                        bankName: 'Moniepoint',
                        accountNumber: '5449707683',
                        accountName: '#08Vic Enterprise',
                        onCopy: _copyToClipboard,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // --- PROOF OF PAYMENT ---
                      _buildSectionHeader('Proof of Payment'),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            image: _pickedReceiptImage != null 
                                ? DecorationImage(image: FileImage(_pickedReceiptImage!), fit: BoxFit.cover)
                                : null
                          ),
                          child: _pickedReceiptImage == null 
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, color: Colors.grey.shade400, size: 30),
                                  const SizedBox(height: 5),
                                  Text('Tap to upload receipt', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              )
                            : null,
                        ),
                      ),
                      if (_uploadMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_uploadMessage!, 
                            style: TextStyle(
                              fontSize: 12, 
                              color: _uploadMessage!.contains('Error') || _uploadMessage!.contains('wait') ? Colors.red : Colors.green, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                      
                      const SizedBox(height: 25),
                      
                      // --- CONFIRM BUTTON ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _placeOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                          ),
                          child: _isUploading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('CONFIRM ORDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildCustomHeader(BuildContext context) {
    final List<IconData> icons = [Icons.shopping_bag, Icons.shopping_cart, Icons.local_offer, Icons.credit_card, Icons.store];
    final Random random = Random();

    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.9),
            Theme.of(context).primaryColor,
            Colors.blue.shade800,
          ],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Stack(
                  children: List.generate(10, (index) {
                    return Positioned(
                      left: random.nextDouble() * 300,
                      top: random.nextDouble() * 80,
                      child: Icon(icons[index % icons.length], color: Colors.white, size: 20 + random.nextDouble() * 20),
                    );
                  }),
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Checkout',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title.toUpperCase(), 
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required DeliveryMethod value,
    required String title,
    required String subtitle,
    required IconData icon,
    Color? warningColor,
    String? feeInfo,
  }) {
    final bool isSelected = _selectedDeliveryMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedDeliveryMethod = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSelected ? Colors.black : Colors.grey[700])),
                      if (feeInfo != null)
                        Text(feeInfo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: warningColor ?? Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isFee = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          Text(
            amount == 0 && isFee ? 'Free' : '₦${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w600, 
              color: isFee && amount > 0 ? Colors.red[700] : Colors.black87
            ),
          ),
        ],
      ),
    );
  }
}

class AccountDetailCard extends StatelessWidget {
  final String bankName;
  final String accountNumber;
  final String accountName;
  final Function(String text, String label) onCopy;

  const AccountDetailCard({
    super.key,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.account_balance, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Text("Account:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    accountNumber,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => onCopy(accountNumber, 'Account Number'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                    child: const Text("COPY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Name:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    accountName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW SUCCESS SCREEN ---
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Scale Checkmark
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Colors.blue.shade800,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ]
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              const Text(
                'Order Completed',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              const Text(
                'Thank you for your purchase!\nYour order is pending verification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              
              const SizedBox(height: 50),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                     Navigator.of(context).popUntil((route) => route.isFirst);
                     Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const HomeScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("CONTINUE SHOPPING", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}