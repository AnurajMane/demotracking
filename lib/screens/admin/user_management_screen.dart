import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedRole = 'all';

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _filterUsers();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load users: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    if (_selectedRole == 'all') {
      _filteredUsers = _users;
    } else {
      _filteredUsers = _users.where((user) => user['role'] == _selectedRole).toList();
    }
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    try {
      setState(() => _isLoading = true);

      final newStatus = user['status'] == 'active' ? 'inactive' : 'active';
      await _supabase
          .from('profiles')
          .update({'status': newStatus})
          .eq('id', user['id']);

      // Update local state
      setState(() {
        final index = _users.indexWhere((u) => u['id'] == user['id']);
        if (index != -1) {
          _users[index]['status'] = newStatus;
          _filterUsers();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${newStatus == 'active' ? 'activated' : 'deactivated'} successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['full_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      // Delete user's profile
      await _supabase
          .from('profiles')
          .delete()
          .eq('id', user['id']);

      // Delete user's auth account
      await _supabase.auth.admin.deleteUser(user['id']);

      // Update local state
      setState(() {
        _users.removeWhere((u) => u['id'] == user['id']);
        _filterUsers();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'all',
                            label: Text('All Users'),
                            icon: Icon(Icons.people),
                          ),
                          ButtonSegment(
                            value: 'admin',
                            label: Text('Admins'),
                            icon: Icon(Icons.admin_panel_settings),
                          ),
                          ButtonSegment(
                            value: 'driver',
                            label: Text('Drivers'),
                            icon: Icon(Icons.directions_bus),
                          ),
                          ButtonSegment(
                            value: 'parent',
                            label: Text('Parents'),
                            icon: Icon(Icons.family_restroom),
                          ),
                        ],
                        selected: {_selectedRole},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedRole = newSelection.first;
                            _filterUsers();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  user['full_name'][0].toUpperCase(),
                                ),
                              ),
                              title: Text(user['full_name']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email']),
                                  Text(
                                    'Role: ${user['role']}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    'Status: ${user['status']}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      user['status'] == 'active'
                                          ? Icons.toggle_on
                                          : Icons.toggle_off,
                                      color: user['status'] == 'active'
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    onPressed: () => _toggleUserStatus(user),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () => _deleteUser(user),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
} 