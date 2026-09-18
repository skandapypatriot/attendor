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
        title: 'Attendor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 12),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

    // Not logged in -> show home/login
    if (auth.user == null) {
      return const HomeScreen();
    }

    // Logged in but meta not loaded yet -> show loading
    if (auth.meta == null) {
      return const _LoadingMetaScreen();
    }

    // Meta loaded -> route to correct screen
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
      if (auth.meta == null && _attempts < 10) {
        _retry();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_top_rounded, size: 36, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'Loading your account...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (_attempts >= 10) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.read<AuthService>().logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
