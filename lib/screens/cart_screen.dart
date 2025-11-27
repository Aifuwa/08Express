// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/screens/checkout_screen.dart';
import 'package:eight_express/models/product.dart'; // Ensure Product model is correctly imported
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Timestamp
import 'package:eight_express/screens/home_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: cart.items.isEmpty
                ? _buildEmptyCartState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    // CORRECTED: 'itemCountByUniqueProducts' -> 'cart.items.length'
                    // This assumes cart.items is a Map<String, CartItem> and you want
                    // the count of unique products (keys in the map).
                    // If you have a specific getter for total product count with quantity, use that instead.
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      String productId = cart.items.keys.elementAt(i);
                      CartItem cartItem = cart.items.values.elementAt(i);
                      return CartItemCard(
                        productId: productId,
                        cartItem: cartItem,
                      );
                    },
                  ),
          ),
          _buildCheckoutSummary(context, cart),
        ],
      ),
    );
  }

  Widget _buildEmptyCartState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'Your cart is empty!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start adding some amazing items to your cart.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              //Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const HomeScreen()));
            },
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
            label: const Text(
              'Start Shopping',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSummary(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Total:',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(
                  '\₦${cart.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: cart.itemCount <= 0
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              CheckoutScreen(totalAmount: cart.totalAmount),
                        ),
                      );
                    },
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text(
                'Proceed to Checkout',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartItemCard extends StatelessWidget {
  final String productId;
  final CartItem cartItem;

  const CartItemCard({
    super.key,
    required this.productId,
    required this.cartItem,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Dismissible(
      key: ValueKey(productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(
          Icons.delete_sweep_outlined,
          color: Colors.white,
          size: 35,
        ),
      ),
      confirmDismiss: (direction) {
        return showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove Item?'),
            content: Text(
              'Do you want to remove "${cartItem.name}" from your cart?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('No', style: TextStyle(color: Theme.of(context).primaryColor)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Yes, Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        cart.removeItem(productId);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: cartItem.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cartItem.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)),
                          errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image_outlined, size: 40, color: Colors.grey[400]),
                        ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cartItem.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '\₦${cartItem.price.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                    onPressed: () {
                      Product productToAdd = Product(
                        id: cartItem.productId,
                        name: cartItem.name,
                        description: '', // Provide a default or fetch if available
                        price: cartItem.price,
                        imageUrl: cartItem.imageUrl,
                        category: '', // Provide a default or fetch if available
                        stock: cartItem.quantity, // Assuming current cart quantity as stock for adding
                        // CORRECTED: Convert DateTime.now() to a Firestore Timestamp
                        createdAt: Timestamp.now(),
                      );
                      cart.addItem(productToAdd);
                    },
                    tooltip: 'Increase quantity',
                  ),
                  Text(
                    '${cartItem.quantity}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      cart.removeSingleItem(productId);
                    },
                    tooltip: 'Decrease quantity',
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Text(
                '\₦${(cartItem.price * cartItem.quantity).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}