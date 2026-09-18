import 'package:flutter/material.dart';

import 'create_school_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.badge_outlined, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('Attendor',
                      textAlign: TextAlign.center, style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text('Smart RFID attendance for schools',
                      textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What is Attendor?', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          const Text(
                            'Attendor runs an attendance kiosk at the door of every class. '
                            'Students tap their RFID card on the reader and their presence is '
                            'recorded automatically in the school\'s timetable windows '
                            '(e.g. the morning and afternoon entry periods). No registers, '
                            'no roll calls. Each class device is linked permanently to its '
                            'class using a QR code / pairing code and its hardware MAC address.',
                            style: TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FeatureRow(
                    icon: Icons.sensors,
                    title: 'Class devices',
                    text: 'ESP8266 + RFID readers show live status on each classroom door.',
                  ),
                  const _FeatureRow(
                    icon: Icons.history_toggle_off,
                    title: 'Automatic attendance',
                    text: 'Presence is counted in the configured AM / PM windows.',
                  ),
                  const _FeatureRow(
                    icon: Icons.qr_code_2,
                    title: 'Easy device pairing',
                    text: 'Scan the device\'s screen QR to link it to a class forever.',
                  ),
                  const _FeatureRow(
                    icon: Icons.verified_user,
                    title: 'Three roles',
                    text: 'Admins run the school, teachers run their class, students join with an entry code.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _push(context, const LoginScreen()),
                    icon: const Icon(Icons.login),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Sign in'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _push(context, const CreateSchoolScreen()),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Create a school'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _push(context, const RegisterScreen()),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Join as a student (with entry code)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _FeatureRow({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}