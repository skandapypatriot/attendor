import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sid = auth.meta!.schoolId;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder(
            stream: DbService().ref(DbService().schoolPath(sid)).child('profile').onValue,
            builder: (context, snap) {
              final v = snap.data?.snapshot.value;
              return Text(v is Map ? v['name']?.toString() ?? 'Admin' : 'Admin');
            },
          ),
          actions: [
            IconButton(
              onPressed: () => context.read<AuthService>().logout(),
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Classes'), Tab(text: 'Teachers'), Tab(text: 'Devices')]),
        ),
        body: TabBarView(children: [
          _ClassesTab(schoolId: sid),
          _TeachersTab(schoolId: sid),
          _DevicesTab(schoolId: sid),
        ]),
      ),
    );
  }
}

class _ClassesTab extends StatefulWidget {
  final String schoolId;
  const _ClassesTab({required this.schoolId});

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  late Future<List<ClassInfo>> _classes;
  List<TeacherRecord> _teachers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<DbService>();
    _teachers = await db.fetchTeachers(widget.schoolId);
    setState(() {
      _classes = db.fetchClasses(widget.schoolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _classes,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final classes = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              FilledButton.icon(
                onPressed: () => _createClass(context),
                icon: const Icon(Icons.add),
                label: const Text('New class'),
              ),
              const SizedBox(height: 8),
              for (final c in classes) _ClassCard(classInfo: c, teachers: _teachers, schoolId: widget.schoolId),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createClass(BuildContext context) async {
    final name = TextEditingController();
    String? pickedTeacher;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Class name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: pickedTeacher,
                items: _teachers.map((t) => DropdownMenuItem(value: t.uid, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => pickedTeacher = v),
                decoration: const InputDecoration(labelText: 'Teacher (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final code = await context.read<DbService>().createClass(
                      widget.schoolId,
                      name: name.text,
                      teacherUids: pickedTeacher == null ? [] : [pickedTeacher!],
                    );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Class created. Entry code: $code')),
                  );
                }
                _load();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String schoolId;
  final ClassInfo classInfo;
  final List<TeacherRecord> teachers;

  const _ClassCard({required this.schoolId, required this.classInfo, required this.teachers});

  @override
  Widget build(BuildContext context) {
    final teacher = teachers.where((t) => t.uid == classInfo.teacherUid).firstOrNull;
    final am = classInfo.windows['am'];
    final pm = classInfo.windows['pm'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(classInfo.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Code: ${classInfo.entryCode}', style: Theme.of(context).textTheme.bodyMedium),
            Text('Teacher: ${teacher?.name ?? 'unassigned'}'),
            Text('Device: ${classInfo.deviceId.isEmpty ? 'none' : classInfo.deviceId}'),
            Text('Students: ${classInfo.studentIds.length}'),
            Text('Windows: ${am?['start']}-${am?['end']} AM / ${pm?['start']}-${pm?['end']} PM'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                DropdownButton<String>(
                  hint: const Text('Assign teacher'),
                  value: classInfo.teacherUid.isEmpty ? null : classInfo.teacherUid,
                  items: teachers
                      .map((t) => DropdownMenuItem(value: t.uid, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    final db = context.read<DbService>();
                    await db.assignTeacher(schoolId, classInfo.id, v);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher assigned')));
                    }
                  },
                ),
                TextButton.icon(
                  onPressed: () => _showRoster(context),
                  icon: const Icon(Icons.people),
                  label: const Text('Roster'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRoster(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => FutureBuilder(
        future: context.read<DbService>().fetchStudentsForClass(schoolId, classInfo.id),
        builder: (ctx, snap) {
          final students = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Roster - ${classInfo.name}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final s in students)
                ListTile(
                  dense: true,
                  title: Text(s.name),
                  subtitle: Text(s.tagUid.isEmpty ? 'no card assigned' : 'tag: ${s.tagUid}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TeachersTab extends StatefulWidget {
  final String schoolId;
  const _TeachersTab({required this.schoolId});

  @override
  State<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<_TeachersTab> {
  late Future<List<TeacherRecord>> _teachers;

  @override
  void initState() {
    super.initState();
    _teachers = context.read<DbService>().fetchTeachers(widget.schoolId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _teachers,
      builder: (context, snap) {
        final teachers = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            FilledButton.icon(
              onPressed: () => _addTeacher(context),
              icon: const Icon(Icons.add),
              label: const Text('Add teacher'),
            ),
            const SizedBox(height: 8),
            for (final t in teachers)
              ListTile(
                title: Text(t.name),
                subtitle: Text('${t.email} · class: ${t.classId.isEmpty ? 'none' : t.classId}'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addTeacher(BuildContext context) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add teacher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<DbService>().createTeacher(widget.schoolId,
                    name: name.text, email: email.text, password: password.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  setState(() {
                    _teachers = context.read<DbService>().fetchTeachers(widget.schoolId);
                  });
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create teacher')));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _DevicesTab extends StatefulWidget {
  final String schoolId;
  const _DevicesTab({required this.schoolId});

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  late Future<List<DeviceRecord>> _devices;
  List<ClassInfo> _classes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<DbService>();
    _classes = await db.fetchClasses(widget.schoolId);
    setState(() {
      _devices = db.fetchDevices(widget.schoolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _devices,
      builder: (context, snap) {
        final devices = snap.data ?? [];
        final classNames = {for (final c in _classes) c.id: c.name};
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              FilledButton.icon(
                onPressed: () => _addDevice(context),
                icon: const Icon(Icons.add),
                label: const Text('Add ESP32 device'),
              ),
              const SizedBox(height: 8),
              for (final d in devices)
                ListTile(
                  title: Text('${d.label} - ${classNames[d.classId] ?? d.classId}'),
                  subtitle: Text(d.authEmail),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addDevice(BuildContext context) async {
    final label = TextEditingController();
    String? pickedClass;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add ESP32 device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: label, decoration: const InputDecoration(labelText: 'Device label (e.g. Room 1 reader)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => pickedClass = v),
                decoration: const InputDecoration(labelText: 'Class'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (pickedClass == null) return;
                final db = context.read<DbService>();
                final creds = await db.createDevice(
                      widget.schoolId,
                      pickedClass!,
                      label.text,
                    );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  await _showDeviceCreds(context, creds);
                }
                _load();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeviceCreds(BuildContext context, Map<String, String> creds) async {
    final text = 'deviceId: ${creds['deviceId']}\nauthEmail: ${creds['authEmail']}\nauthPassword: ${creds['authPassword']}';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange),
        title: const Text('Device credentials - save now'),
        content: SingleChildScrollView(
          child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace')),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
            },
            child: const Text('Copy & close'),
          ),
        ],
      ),
    );
  }
}