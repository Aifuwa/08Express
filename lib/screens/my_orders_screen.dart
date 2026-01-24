import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:eight_express/services/order_service.dart';
import 'package:eight_express/models/AppOrder.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/order_detail_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/widgets/custom_loader.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderService = Provider.of<OrderService>(context);
    final userProv = Provider.of<UserProvider>(context);
    const Color primaryColor = Color(0xFFFE7F2D);
    const Color scaffoldBg = Color(0xFFF8F9FB);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primaryColor.withOpacity(0.15), scaffoldBg],
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 100,
                pinned: true,
                elevation: 0,
                centerTitle: true,
                backgroundColor: Colors.white.withOpacity(0.1),
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

              if (!userProv.isAuthenticated)
                const SliverFillRemaining(
                  child: Center(child: Text("Please login to see orders")),
                )
              else
                StreamBuilder<List<AppOrder>>(
                  stream: orderService.getUserOrders(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: Center(child: Text("Error loading orders")),
                      );
                    }

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
          Icon(Icons.shopping_bag_outlined, size: 100, color: color.withOpacity(0.2)),
          const SizedBox(height: 20),
          const Text("No orders yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          const Text("Your history will appear here.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    // Correctly accessing the new dynamic fields from the model
    final List<dynamic> milestones = order.trackingMilestones;
    final int currentStep = order.currentStep;
    
    final String currentStatusLabel = (currentStep < milestones.length) 
        ? milestones[currentStep].toString().toUpperCase() 
        : milestones.last.toString().toUpperCase();

    final String? previewImage = order.items.isNotEmpty ? order.items.first.imageUrl : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
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
                          width: 75, height: 75,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.grey[50],
                            image: previewImage != null ? DecorationImage(image: NetworkImage(previewImage), fit: BoxFit.cover) : null,
                          ),
                        ),
                        if (order.items.length > 1)
                          Positioned(
                            bottom: -5, right: -5,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: Text("+${order.items.length - 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Order #${order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(DateFormat('MMM dd, yyyy • hh:mm a').format(order.orderDate.toDate()), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentStatusLabel).withOpacity(0.1), 
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min, 
                              children: [
                                Icon(Icons.lens, size: 8, color: _getStatusColor(currentStatusLabel)),
                                const SizedBox(width: 6),
                                Text(currentStatusLabel, style: TextStyle(color: _getStatusColor(currentStatusLabel), fontSize: 10, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // THE TRACKING LINE (MATCHES FIRESTORE MILESTONES)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(milestones.length, (index) {
                        bool isCompleted = index <= currentStep;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isCompleted ? primaryColor : Colors.grey[200],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Progress", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text("${((currentStep + 1) / milestones.length * 100).toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFE7F2D))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(color: Colors.grey.shade50.withOpacity(0.5), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("TOTAL PAID", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      Text('₦${order.totalAmount.toStringAsFixed(0)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 18)),
                    ]),
                    const Row(children: [Text("Details", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)), SizedBox(width: 5), Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('DELIVERED') || status.contains('COLLECTED')) return Colors.green;
    if (status.contains('CANCELLED')) return Colors.red;
    if (status.contains('WAY') || status.contains('TRANSIT')) return Colors.blue;
    return const Color(0xFFFE7F2D);
  }
}