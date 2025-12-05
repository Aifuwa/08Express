// lib/screens/my_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:eight_express/services/order_service.dart';
import 'package:eight_express/models/AppOrder.dart';
import 'package:eight_express/screens/order_detail_screen.dart';
import 'package:eight_express/screens/home_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderService = Provider.of<OrderService>(context);
    const Color primaryColor = Color(0xFFFE7F2D);
    const Color backgroundColor = Color(0xFFF5F6F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // 1. IMMERSIVE HEADER (Matches Profile Screen)
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)], // Modern Teal/Dark Blue
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'My Orders',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balance the back button
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. ORDER LIST
          Expanded(
            child: StreamBuilder<List<AppOrder>>(
              stream: orderService.getUserOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // EMPTY STATE
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(context, primaryColor);
                }

                final orders = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: orders.length,
                  itemBuilder: (ctx, index) {
                    final order = orders[index];
                    return _buildPremiumOrderCard(context, order, primaryColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: EMPTY STATE ---
  Widget _buildEmptyState(BuildContext context, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]
            ),
            child: Icon(Icons.local_mall_outlined, size: 60, color: Colors.grey[300]),
          ),
          const SizedBox(height: 20),
          const Text(
            'No orders yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your order history will appear here.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const HomeScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              elevation: 5,
              shadowColor: primaryColor.withOpacity(0.4),
            ),
            child: const Text('Start Shopping', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: PREMIUM CARD ---
  Widget _buildPremiumOrderCard(BuildContext context, AppOrder order, Color primaryColor) {
    // Determine visuals based on status
    Color statusColor;
    String statusText = order.status.replaceAll('_', ' ').toUpperCase();
    IconData statusIcon;

    if (order.status.contains('delivered') || order.status.contains('completed')) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (order.status.contains('shipped')) {
      statusColor = Colors.blue;
      statusIcon = Icons.local_shipping;
    } else if (order.status.contains('pending')) {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time_filled;
      statusText = "PROCESSING";
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.info;
    }

    // Get first item image for preview
    String? previewImage = order.items.isNotEmpty ? order.items.first.imageUrl : null;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => OrderDetailScreen(order: order),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // TOP SECTION: Image + Info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Product Preview Image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.grey[100],
                      image: previewImage != null
                          ? DecorationImage(image: NetworkImage(previewImage), fit: BoxFit.cover)
                          : null,
                    ),
                    child: previewImage == null
                        ? const Icon(Icons.shopping_bag, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 15),
                  
                  // Order Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order ID
                        Text(
                          'Order #${order.id.substring(0, 6).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Date
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(order.orderDate.toDate()),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // SEPARATOR
            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // BOTTOM SECTION: Totals + Arrow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Amount",
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '\₦${order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  
                  // View Details Button (Small Arrow)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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