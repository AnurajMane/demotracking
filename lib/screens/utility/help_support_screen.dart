import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@demotracking.com',
      queryParameters: {
        'subject': 'Support Request',
        'body': 'Please describe your issue:',
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneLaunchUri = Uri(
      scheme: 'tel',
      path: '+1234567890',
    );

    if (await canLaunchUrl(phoneLaunchUri)) {
      await launchUrl(phoneLaunchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('How do I track my bus?'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'To track your bus, go to the Live Tracking screen and select your bus from the list. The map will show the real-time location of your bus.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('How do I report an issue?'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'You can report issues through the Incident Report screen. Fill in the details and submit the report. Our support team will review and respond to your report.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('How do I update my profile?'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Go to the Profile screen and tap the edit icon. You can update your information and profile picture there.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Contact Section
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email Support'),
                subtitle: const Text('support@demotracking.com'),
                onTap: _launchEmail,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone Support'),
                subtitle: const Text('+1 (234) 567-890'),
                onTap: _launchPhone,
              ),
            ),
            const SizedBox(height: 32),
            // App Information
            const Text(
              'App Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.update),
                title: const Text('Last Updated'),
                subtitle: const Text('March 2024'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 