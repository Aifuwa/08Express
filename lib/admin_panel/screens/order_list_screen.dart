import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Requires intl package in pubspec.yaml
import 'package:eight_express/admin_panel/models/order_model.dart';
import 'package:eight_express/admin_panel/services/admin_firestore_service.dart';
// Ensure this path matches where you put the detail screen file
import 'package:eight_express/admin_panel/screens/order_detail_screen.dart'; 

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminFirestoreService adminService = AdminFirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // Dark text for white app bar
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: adminService.getOrders(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading orders: ${snapshot.error}'),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? [];

          // 3. Empty State
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No orders received yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // 4. Data List State
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final dateString = DateFormat('MMM dd, yyyy – hh:mm a').format(order.date);
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Navigate to details screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailScreen(order: order),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Order ID and Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${order.id.substring(0, 8).toUpperCase()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateString,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getStatusColor(order.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _getStatusColor(order.status)),
                              ),
                              child: Text(
                                order.status,
                                style: TextStyle(
                                  color: _getStatusColor(order.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${order.items.length} Items',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            Text(
                              '\$${order.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1E3A8A), // Admin theme blue
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Helper method to get color based on status text
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}