// lib/screens/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eight_express/models/AppOrder.dart';

class OrderDetailScreen extends StatefulWidget {
  final AppOrder order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Hardcoded Store Address
  final String _storeAddress = "269, Murtala Muhammed way, opposite Igbinedion education center, off Sapele Road, Benin City";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- LOGIC: Delivery Date Calculator ---
  String _getDeliveryEstimate(DateTime orderDate) {
    // Start date = Order date + 1 day
    DateTime start = orderDate.add(const Duration(days: 1));
    // End date = Order date + 3 days
    DateTime end = orderDate.add(const Duration(days: 3));

    final DateFormat formatter = DateFormat('MMM d');
    return "Between ${formatter.format(start)} and ${formatter.format(end)}";
  }

  // --- LOGIC: Define Timeline Steps based on Method ---
  List<String> _getSteps() {
    // Note: These strings must match what the Admin sets in Firestore 'status' field
    if (widget.order.deliveryMethod == 'pickup') {
      return [
        'pending_receipt_verification', // 0: Ordered (Pending)
        'verified',                     // 1: Receipt Verified
        'ready_for_pickup',             // 2: Ready for Pickup
        'picked_up'                     // 3: Picked Up
      ];
    } else {
      return [
        'pending_receipt_verification', // 0: Ordered (Pending)
        'verified',                     // 1: Receipt Verified / Processing
        'shipped',                      // 2: Shipped / Out for Delivery
        'delivered'                     // 3: Delivered
      ];
    }
  }

  List<String> _getStepTitles() {
    if (widget.order.deliveryMethod == 'pickup') {
      return ['Ordered (Pending Verification)', 'Receipt Verified', 'Ready for Pickup', 'Picked Up'];
    } else {
      return ['Ordered (Pending Verification)', 'Receipt Verified', 'Shipped', 'Delivered'];
    }
  }

  int _getCurrentStepIndex() {
    List<String> steps = _getSteps();
    int index = steps.indexOf(widget.order.status);
    // If status isn't exact match (e.g. 'cancelled'), or handling defaults
    if (index == -1) {
      if (widget.order.status == 'completed') return 3;
      return 0; 
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFE7F2D);
    const Color backgroundColor = Color(0xFFF5F6F8);
    
    final bool isPickup = widget.order.deliveryMethod == 'pickup';
    final double subtotal = widget.order.totalAmount - widget.order.deliveryFee;
    final int currentStepIndex = _getCurrentStepIndex();
    final List<String> stepTitles = _getStepTitles();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER CARD (ID, Date, Estimated Time)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${widget.order.id.substring(0, 5).toUpperCase()}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isPickup ? "PICKUP" : "DELIVERY",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    DateFormat('MMMM dd, yyyy • hh:mm a').format(widget.order.orderDate.toDate()),
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(isPickup ? Icons.storefront : Icons.local_shipping, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPickup ? "Ready for Pickup Estimate" : "Estimated Delivery",
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                            ),
                            Text(
                              _getDeliveryEstimate(widget.order.orderDate.toDate()),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (!isPickup)
                              Text(
                                "(Sundays excluded)",
                                style: TextStyle(color: Colors.orangeAccent.shade100, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 2. VERTICAL ANIMATED TIMELINE
            const Text("Tracking", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stepTitles.length,
                itemBuilder: (context, index) {
                  return _buildAnimatedTimelineTile(
                    title: stepTitles[index],
                    isLast: index == stepTitles.length - 1,
                    index: index,
                    currentIndex: currentStepIndex,
                    primaryColor: primaryColor,
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // 3. ADDRESS INFO
            const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isPickup ? Icons.store_mall_directory : Icons.location_on, 
                    color: isPickup ? primaryColor : Colors.redAccent,
                    size: 30
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPickup ? "Pickup Store Address" : "Delivery Address",
                          style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          // Logic: If pickup, show Store Address. If delivery, show stored user address.
                          isPickup ? _storeAddress : widget.order.shippingAddress,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 4. ITEMS ORDERED
            const Text("Items Ordered", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ...widget.order.items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(width: 60, height: 60, color: Colors.grey[200]),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text("Qty: ${item.quantity}", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text("\₦${item.price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )).toList(),

            const SizedBox(height: 25),

            // 5. PAYMENT SUMMARY
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _buildRow("Subtotal", subtotal),
                  const SizedBox(height: 10),
                  _buildRow("Delivery Fee", widget.order.deliveryFee),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Grand Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        "\₦${widget.order.totalAmount.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildAnimatedTimelineTile({
    required String title,
    required bool isLast,
    required int index,
    required int currentIndex,
    required Color primaryColor,
  }) {
    bool isCompleted = index <= currentIndex;
    bool isCurrent = index == currentIndex;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The Line and Dot Column
        Column(
          children: [
            // The Dot (Animated Scale)
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCompleted ? (isCurrent ? primaryColor : Colors.green) : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: isCurrent ? Border.all(color: primaryColor.withOpacity(0.3), width: 4) : null,
                ),
                child: isCompleted && !isCurrent 
                    ? const Icon(Icons.check, size: 12, color: Colors.white) 
                    : null,
              ),
            ),
            // The Line
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: index < currentIndex ? Colors.green : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 15),
        // The Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 30), // Spacing matching the line height
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text("\₦${amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}