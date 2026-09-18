import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/db_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _isTeacher = false;

  Future<void> _register() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_isTeacher) {
      final db = context.read<DbService>();
      final error = await db.registerTeacherWithCode(
        code: _code.text,
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.isEmpty ? null : error;
        });
        if (error.isEmpty) {
          await context.read<AuthService>().loadMeta();
          if (mounted) Navigator.of(context).pop();
        }
      }
    } else {
      final auth = context.read<AuthService>();
      final error = await auth.registerStudent(
        code: _code.text,
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.isEmpty ? null : error;
        });
        if (error.isEmpty) {
          await auth.loadMeta();
          if (mounted) Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Join Attendor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(_isTeacher ? Icons.school_outlined : Icons.vpn_key_rounded, size: 36, color: cs.onPrimaryContainer),
                ),
                Text(
                  _isTeacher ? 'Register as a teacher' : 'Enter your entry code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _isTeacher
                      ? 'Ask your admin for a teacher join code, then fill in your details below.'
                      : 'Ask your teacher or admin for the class entry code, then fill in your details below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                // Role toggle
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isTeacher = false;
                            _error = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isTeacher ? cs.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outlined, size: 18, color: !_isTeacher ? cs.onPrimary : cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text('Student', style: TextStyle(fontWeight: FontWeight.w600, color: !_isTeacher ? cs.onPrimary : cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isTeacher = true;
                            _error = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isTeacher ? cs.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined, size: 18, color: _isTeacher ? cs.onPrimary : cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text('Teacher', style: TextStyle(fontWeight: FontWeight.w600, color: _isTeacher ? cs.onPrimary : cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _code,
                  decoration: InputDecoration(
                    labelText: _isTeacher ? 'Teacher join code' : 'Entry code',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    hintText: 'e.g. ABC123',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outlined)),
                ),
                const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
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
                        Expanded(child: Text(_error!, style: TextStyle(color: cs.onErrorContainer, fontSize: 13))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _busy ? null : _register,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isTeacher ? 'Register as teacher' : 'Register & join class'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
