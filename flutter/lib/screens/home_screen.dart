import 'package:flutter/material.dart';

import 'create_school_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Hero header ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.badge_outlined, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Attendor',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Smart RFID attendance for schools',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),

                      // What is Attendor card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: cs.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'What is Attendor?',
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Attendor runs an attendance kiosk at the door of every class. '
                                'Students tap their RFID card on the reader and their presence is '
                                'recorded automatically in the school\'s timetable windows '
                                '(e.g. the morning and afternoon entry periods). No registers, '
                                'no roll calls. Each class device is linked permanently to its '
                                'class using a QR code / pairing code and its hardware MAC address.',
                                style: TextStyle(height: 1.5, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Feature cards
                      Text(
                        'Features',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _FeatureCard(
                        icon: Icons.sensors,
                        title: 'Class devices',
                        text: 'ESP8266 + RFID readers show live status on each classroom door.',
                      ),
                      _FeatureCard(
                        icon: Icons.history_toggle_off,
                        title: 'Automatic attendance',
                        text: 'Presence is counted in the configured AM / PM windows.',
                      ),
                      _FeatureCard(
                        icon: Icons.qr_code_2,
                        title: 'Easy device pairing',
                        text: 'Scan the device\'s screen QR to link it to a class forever.',
                      ),
                      _FeatureCard(
                        icon: Icons.verified_user,
                        title: 'Three roles',
                        text: 'Admins run the school, teachers run their class, students join with an entry code.',
                      ),
                      const SizedBox(height: 28),

                      // ── Action buttons ──
                      FilledButton.icon(
                        onPressed: () => _push(context, const LoginScreen()),
                        icon: const Icon(Icons.login_rounded),
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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _FeatureCard({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.onPrimaryContainer, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: TextStyle(height: 1.4, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
