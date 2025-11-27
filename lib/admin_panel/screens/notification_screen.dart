// eight_express/lib/admin_panel/screens/notification_screen.dart

import 'package:flutter/material.dart';
import 'package:eight_express/admin_panel/services/admin_firestore_service.dart';
import 'package:eight_express/admin_panel/widgets/custom_admin_button.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final AdminFirestoreService _adminService = AdminFirestoreService();
  bool _isLoading = false;

  Future<void> _sendNotification() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _adminService.sendPushNotification(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
          // You can add more data here, e.g., target user ID, deep link path
          data: {'screen': 'home', 'deeplink': '/product/123'}, // Example additional data
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification send initiated successfully!')),
          );
          _titleController.clear();
          _bodyController.clear();
          _imageUrlController.clear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send notification: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Container(
          width: 600, // Constrain width for a web form
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send Push Notification',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Notification Title', prefixIcon: Icon(Icons.title)),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: 'Notification Body', prefixIcon: Icon(Icons.message)),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a message body';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(labelText: 'Optional Image URL', prefixIcon: Icon(Icons.image)),
                ),
                const SizedBox(height: 30),
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : CustomAdminButton(
                          text: 'Send Notification',
                          icon: Icons.send,
                          onPressed: _sendNotification,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }
}