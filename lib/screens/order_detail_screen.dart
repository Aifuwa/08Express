import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eight_express/models/AppOrder.dart';
import 'package:eight_express/screens/product_detail_screen.dart'; // To navigate to product details if needed

class OrderDetailScreen extends StatelessWidget {
  final AppOrder order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              context,
              title: 'Order Summary',
              children: [
                _buildInfoRow('Order ID:', order.id),
                _buildInfoRow('Order Date:', DateFormat('MMM dd, yyyy - hh:mm a').format(order.orderDate.toDate())),
                _buildInfoRow('Total Amount:', '\₦${order.totalAmount.toStringAsFixed(2)}', isBold: true),
                // Add more order summary details if available in AppOrder model
                // _buildInfoRow('Status:', order.status),
                // _buildInfoRow('Shipping Address:', order.shippingAddress),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoCard(
              context,
              title: 'Items in Order',
              children: [
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(item.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text('Quantity: ${item.quantity}'),
                            Text('Price: \₦${item.price.toStringAsFixed(2)}'),
                            Text('Subtotal: \₦${(item.price * item.quantity).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? Colors.deepOrange : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}