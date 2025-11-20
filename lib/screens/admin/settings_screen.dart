import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Settings state
  bool _enableNotifications = true;
  bool _enableLocationTracking = true;
  bool _enableAttendanceTracking = true;
  String _defaultMapType = 'normal';
  int _locationUpdateInterval = 10;
  int _attendanceGracePeriod = 15;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('settings')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .single();

      setState(() {
        _enableNotifications = response['enable_notifications'] ?? true;
        _enableLocationTracking = response['enable_location_tracking'] ?? true;
        _enableAttendanceTracking = response['enable_attendance_tracking'] ?? true;
        _defaultMapType = response['default_map_type'] ?? 'normal';
        _locationUpdateInterval = response['location_update_interval'] ?? 10;
        _attendanceGracePeriod = response['attendance_grace_period'] ?? 15;
      });
        } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load settings: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() => _isLoading = true);

      final settings = {
        'enable_notifications': _enableNotifications,
        'enable_location_tracking': _enableLocationTracking,
        'enable_attendance_tracking': _enableAttendanceTracking,
        'default_map_type': _defaultMapType,
        'location_update_interval': _locationUpdateInterval,
        'attendance_grace_period': _attendanceGracePeriod,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('settings')
          .upsert(settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
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
        title: const Text('System Settings'),
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
                        onPressed: _loadSettings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        'Notifications',
                        [
                          SwitchListTile(
                            title: const Text('Enable Push Notifications'),
                            subtitle: const Text('Allow sending notifications to users'),
                            value: _enableNotifications,
                            onChanged: (value) {
                              setState(() => _enableNotifications = value);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        'Location Tracking',
                        [
                          SwitchListTile(
                            title: const Text('Enable Location Tracking'),
                            subtitle: const Text('Track bus locations in real-time'),
                            value: _enableLocationTracking,
                            onChanged: (value) {
                              setState(() => _enableLocationTracking = value);
                            },
                          ),
                          ListTile(
                            title: const Text('Location Update Interval'),
                            subtitle: Text('$_locationUpdateInterval seconds'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _locationUpdateInterval > 15
                                      ? () {
                                          setState(() {
                                            _locationUpdateInterval -= 15;
                                          });
                                        }
                                      : null,
                                ),
                                Text('$_locationUpdateInterval'),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _locationUpdateInterval < 300
                                      ? () {
                                          setState(() {
                                            _locationUpdateInterval += 15;
                                          });
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          ListTile(
                            title: const Text('Default Map Type'),
                            subtitle: const Text('Choose the default map view'),
                            trailing: DropdownButton<String>(
                              value: _defaultMapType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'normal',
                                  child: Text('Normal'),
                                ),
                                DropdownMenuItem(
                                  value: 'satellite',
                                  child: Text('Satellite'),
                                ),
                                DropdownMenuItem(
                                  value: 'terrain',
                                  child: Text('Terrain'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _defaultMapType = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        'Attendance',
                        [
                          SwitchListTile(
                            title: const Text('Enable Attendance Tracking'),
                            subtitle: const Text('Track student attendance'),
                            value: _enableAttendanceTracking,
                            onChanged: (value) {
                              setState(() => _enableAttendanceTracking = value);
                            },
                          ),
                          ListTile(
                            title: const Text('Grace Period'),
                            subtitle: Text('$_attendanceGracePeriod minutes'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _attendanceGracePeriod > 5
                                      ? () {
                                          setState(() {
                                            _attendanceGracePeriod -= 5;
                                          });
                                        }
                                      : null,
                                ),
                                Text('$_attendanceGracePeriod'),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _attendanceGracePeriod < 60
                                      ? () {
                                          setState(() {
                                            _attendanceGracePeriod += 5;
                                          });
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Save Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
} 