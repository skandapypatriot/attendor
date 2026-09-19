import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models.dart';
import 'screens/admin_screen.dart';
import 'screens/home_screen.dart';
import 'screens/student_screen.dart';
import 'screens/teacher_screen.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  runApp(const AttendApp());
}

class AttendApp extends StatelessWidget {
  const AttendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => DbService()),
      ],
      child: MaterialApp(
        title: 'Attendor — RFID Attendance System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1D4ED8), // Vibrant Royal Blue
            brightness: Brightness.light,
            surface: const Color(0xFFF8FAFC),
          ),
          scaffoldBackgroundColor: const Color(0xFFF1F5F9),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            margin: const EdgeInsets.only(bottom: 12),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        home: const RoleGate(),
      ),
    );
  }
}

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Initial check before auth is evaluated
    if (!auth.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Not logged in -> show Home page with portal links
    if (auth.user == null) {
      return const HomeScreen();
    }

    // Logged in but meta loading/recovering -> show clean loading indicator
    if (auth.meta == null) {
      return const _LoadingMetaScreen();
    }

    // Meta loaded -> route dynamically to appropriate dashboard
    switch (auth.meta!.role) {
      case Role.admin:
        return const AdminScreen();
      case Role.teacher:
        return const TeacherScreen();
      case Role.student:
        return const StudentScreen();
    }
  }
}

class _LoadingMetaScreen extends StatefulWidget {
  const _LoadingMetaScreen();

  @override
  State<_LoadingMetaScreen> createState() => _LoadingMetaScreenState();
}

class _LoadingMetaScreenState extends State<_LoadingMetaScreen> {
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _retry();
  }

  void _retry() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      await auth.loadMeta();
      if (!mounted) return;
      setState(() => _attempts++);
      if (auth.meta == null && _attempts < 6) {
        _retry();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school_rounded, size: 32, color: cs.primary),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 20),
              Text(
                'Opening Attendor...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Syncing permissions & class roster',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (_attempts >= 4) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.read<AuthService>().logout(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Back to Sign In'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
