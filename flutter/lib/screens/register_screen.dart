import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/db_service.dart';

class RegisterScreen extends StatefulWidget {
  final bool initialIsTeacher;

  const RegisterScreen({super.key, this.initialIsTeacher = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late bool _isTeacher;
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isTeacher = widget.initialIsTeacher;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (code.isEmpty || name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters long.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final db = context.read<DbService>();

      String err = '';
      if (_isTeacher) {
        err = await auth.registerTeacher(
          code: code,
          name: name,
          email: email,
          password: password,
          db: db,
        );
      } else {
        err = await auth.registerStudent(
          code: code,
          name: name,
          email: email,
          password: password,
          db: db,
        );
      }

      if (!mounted) return;

      if (err.isNotEmpty) {
        setState(() {
          _busy = false;
          _error = err;
        });
      } else {
        // Success! Pop back so RoleGate routes to appropriate dashboard
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _isTeacher ? 'Teacher Registration' : 'Student Registration',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(32),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Role Toggle Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _busy ? null : () => setState(() {
                              _isTeacher = false;
                              _error = null;
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isTeacher ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isTeacher
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: !_isTeacher ? cs.primary : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Student Portal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !_isTeacher ? cs.primary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _busy ? null : () => setState(() {
                              _isTeacher = true;
                              _error = null;
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isTeacher ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isTeacher
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    size: 18,
                                    color: _isTeacher ? Colors.amber.shade800 : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Teacher Portal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isTeacher ? Colors.amber.shade800 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Header icon & description
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isTeacher ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isTeacher ? Icons.assignment_ind_rounded : Icons.vpn_key_rounded,
                        color: _isTeacher ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isTeacher ? 'Join as Class Teacher' : 'Join as Student',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isTeacher
                      ? 'Enter the Teacher Join Code provided by your school admin'
                      : 'Enter the Class Student Entry Code provided by your teacher',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),

                  const SizedBox(height: 24),

                  // Code Field
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: _isTeacher ? 'Teacher Join Code' : 'Student Entry Code',
                      hintText: _isTeacher ? 'e.g. TCH-A8B9C' : 'e.g. STU-K2M9P',
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name Field
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  // Error banner
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Submit Button
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _isTeacher ? const Color(0xFFD97706) : cs.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isTeacher ? 'Register & Claim Class' : 'Register & Join Class'),
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
