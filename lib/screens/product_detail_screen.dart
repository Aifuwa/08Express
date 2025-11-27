// lib/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/models/product.dart';
import 'package:eight_express/providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name, style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'productImage${widget.product.id}',
              child: Image.network(
                widget.product.imageUrl,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.broken_image, size: 100, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '\₦${widget.product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      color: primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.product.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(widget.product.category),
                        backgroundColor: primaryColor.withOpacity(0.1),
                        labelStyle: TextStyle(color: primaryColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                        side: BorderSide(color: primaryColor.withOpacity(0.2)),
                      ),
                      Text(
                        'In Stock: ${widget.product.stock}',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.product.stock > 0 ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (widget.product.stock > 0)
                    Row(
                      children: [
                        Text(
                          'Quantity:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: _quantity > 1
                                    ? () {
                                  setState(() {
                                    _quantity--;
                                  });
                                }
                                    : null,
                              ),
                              Text(
                                '$_quantity',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _quantity < widget.product.stock
                                    ? () {
                                  setState(() {
                                    _quantity++;
                                  });
                                }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.product.stock > 0
                          ? () {
                        Provider.of<CartProvider>(context, listen: false).addItem(widget.product, quantity: _quantity);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_quantity x ${widget.product.name} added to cart!'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                        setState(() {
                          _quantity = 1;
                        });
                      }
                          : null,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(widget.product.stock > 0 ? 'Add to Cart' : 'Out of Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.product.stock > 0 ? primaryColor : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}