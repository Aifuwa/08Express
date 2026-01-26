import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eight_express/models/AppOrder.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrderDetailScreen extends StatefulWidget {
  final AppOrder order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Hardcoded Store Address for Pickups
  final String _storeAddress = "#08Vic Enterprise HQ: 269, Murtala Muhammed way, opposite Igbinedion education center, off Sapele Road, Benin City";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- LOGIC: Delivery Date Calculator ---
  String _getDeliveryEstimate(DateTime orderDate) {
    DateTime start = orderDate.add(const Duration(days: 1));
    DateTime end = orderDate.add(const Duration(days: 3));
    final DateFormat formatter = DateFormat('MMM d');
    return "Between ${formatter.format(start)} and ${formatter.format(end)}";
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFE7F2D);
    const Color backgroundColor = Color(0xFFF8F9FB);
    
    final bool isPickup = widget.order.deliveryMethod.toLowerCase() == 'pickup';
    final double subtotal = widget.order.totalAmount - widget.order.deliveryFee;
    
    // Status & Failure Logic
    final String currentStatus = widget.order.status.toUpperCase();
    final bool isFailed = currentStatus.contains("CANCELLED") || currentStatus.contains("FAILED");
    final Color activeTrackingColor = isFailed ? Colors.red : primaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Order Details', 
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER SUMMARY CARD
            _buildHeaderCard(isPickup, activeTrackingColor),

            const SizedBox(height: 25),

            // 2. DYNAMIC VERTICAL TRACKER (MATCHES OUTSIDE PROGRESS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                isFailed ? "ORDER TERMINATED" : "SHIPMENT TRACKING", 
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w900, 
                  color: isFailed ? Colors.red : Colors.grey[400],
                  letterSpacing: 1.2
                )
              ),
            ),
            const SizedBox(height: 15),
            _buildVerticalTracker(activeTrackingColor, isFailed),

            const SizedBox(height: 30),

            // 3. LOCATION INFO
            _buildSectionHeader("Delivery Information"),
            _buildInfoBox(
              isPickup ? Icons.storefront_rounded : Icons.location_on_rounded,
              isPickup ? "Pickup Location" : "Shipping To",
              isPickup ? _storeAddress : widget.order.shippingAddress,
              isPickup ? primaryColor : Colors.blueAccent,
            ),

            const SizedBox(height: 30),

            // 4. ITEMS LIST
            _buildSectionHeader("Items Manifest"),
            ...widget.order.items.map((item) => _buildProductTile(item)).toList(),

            const SizedBox(height: 30),

            // 5. PAYMENT FINAL SUMMARY
            _buildPaymentSummary(subtotal, primaryColor, isFailed),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isPickup, Color activeColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER #${widget.order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  isPickup ? "STORE PICKUP" : "HOME DELIVERY",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(isPickup ? Icons.access_time : Icons.local_shipping, color: Colors.white60, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPickup 
                    ? "Available for pickup: ${_getDeliveryEstimate(widget.order.orderDate.toDate())}"
                    : "Estimated Arrival: ${_getDeliveryEstimate(widget.order.orderDate.toDate())}",
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalTracker(Color activeColor, bool isFailed) {
    final List<dynamic> milestones = widget.order.trackingMilestones;
    final int currentStep = widget.order.currentStep;

    return Container(
      padding: const EdgeInsets.all(25),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: milestones.length,
        itemBuilder: (ctx, index) {
          bool isCompleted = index <= currentStep;
          bool isCurrent = index == currentStep;
          bool isLast = index == milestones.length - 1;
          bool isStepFailure = isFailed && isCurrent;

          return IntrinsicHeight(
            child: Row(
              children: [
                // Vertical Line and Animated Dot Column
                Column(
                  children: [
                    ScaleTransition(
                      scale: isCurrent ? _animation : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: isStepFailure ? Colors.red : (isCompleted ? activeColor : Colors.white),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted ? activeColor : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: isCompleted 
                          ? Icon(isStepFailure ? Icons.close : Icons.check, size: 14, color: Colors.white) 
                          : null,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: index < currentStep ? activeColor : Colors.grey.shade200,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                // Milestone Text Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        milestones[index].toString().toUpperCase(),
                        style: TextStyle(
                          fontWeight: isCompleted ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 13,
                          color: isStepFailure ? Colors.red : (isCompleted ? Colors.black87 : Colors.grey[400]),
                        ),
                      ),
                      if (isCurrent)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isStepFailure ? "Terminated on ${DateFormat('MMM dd').format(widget.order.orderDate.toDate())}"
                                         : "Updated at ${DateFormat('hh:mm a').format(widget.order.orderDate.toDate())}",
                            style: TextStyle(color: activeColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 35),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductTile(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              width: 65, height: 65, fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("Quantity: ${item.quantity}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text("₦${(item.price * item.quantity).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(double subtotal, Color primaryColor, bool isFailed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        children: [
          _row("Subtotal", "₦${subtotal.toStringAsFixed(0)}", Colors.black87),
          const SizedBox(height: 12),
          _row("Delivery Fee", "₦${widget.order.deliveryFee.toStringAsFixed(0)}", Colors.black87),
          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("GRAND TOTAL", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              Text(
                "₦${widget.order.totalAmount.toStringAsFixed(0)}",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isFailed ? Colors.red : primaryColor),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _row(String label, String val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  Widget _buildInfoBox(IconData icon, String title, String val, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 25, bottom: 15),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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