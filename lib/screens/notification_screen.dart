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
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Notifications", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: "Clear All",
            onPressed: () => _confirmClear(context, service),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        // Listen to the real-time stream from NotificationService
        stream: service.getNotifications().timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            debugPrint("Notification stream timed out.");
          },
        ),
        builder: (context, snapshot) {
          
          // 1. LOADING STATE
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoader(size: 60));
          }

          // 2. ERROR STATE (Commonly Firestore Indexing)
          if (snapshot.hasError) {
             return Center(
               child: Padding(
                 padding: const EdgeInsets.all(30.0),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.redAccent),
                     const SizedBox(height: 16),
                     const Text(
                       "Error loading notifications",
                       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                     ),
                     const SizedBox(height: 8),
                     const Text(
                       "Please ensure your Firestore Index for the 'broadcasts' collection is enabled. Check the debug console for the creation link.",
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey, fontSize: 13),
                     ),
                     const SizedBox(height: 20),
                     TextButton(
                       onPressed: () => Navigator.of(context).pushReplacement(
                         MaterialPageRoute(builder: (_) => const NotificationScreen())
                       ),
                       child: const Text("RETRY"),
                     )
                   ],
                 ),
               ),
             );
          }

          // 3. EMPTY STATE
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data!;

          // 4. NOTIFICATION LIST
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear all?"),
        content: const Text("This will permanently delete your notification history."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () { 
              service.clearAll(); 
              Navigator.pop(ctx); 
            }, 
            child: const Text("DELETE ALL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)
              ]
            ),
            child: Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey[300]),
          ),
          const SizedBox(height: 25),
          const Text(
            "Nothing here yet", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
          ),
          const SizedBox(height: 8),
          const Text(
            "New updates and alerts will appear here.", 
            style: TextStyle(color: Colors.grey, fontSize: 14)
          ),
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
    // Determine the color based on type
    final Color typeColor = _getColor(note.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // Subtle highlight for unread messages
        color: note.isRead ? Colors.white : const Color(0xFFFFF9F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: note.isRead ? Colors.transparent : Colors.orange.shade100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: () {
            if (!note.isRead) {
              service.markAsRead(note.id);
            }
            // Navigate based on type if needed
            // if (note.type == 'order') Navigator.push(...)
          },
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getIcon(note.type), color: typeColor, size: 22),
          ),
          title: Text(
            note.title, 
            style: TextStyle(
              fontWeight: note.isRead ? FontWeight.w600 : FontWeight.w900, 
              fontSize: 15,
              color: Colors.black87
            )
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                note.body, 
                style: TextStyle(
                  color: Colors.grey[700], 
                  fontSize: 13,
                  height: 1.3
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(note.timestamp), 
                    style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ],
          ),
          // Small red dot for unread
          trailing: !note.isRead 
              ? const CircleAvatar(radius: 4, backgroundColor: Colors.orange) 
              : null,
        ),
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'order': return Icons.local_shipping_rounded;
      case 'promo': return Icons.local_offer_rounded;
      case 'system': return Icons.settings_suggest_rounded;
      case 'home': return Icons.home_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  Color _getColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'order': return Colors.blue;
      case 'promo': return Colors.green;
      case 'system': return Colors.orange;
      case 'home': return Colors.indigo;
      default: return Colors.orange;
    }
  }
}