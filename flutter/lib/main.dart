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
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6FEB)), useMaterial3: true),
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

    if (auth.user == null) {
      return const HomeScreen();
    }
    if (auth.meta == null) {
      return const WaitingScreen();
    }
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

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  void _poll() {
    final auth = context.read<AuthService>();
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      await auth.loadMeta();
      setState(() => _ticks++);
      if (auth.meta == null && _ticks < 20) {
        _poll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final registered = auth.user != null && auth.user!.email != null;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(registered ? 'Adding you to the class...' : 'Loading your role...'),
            if (_ticks >= 20) const SizedBox(height: 8),
            if (_ticks >= 20)
              TextButton(
                onPressed: () => context.read<AuthService>().logout(),
                child: const Text('Logout'),
              ),
          ],
        ),
      ),
    );
  }
}