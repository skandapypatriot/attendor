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
    return Scaffold(
      appBar: AppBar(title: const Text('Create a school')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Start your school on Attendor. You will become its first admin and '
                  'can then add classes, teachers and link the classroom devices.',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(controller: _schoolName, decoration: const InputDecoration(labelText: 'School name')),
                const SizedBox(height: 12),
                TextField(controller: _adminName, decoration: const InputDecoration(labelText: 'Your full name')),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Admin email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
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