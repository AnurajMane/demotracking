import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageBusesScreen extends StatefulWidget {
  const ManageBusesScreen({super.key});

  @override
  State<ManageBusesScreen> createState() => _ManageBusesScreenState();
}

class _ManageBusesScreenState extends State<ManageBusesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _busNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _buses = [];
  Map<String, dynamic>? _editingBus;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  @override
  void dispose() {
    _busNumberController.dispose();
    _capacityController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadBuses() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('buses')
          .select()
          .order('bus_number');

      setState(() {
        _buses = List<Map<String, dynamic>>.from(response);
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load buses: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _editingBus = null;
    _busNumberController.clear();
    _capacityController.clear();
    _modelController.clear();
    _yearController.clear();
  }

  Future<void> _saveBus() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final bus = {
        'bus_number': _busNumberController.text,
        'capacity': int.parse(_capacityController.text),
        'model': _modelController.text,
        'year': int.parse(_yearController.text),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_editingBus == null) {
        // Create new bus
        await _supabase.from('buses').insert(bus);
      } else {
        // Update existing bus
        await _supabase
            .from('buses')
            .update(bus)
            .eq('id', _editingBus!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        _resetForm();
        _loadBuses();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingBus == null
                  ? 'Bus added successfully'
                  : 'Bus updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save bus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBus(Map<String, dynamic> bus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bus'),
        content: Text('Are you sure you want to delete bus ${bus['bus_number']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      await _supabase
          .from('buses')
          .delete()
          .eq('id', bus['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBuses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete bus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBusForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_editingBus == null ? 'Add New Bus' : 'Edit Bus'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _busNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Bus Number *',
                    border: OutlineInputBorder(),
                    helperText: 'Required',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a bus number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Capacity *',
                    border: OutlineInputBorder(),
                    helperText: 'Required',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the capacity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                    helperText: 'Optional',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _yearController,
                  decoration: const InputDecoration(
                    labelText: 'Year *',
                    border: OutlineInputBorder(),
                    helperText: 'Required',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the year';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid year';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveBus,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_editingBus == null ? 'Add Bus' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  void _editBus(Map<String, dynamic> bus) {
    _editingBus = bus;
    _busNumberController.text = bus['bus_number'];
    _capacityController.text = bus['capacity'].toString();
    _modelController.text = bus['model'] ?? '';
    _yearController.text = bus['year'].toString();
    _showBusForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Buses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBuses,
          ),
        ],
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
                        onPressed: _loadBuses,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.directions_bus_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No buses found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              _resetForm();
                              _showBusForm();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Bus'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _buses.length,
                      itemBuilder: (context, index) {
                        final bus = _buses[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: const Icon(
                              Icons.directions_bus,
                              size: 36,
                            ),
                            title: Text(
                              bus['bus_number'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Capacity: ${bus['capacity']} seats'),
                                if (bus['model'] != null)
                                  Text('Model: ${bus['model']}'),
                                Text('Year: ${bus['year']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editBus(bus),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  onPressed: () => _deleteBus(bus),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _resetForm();
          _showBusForm();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 