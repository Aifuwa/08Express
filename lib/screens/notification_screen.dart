import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eight_express/models/app_notification.dart';
import 'package:eight_express/services/notification_service.dart';
import 'package:eight_express/widgets/custom_loader.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            onPressed: () => _confirmClear(context, service),
          )
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        // Added Timeout to detect Indexing issues
        stream: service.getNotifications().timeout(const Duration(seconds: 5)),
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoader(size: 60));
          }

          // Error Handling (Usually Indexing issue)
          if (snapshot.hasError) {
             // Check debug console for the link to create index
             return Center(
               child: Padding(
                 padding: const EdgeInsets.all(20.0),
                 child: Text(
                   "Error loading notifications.\n\nCheck your debug console for a Firebase Index link, or try again later.", 
                   textAlign: TextAlign.center,
                   style: TextStyle(color: Colors.red.shade300),
                 ),
               ),
             );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final note = notifications[index];
              return _NotificationTile(note: note, service: service);
            },
          );
        },
      ),
    );
  }

  void _confirmClear(BuildContext context, NotificationService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear all?"),
        content: const Text("This will permanently delete your notification history."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(onPressed: () { service.clearAll(); Navigator.pop(ctx); }, child: const Text("DELETE ALL", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text("All caught up!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("New updates will appear here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification note;
  final NotificationService service;
  const _NotificationTile({required this.note, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: note.isRead ? Colors.white : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: note.isRead ? Colors.transparent : Colors.orange.shade100),
      ),
      child: ListTile(
        onTap: () => service.markAsRead(note.id),
        leading: CircleAvatar(
          backgroundColor: _getColor(note.type).withOpacity(0.1),
          child: Icon(_getIcon(note.type), color: _getColor(note.type), size: 20),
        ),
        title: Text(note.title, style: TextStyle(fontWeight: note.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(note.body, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              // Safe timestamp formatting
              DateFormat('MMM dd, hh:mm a').format(note.timestamp), 
              style: const TextStyle(fontSize: 11, color: Colors.grey)
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'order': return Icons.local_shipping_rounded;
      case 'promo': return Icons.local_offer_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  Color _getColor(String? type) {
    switch (type) {
      case 'order': return Colors.blue;
      case 'promo': return Colors.green;
      default: return Colors.orange;
    }
  }
}