import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedRecipientType = 'all';
  List<String> _selectedRecipients = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Available recipients based on type
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    try {
      setState(() => _isLoading = true);

      // Load drivers
      final driversResponse = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'driver');
      _drivers = List<Map<String, dynamic>>.from(driversResponse);

      // Load parents
      final parentsResponse = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'parent');
      _parents = List<Map<String, dynamic>>.from(parentsResponse);

      // Load students
      final studentsResponse = await _supabase
          .from('students')
          .select('*, profiles!parent_id(*)');
      _students = List<Map<String, dynamic>>.from(studentsResponse);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load recipients: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      // Create notification record
      final notification = {
        'title': _titleController.text,
        'message': _messageController.text,
        'recipient_type': _selectedRecipientType,
        'recipient_ids': _selectedRecipients,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'sent',
      };

      await _supabase.from('notifications').insert(notification);

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedRecipientType = 'all';
        _selectedRecipients = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send notification: $e')),
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
        title: const Text('Send Notifications'),
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
                        onPressed: _loadRecipients,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Notification Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a message';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Recipient Type',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'all',
                              label: Text('All Users'),
                              icon: Icon(Icons.people),
                            ),
                            ButtonSegment(
                              value: 'drivers',
                              label: Text('Drivers'),
                              icon: Icon(Icons.directions_bus),
                            ),
                            ButtonSegment(
                              value: 'parents',
                              label: Text('Parents'),
                              icon: Icon(Icons.family_restroom),
                            ),
                            ButtonSegment(
                              value: 'students',
                              label: Text('Students'),
                              icon: Icon(Icons.school),
                            ),
                          ],
                          selected: {_selectedRecipientType},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _selectedRecipientType = newSelection.first;
                              _selectedRecipients = [];
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_selectedRecipientType != 'all') ...[
                          Text(
                            'Select Recipients',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _getRecipientList().length,
                              itemBuilder: (context, index) {
                                final recipient = _getRecipientList()[index];
                                return CheckboxListTile(
                                  title: Text(recipient['name'] ?? recipient['full_name']),
                                  value: _selectedRecipients.contains(recipient['id']),
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedRecipients.add(recipient['id']);
                                      } else {
                                        _selectedRecipients.remove(recipient['id']);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendNotification,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : const Text('Send Notification'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  List<Map<String, dynamic>> _getRecipientList() {
    switch (_selectedRecipientType) {
      case 'drivers':
        return _drivers;
      case 'parents':
        return _parents;
      case 'students':
        return _students;
      default:
        return [];
    }
  }
} 