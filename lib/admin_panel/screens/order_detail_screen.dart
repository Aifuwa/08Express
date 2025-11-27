import 'package:flutter/material.dart';
import 'package:eight_express/admin_panel/models/order_model.dart';
import 'package:eight_express/admin_panel/services/admin_firestore_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final AdminFirestoreService _adminService = AdminFirestoreService();
  late String _currentStatus;

  final List<String> _statusOptions = [
    'Pending',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  Future<void> _updateStatus(String? newStatus) async {
    if (newStatus != null && newStatus != _currentStatus) {
      try {
        await _adminService.updateOrderStatus(widget.order.id, newStatus);
        setState(() {
          _currentStatus = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order updated to $newStatus')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text('Status:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusOptions.contains(_currentStatus) ? _currentStatus : _statusOptions[0],
                        items: _statusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: _updateStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Shipping Info
            const Text('Shipping Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User ID: ${widget.order.userId}'),
                  const SizedBox(height: 5),
                  Text('Address: ${widget.order.shippingAddress['address'] ?? 'N/A'}'),
                  Text('City: ${widget.order.shippingAddress['city'] ?? 'N/A'}'),
                  Text('Zip: ${widget.order.shippingAddress['zip'] ?? 'N/A'}'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Items List
            const Text('Items Ordered', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.order.items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = widget.order.items[index];
                return ListTile(
                  leading: item['imageUrl'] != null 
                    ? Image.network(item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported),
                  title: Text(item['name'] ?? 'Product'),
                  subtitle: Text('Qty: ${item['quantity'] ?? 1}'),
                  trailing: Text('\$${(item['price'] ?? 0).toString()}'),
                );
              },
            ),
            const Divider(thickness: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: \$${widget.order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}