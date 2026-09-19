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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Attendor',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _push(context, const LoginScreen()),
            child: const Text('Sign in'),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: () => _push(context, const CreateSchoolScreen()),
              child: const Text('New School'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero Section ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1E3A8A), const Color(0xFF2563EB), const Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 24,
                vertical: isDesktop ? 64 : 40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sensors_rounded, color: Colors.amberAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'ESP32 & ESP8266 RFID Attendance Cloud',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'School Attendance,\nAutomated at the Door',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 44 : 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Classroom RFID tap readers with instant OLED screen feedback. '
                        'Separate access codes for students and teachers for effortless self-onboarding.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 15,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1D4ED8),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            onPressed: () => _push(context, const RegisterScreen(initialIsTeacher: false)),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Join as Student (Entry Code)'),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            onPressed: () => _push(context, const RegisterScreen(initialIsTeacher: true)),
                            icon: const Icon(Icons.school_rounded),
                            label: const Text('Join as Teacher (Teacher Code)'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            onPressed: () => _push(context, const LoginScreen()),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Admin / Sign in'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Portal Entry Cards ──
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 20,
                vertical: 36,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Your Portal',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to your dashboard or join a class using your designated code',
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 700;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildStudentCard(context)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTeacherCard(context)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildAdminCard(context)),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildStudentCard(context),
                              const SizedBox(height: 16),
                              _buildTeacherCard(context),
                              const SizedBox(height: 16),
                              _buildAdminCard(context),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 48),

                    // ── How It Works Grid ──
                    Text(
                      'Hardware & Cloud Architecture',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildArchitectureSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Student Portal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use your class entry code to register. Tap your RFID badge at the door reader and track your daily AM/PM attendance.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => _push(context, const RegisterScreen(initialIsTeacher: false)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Student Sign Up'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school_rounded, color: Color(0xFFD97706), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Teacher Portal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use your teacher join code to claim assigned classes. View live classroom roster, close attendance sessions, and pair student RFID badges.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => _push(context, const RegisterScreen(initialIsTeacher: true)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Teacher Sign Up'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF475569), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'School Admin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage classes, generate access codes, pair ESP32/ESP8266 devices via MAC address, and oversee school-wide attendance records.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _push(context, const LoginScreen()),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Admin Login'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchitectureSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildArchRow(
              icon: Icons.credit_card_rounded,
              title: '1. Student Taps RFID Card on Reader',
              desc: 'RC522 reads 13.56 MHz card UID. ESP32/ESP8266 shows "Scanning..." on the OLED screen and sends to RTDB.',
            ),
            const Divider(height: 28),
            _buildArchRow(
              icon: Icons.cloud_sync_rounded,
              title: '2. Firebase RTDB & Worker Verification',
              desc: 'Tag UID is matched to the enrolled student. AM/PM timetable window and session status are checked.',
            ),
            const Divider(height: 28),
            _buildArchRow(
              icon: Icons.tv_rounded,
              title: '3. Instant Hardware Feedback & Live Roster',
              desc: 'OLED screen instantly displays student name and "Present". Teacher dashboard roster updates in real time.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchRow({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1D4ED8), size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: Color(0xFF64748B), height: 1.4, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
