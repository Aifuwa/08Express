import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:eight_express/services/order_service.dart';
import 'package:eight_express/models/AppOrder.dart';
import 'package:eight_express/screens/order_detail_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
// ADDED: Import for your signature 08 loader
import 'package:eight_express/widgets/custom_loader.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderService = Provider.of<OrderService>(context);
    const Color primaryColor = Color(0xFFFE7F2D);
    const Color scaffoldBg = Color(0xFFF8F9FB);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // 1. SOFT TOP DECORATION
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryColor.withOpacity(0.15),
                    scaffoldBg,
                  ],
                ),
              ),
            ),
          ),

          // 2. MAIN CONTENT
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 100,
                pinned: true,
                elevation: 0,
                centerTitle: true,
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: const FlexibleSpaceBar(
                  title: Text(
                    "My Orders",
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  centerTitle: true,
                ),
              ),

              StreamBuilder<List<AppOrder>>(
                stream: orderService.getUserOrders(),
                builder: (context, snapshot) {
                  // --- UPDATED: Using Custom 08 Loader ---
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CustomLoader(size: 70)),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return SliverFillRemaining(child: _buildEmptyState(context, primaryColor));
                  }

                  final orders = snapshot.data!;
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) => _OrderCard(order: orders[index], primaryColor: primaryColor),
                        childCount: orders.length,
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://cdn-icons-png.flaticon.com/512/3500/3500833.png',
            height: 180,
            color: color.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          const Text("No orders yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          const Text("Hungry? Your next meal is a click away!", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text("Start Browsing", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final AppOrder order;
  final Color primaryColor;

  const _OrderCard({required this.order, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final status = _getStatusDetails(order.status);
    final String? previewImage = order.items.isNotEmpty ? order.items.first.imageUrl : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order))),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 75,
                          height: 75,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.grey[50],
                            image: previewImage != null
                                ? DecorationImage(image: NetworkImage(previewImage), fit: BoxFit.cover)
                                : null,
                          ),
                          child: previewImage == null ? const Icon(Icons.restaurant, color: Colors.grey) : null,
                        ),
                        if (order.items.length > 1)
                          Positioned(
                            bottom: -5,
                            right: -5,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                "+${order.items.length - 1}",
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Order #${order.id.substring(0, 6).toUpperCase()}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(order.orderDate.toDate()),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: status.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(status.icon, size: 14, color: status.color),
                                const SizedBox(width: 6),
                                Text(
                                  status.label,
                                  style: TextStyle(color: status.color, fontSize: 11, fontWeight: FontWeight.w900),
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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TOTAL AMOUNT", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        Text(
                          '₦${order.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text("View Details", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
                        const SizedBox(width: 5),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusInfo _getStatusDetails(String status) {
    if (status.toLowerCase().contains('delivered')) {
      return _StatusInfo(Icons.check_circle_rounded, Colors.green, "DELIVERED");
    } else if (status.toLowerCase().contains('shipped') || status.toLowerCase().contains('way')) {
      return _StatusInfo(Icons.local_shipping_rounded, Colors.blue, "ON THE WAY");
    } else if (status.toLowerCase().contains('pending') || status.toLowerCase().contains('processing')) {
      return _StatusInfo(Icons.timer_rounded, Colors.orange, "PROCESSING");
    } else if (status.toLowerCase().contains('cancelled')) {
      return _StatusInfo(Icons.cancel_rounded, Colors.red, "CANCELLED");
    }
    return _StatusInfo(Icons.help_rounded, Colors.grey, status.toUpperCase());
  }
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  final String label;
  _StatusInfo(this.icon, this.color, this.label);
}