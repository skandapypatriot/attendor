import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/db_service.dart';

class CreateSchoolScreen extends StatefulWidget {
  const CreateSchoolScreen({super.key});

  @override
  State<CreateSchoolScreen> createState() => _CreateSchoolScreenState();
}

class _CreateSchoolScreenState extends State<CreateSchoolScreen> {
  final _schoolName = TextEditingController();
  final _adminName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final db = context.read<DbService>();
    final auth = context.read<AuthService>();
    try {
      await db.createSchool(
            schoolName: _schoolName.text,
            adminName: _adminName.text,
            email: _email.text,
            password: _password.text,
          );
      await auth.loadMeta();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not create the school. ${e.toString()}'.replaceAll('PlatformException(', '');
      });
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
        title: const Text('Create a school', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                // Header icon
                Container(
                  width: 72,
                  height: 72,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.school_outlined, size: 36, color: cs.onPrimaryContainer),
                ),
                Text(
                  'Start your school on Attendor',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You will become its first admin and can then add classes, '
                  'teachers and link the classroom devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _schoolName,
                  decoration: const InputDecoration(labelText: 'School name', prefixIcon: Icon(Icons.business_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _adminName,
                  decoration: const InputDecoration(labelText: 'Your full name', prefixIcon: Icon(Icons.person_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Admin email', prefixIcon: Icon(Icons.email_outlined)),
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
                  onPressed: _busy ? null : _create,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create school & admin account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
