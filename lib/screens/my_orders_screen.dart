import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:eight_express/services/order_service.dart';
import 'package:eight_express/models/AppOrder.dart'; // Ensure correct import for AppOrder
import 'package:eight_express/screens/order_detail_screen.dart'; // Import the new order detail screen

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderService = Provider.of<OrderService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: StreamBuilder<List<AppOrder>>(
        stream: orderService.getUserOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have no orders yet!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final orders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: orders.length,
            itemBuilder: (ctx, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16.0),
                  title: Text(
                    'Order ID: ${order.id.substring(0, 8).toUpperCase()}', // Shorten ID for display
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Total: \₦${order.totalAmount.toStringAsFixed(2)}'),
                      Text('Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(order.orderDate.toDate())}'),
                      Text('Items: ${order.items.length}'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => OrderDetailScreen(order: order),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}