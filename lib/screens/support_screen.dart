import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/services/support_service.dart';
import 'package:eight_express/widgets/custom_loader.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key}); // Ensure this line exists

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  final List<String> _categories = [
    "Order Issue",
    "Payment Verification",
    "Delivery Delay",
    "Product Quality",
    "Account/Login Help",
    "Other"
  ];
  String _selectedCategory = "Order Issue";

  Future<void> _submitTicket() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please describe your issue")),
      );
      return;
    }

    setState(() => _isSending = true);

    final userProv = Provider.of<UserProvider>(context, listen: false);
    
    try {
      await SupportService().sendTicket(
        user: userProv.appUser!,
        subject: _selectedCategory,
        message: _messageController.text.trim(),
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text("Message Sent", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 10),
            const Text(
              "Our Resolution Team has received your request. We will get back to you shortly.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color orange = Color(0xFFFE7F2D);
    const Color navy = Color(0xFF0D47A1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Support Hub", style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "How can we help you?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navy),
            ),
            const SizedBox(height: 8),
            const Text(
              "Send a message to our team and we'll resolve your issue as fast as possible.",
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 35),
            
            const Text("ISSUE CATEGORY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() => _selectedCategory = newValue!);
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text("YOUR MESSAGE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Describe the situation in detail...",
                fillColor: Colors.white,
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: orange, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _isSending ? null : _submitTicket,
                child: _isSending 
                  ? const CustomLoader(size: 30) 
                  : const Text(
                      "SEND TO RESOLUTION TEAM", 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}