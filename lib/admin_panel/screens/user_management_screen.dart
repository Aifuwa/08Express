// eight_express/lib/admin_panel/screens/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:eight_express/admin_panel/services/admin_firestore_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AdminFirestoreService _adminService = AdminFirestoreService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adminService.getUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('No users found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(user['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? 'No Email'),
                            Text('Registered: ${user['registrationDate']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Admin:'),
                            Switch(
                              value: user['isAdmin'] ?? false,
                              onChanged: (bool newValue) async {
                                await _updateUserAdminStatus(user['id'], newValue, user['email']);
                              },
                            ),
                            IconButton( // User deletion via Cloud Function
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteUser(user),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserAdminStatus(String userId, bool isAdmin, String userEmail) async {
    try {
      await _adminService.updateUserRole(userId, isAdmin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $userEmail admin status updated to $isAdmin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update admin status: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete User'),
        content: Text('Are you sure you want to delete user "${user['email']}"? This action cannot be undone and should be done via a Cloud Function.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && user['id'] != null) {
      try {
        await _adminService.deleteUserByAdmin(user['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deletion initiated for user ${user['email']}.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: $e')),
          );
        }
      }
    }
  }
}