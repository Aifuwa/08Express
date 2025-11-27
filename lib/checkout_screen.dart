import 'package:flutter/material.dart';
import 'dart:io'; // For File operations
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:firebase_storage/firebase_storage.dart'; // For uploading to Firebase Storage
import 'package:cloud_firestore/cloud_firestore.dart'; // For saving order details
import 'package:provider/provider.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/screens/home_screen.dart'; // For navigating back
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:logger/logger.dart'; // For logging

final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: false,
  ),
);

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

  // Function to pick an image from gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _pickedReceiptImage = File(pickedFile.path);
        _uploadMessage = null; // Clear previous messages
      } else {
        _uploadMessage = 'No image selected.';
        _logger.i('No image selected for receipt.');
      }
    });
  }

  // Function to upload the image to Firebase Storage
  Future<String?> _uploadReceiptImage() async {
    if (_pickedReceiptImage == null) {
      if (mounted) { // Check mounted before calling setState after an await
        setState(() {
          _uploadMessage = 'Please select a receipt image first.';
        });
      }
      _logger.w('Attempted to upload receipt without selecting an image.');
      return null;
    }

    setState(() {
      _isUploading = true;
      _uploadMessage = 'Uploading receipt...';
    });
    _logger.i('Starting receipt image upload.');

    try {
      final String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}_${_pickedReceiptImage!.path.split('/').last}';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(_pickedReceiptImage!);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) { // Check mounted before calling setState after an async operation
        setState(() {
          _uploadMessage = 'Receipt uploaded successfully!';
        });
      }
      _logger.d('Receipt uploaded successfully. Download URL: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      if (mounted) { // Check mounted before calling setState after an async operation
        setState(() {
          _uploadMessage = 'Upload failed: ${e.message}';
        });
      }
      _logger.e('Firebase Storage upload error: ${e.code} - ${e.message}', error: e);
      return null;
    } finally {
      if (mounted) { // Check mounted before calling setState in finally block after an async operation
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Function to place the order
  Future<void> _placeOrder() async {
    setState(() {
      _isUploading = true; // Use this flag for overall order placement now
      _uploadMessage = 'Placing order...';
    });
    _logger.i('Attempting to place order.');


    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.itemCount == 0) {
      if (mounted) {
        setState(() {
          _uploadMessage = 'Your cart is empty!';
          _isUploading = false;
        });
      }
      _logger.w('Order placement aborted: Cart is empty.');
      return;
    }

    // --- Start of userId correction ---
    final User? currentUser = FirebaseAuth.instance.currentUser;
    String userId;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _uploadMessage = 'Error: No user logged in. Please log in to place an order.';
          _isUploading = false;
        });
      }
      _logger.e('Order placement aborted: No user logged in.');
      return; // Stop if no user is logged in
    } else {
      userId = currentUser.uid;
      _logger.d('Logged-in User ID: $userId');
    }
    // --- End of userId correction ---

    final receiptImageUrl = await _uploadReceiptImage();
    if (receiptImageUrl == null) {
      // _uploadReceiptImage already handles setting _isUploading to false and message.
      _logger.e('Order placement aborted: Receipt image upload failed.');
      return; // Image upload failed
    }

    if (!mounted) { // Crucial mounted check after an await that might have taken time
      _logger.w('Widget unmounted after image upload, aborting order placement.');
      return;
    }

    try {
      // Prepare order data
      final orderItems = cartProvider.items.values.map((cartItem) => {
        // Assuming CartItem directly has these properties based on previous discussions
        'productId': cartItem.productId,
        'productName': cartItem.name,
        'price': cartItem.price,
        'quantity': cartItem.quantity,
        'imageUrl': cartItem.imageUrl, // Ensure this property exists on CartItem
      }).toList();

      await FirebaseFirestore.instance.collection('orders').add({
        'totalAmount': widget.totalAmount,
        'receiptImageUrl': receiptImageUrl,
        'orderItems': orderItems,
        'orderDate': Timestamp.now(),
        'userId': userId, // Use the actual user ID here
        'status': 'pending_receipt_verification',
      });

      // Clear the cart after successful order
      cartProvider.clearCart();

      if (mounted) { // Check mounted before calling setState or Navigator actions
        setState(() {
          _uploadMessage = 'Order placed successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order Placed! Thank you for your purchase.')),
        );

        _logger.i('Order placed successfully for user $userId.');
        Navigator.of(context).popUntil((route) => route.isFirst); // Pop all routes until root
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const HomeScreen()));
      }
    } on FirebaseException catch (e) {
      if (mounted) { // Check mounted before calling setState after an async operation
        setState(() {
          _uploadMessage = 'Order placement failed: ${e.message}';
        });
      }
      _logger.e('Firebase Firestore order placement failed: ${e.code} - ${e.message}', error: e);
    } finally {
      if (mounted) { // Check mounted before calling setState in finally block after an async operation
        setState(() {
          _isUploading = false;
        });
      }
      _logger.i('Order placement process finished.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Order Total: \₦${widget.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Method: Upload Receipt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _pickedReceiptImage != null
                ? Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.file(
                      _pickedReceiptImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: Icon(Icons.receipt, size: 100, color: Colors.grey[600]),
                  ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Pick Receipt Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            if (_uploadMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  _uploadMessage!,
                  style: TextStyle(
                    color: _uploadMessage!.contains('failed') ? Colors.red : Colors.green,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _placeOrder, // Disable while uploading/processing
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.payment),
              label: Text(_isUploading ? 'Processing Order...' : 'Place Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}