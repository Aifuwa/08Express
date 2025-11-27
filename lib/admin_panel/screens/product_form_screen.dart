import 'package:flutter/material.dart';
import 'package:eight_express/admin_panel/models/product.dart';
import 'package:eight_express/admin_panel/services/admin_firestore_service.dart';
import 'package:eight_express/admin_panel/widgets/custom_admin_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
// Removed 'dart:io' show File; as it's not strictly necessary for web-only or unified approach.
// If you target mobile as well, ensure you handle platform specifics for File vs. bytes.

class ProductFormScreen extends StatefulWidget {
  final Product? product; // Null for new product, provided for editing

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminFirestoreService _adminService = AdminFirestoreService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _imageUrlController; // For manual URL entry
  late TextEditingController _stockController;
  late TextEditingController _categoryController;

  XFile? _pickedImageFile; // Store the actual XFile for upload
  String? _displayImageUrl; // For preview: either picked blob URL, existing URL, or manual URL
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    _imageUrlController = TextEditingController(text: widget.product?.imageUrl ?? ''); // Manual URL entry
    _stockController = TextEditingController(text: widget.product?.stock.toString() ?? '');
    _categoryController = TextEditingController(text: widget.product?.category ?? '');

    // Initialize display image URL with the existing product's image URL if available
    _displayImageUrl = widget.product?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImageFile = image; // Store the XFile for later upload
        _displayImageUrl = image.path; // This will be a 'blob:' URL on web, which Image.network can handle
        _imageUrlController.clear(); // Clear manual URL entry if an image is picked
      });
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final String fileName = 'product_images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      
      // Read the image file as bytes, which works for Flutter Web and mobile
      final bytes = await imageFile.readAsBytes();
      final UploadTask uploadTask = _storage.ref().child(fileName).putData(bytes);

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String? finalImageUrl;

      // 1. Prioritize uploading a newly picked image
      if (_pickedImageFile != null) {
        finalImageUrl = await _uploadImage(_pickedImageFile!);
        if (finalImageUrl == null) {
          // If upload failed, stop the save process
          setState(() => _isLoading = false);
          return;
        }
      }
      // 2. If no new image was picked, but a manual URL was entered, use that
      else if (_imageUrlController.text.trim().isNotEmpty) {
        finalImageUrl = _imageUrlController.text.trim();
      }
      // 3. If neither a new image nor a manual URL, retain the existing product's image URL (if editing)
      else if (widget.product?.imageUrl != null && widget.product!.imageUrl.isNotEmpty) {
        finalImageUrl = widget.product!.imageUrl;
      }
      // If finalImageUrl is still null, it means no image was provided for a new product,
      // or no change/input for an existing product, so it will be an empty string below.


      final Product newProduct = Product(
        id: widget.product?.id, // Keep existing ID for updates
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        imageUrl: finalImageUrl ?? '', // Use the determined image URL (or empty string if none)
        stock: int.parse(_stockController.text.trim()),
        category: _categoryController.text.trim(),
      );

      try {
        if (widget.product == null) {
          // Add new product
          await _adminService.addProduct(newProduct);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product added successfully!')),
            );
          }
        } else {
          // Update existing product
          await _adminService.updateProduct(newProduct);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product updated successfully!')),
            );
          }
        }
        if (mounted) {
          Navigator.of(context).pop(); // Go back to the product list screen
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save product: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add New Product' : 'Edit Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Container(
            width: 700, // Max width for the form on web
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product == null ? 'Add New Product Details' : 'Edit Product Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.shopping_bag)),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a product name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price', prefixIcon: Icon(Icons.attach_money)),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(labelText: 'Stock Quantity', prefixIcon: Icon(Icons.inventory)),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter stock quantity';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid integer';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a category';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _imageUrlController,
                          decoration: const InputDecoration(labelText: 'Image URL (Optional)', prefixIcon: Icon(Icons.link)),
                          enabled: _pickedImageFile == null, // Disable manual URL entry if an image has been picked
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              // If user starts typing a manual URL, clear any picked image state
                              setState(() {
                                _pickedImageFile = null;
                                _displayImageUrl = value; // Show manual URL in preview
                              });
                            } else {
                              // If manual URL is cleared, revert preview to picked image or original product image
                              setState(() {
                                _displayImageUrl = _pickedImageFile?.path ?? widget.product?.imageUrl;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      CustomAdminButton(
                        text: 'Upload Image',
                        icon: Icons.upload_file,
                        onPressed: _pickImage,
                        color: Colors.grey[700],
                      ),
                    ],
                  ),
                  // Image preview section
                  if (_displayImageUrl != null && _displayImageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Image.network(
                          _displayImageUrl!, // Image.network handles both HTTP/HTTPS and 'blob:' URLs
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 150, color: Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                  Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : CustomAdminButton(
                            text: widget.product == null ? 'Add Product' : 'Update Product',
                            icon: Icons.save,
                            onPressed: _saveProduct,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}