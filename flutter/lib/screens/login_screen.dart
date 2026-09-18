import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'create_school_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().login(_email.text, _password.text);
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Login failed. Check your credentials.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.login_rounded, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to your Attendor account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outlined)),
                    obscureText: true,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: cs.onErrorContainer))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Register with entry code'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateSchoolScreen())),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Create a school'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
