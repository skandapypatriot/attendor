import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          title: StreamBuilder(
            stream: DbService().ref(DbService().schoolPath(sid)).child('profile').onValue,
            builder: (context, snap) {
              final v = snap.data?.snapshot.value;
              return Text(
                v is Map ? v['name']?.toString() ?? 'Admin' : 'Admin',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              );
            },
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: () => context.read<AuthService>().logout(),
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.class_outlined), text: 'Classes'),
              Tab(icon: Icon(Icons.people_outlined), text: 'Teachers'),
              Tab(icon: Icon(Icons.devices_outlined), text: 'Devices'),
            ],
          ),
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

// ═══════════════════════════════════════════════════
//  CLASSES TAB
// ═══════════════════════════════════════════════════

class _ClassesTab extends StatefulWidget {
  final String schoolId;
  const _ClassesTab({required this.schoolId});

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  Future<List<ClassInfo>> _classes = Future.value([]);
  List<TeacherRecord> _teachers = [];
  Map<String, double> _attendancePercentages = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<DbService>();
    _teachers = await db.fetchTeachers(widget.schoolId);
    final classes = await db.fetchClasses(widget.schoolId);
    final pctMap = <String, double>{};
    for (final c in classes) {
      pctMap[c.id] = await db.fetchAttendancePercentage(widget.schoolId, c.id);
    }
    setState(() {
      _classes = Future.value(classes);
      _attendancePercentages = pctMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _classes,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final classes = snap.data ?? [];
        int totalStudents = 0;
        double avgAttendance = 0;
        if (classes.isNotEmpty) {
          for (final c in classes) {
            totalStudents += c.studentIds.length;
          }
          final pctValues = _attendancePercentages.values.where((v) => v > 0).toList();
          if (pctValues.isNotEmpty) {
            avgAttendance = pctValues.reduce((a, b) => a + b) / pctValues.length;
          }
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (classes.isNotEmpty)
                _AdminSummaryRow(totalStudents: totalStudents, avgAttendance: avgAttendance, totalClasses: classes.length),
              if (classes.isNotEmpty) const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _createClass(context),
                icon: const Icon(Icons.add),
                label: const Text('New class'),
              ),
              const SizedBox(height: 12),
              if (classes.isEmpty)
                _EmptyState(
                  icon: Icons.class_outlined,
                  message: 'No classes yet. Create your first class to get started.',
                ),
              for (final c in classes)
                _ClassCard(
                  classInfo: c,
                  teachers: _teachers,
                  schoolId: widget.schoolId,
                  attendancePercentage: _attendancePercentages[c.id] ?? 0,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createClass(BuildContext context) async {
    final name = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('New class'),
            ],
          ),
          content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Class name', prefixIcon: Icon(Icons.class_outlined))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final code = await context.read<DbService>().createClass(
                      widget.schoolId,
                      name: name.text,
                      teacherUids: [],
                    );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Class created. Entry code: $code'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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
  final double attendancePercentage;

  const _ClassCard({required this.schoolId, required this.classInfo, required this.teachers, this.attendancePercentage = 0});

  @override
  Widget build(BuildContext context) {
    final assignedTeachers = teachers.where((t) => classInfo.teacherUids.contains(t.uid)).toList();
    final am = classInfo.windows['am'];
    final pm = classInfo.windows['pm'];
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.class_outlined, color: cs.onPrimaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(classInfo.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        assignedTeachers.isEmpty
                            ? 'No teacher assigned'
                            : assignedTeachers.map((t) => t.name).join(', '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key, size: 16, color: cs.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Text('Entry code: ', style: TextStyle(color: cs.onTertiaryContainer)),
                  Text(
                    classInfo.entryCode,
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 15, color: cs.onTertiaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _StatChip(icon: Icons.people_outlined, label: '${classInfo.studentIds.length} students'),
                _StatChip(icon: Icons.pie_chart_outline, label: '${attendancePercentage.toStringAsFixed(1)}% att.'),
                _StatChip(icon: Icons.access_time, label: 'AM ${am?['start'] ?? '-'}-${am?['end'] ?? '-'}'),
                _StatChip(icon: Icons.access_time, label: 'PM ${pm?['start'] ?? '-'}-${pm?['end'] ?? '-'}'),
                _StatChip(
                  icon: classInfo.deviceId.isEmpty ? Icons.devices_other : Icons.devices,
                  label: classInfo.deviceId.isEmpty ? 'No device' : 'Device linked',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tUid in classInfo.teacherUids)
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        (teachers.where((t) => t.uid == tUid).firstOrNull?.name ?? '?')[0].toUpperCase(),
                        style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                      ),
                    ),
                    label: Text(teachers.where((t) => t.uid == tUid).firstOrNull?.name ?? tUid),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () async {
                      await context.read<DbService>().unassignTeacher(schoolId, classInfo.id, tUid);
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Assign teacher'),
                  onPressed: () => _showAssignTeacherDialog(context),
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

  void _showAssignTeacherDialog(BuildContext context) {
    final unassigned = teachers.where((t) => !classInfo.teacherUids.contains(t.uid)).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.7,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Assign teacher to ${classInfo.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            Expanded(
              child: unassigned.isEmpty
                  ? const Center(child: Text('All teachers are already assigned to this class'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: unassigned.length,
                      itemBuilder: (_, i) {
                        final t = unassigned[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(t.name.isEmpty ? '?' : t.name[0].toUpperCase()),
                          ),
                          title: Text(t.name),
                          subtitle: Text(t.email),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () async {
                            await context.read<DbService>().assignTeacher(schoolId, classInfo.id, t.uid);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoster(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, controller) => FutureBuilder(
          future: context.read<DbService>().fetchStudentsForClass(schoolId, classInfo.id),
          builder: (ctx, snap) {
            final students = snap.data ?? [];
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.people_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Roster - ${classInfo.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${students.length} students', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: students.isEmpty
                      ? const Center(child: Text('No students enrolled yet.'))
                      : ListView.builder(
                          controller: controller,
                          itemCount: students.length,
                          itemBuilder: (_, i) {
                            final s = students[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(s.name.isEmpty ? '?' : s.name[0], style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                              ),
                              title: Text(s.name),
                              subtitle: Text(s.tagUid.isEmpty ? 'No card assigned' : 'Tag: ${s.tagUid}'),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TEACHERS TAB  –  shows class entry codes prominently
// ═══════════════════════════════════════════════════

class _TeachersTab extends StatefulWidget {
  final String schoolId;
  const _TeachersTab({required this.schoolId});

  @override
  State<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<_TeachersTab> {
  Future<List<TeacherRecord>> _teachers = Future.value([]);
  List<ClassInfo> _classes = [];
  List<Map<String, dynamic>> _joinCodes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<DbService>();
    final teachers = await db.fetchTeachers(widget.schoolId);
    final classes = await db.fetchClasses(widget.schoolId);
    final codes = await db.fetchTeacherJoinCodes(widget.schoolId);
    if (mounted) {
      setState(() {
        _teachers = Future.value(teachers);
        _classes = classes;
        _joinCodes = codes;
      });
    }
  }

  String _classNamesFor(List<String> classIds) {
    if (classIds.isEmpty) return 'No class assigned';
    return classIds
        .map((id) => _classes.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? id)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _teachers,
      builder: (context, snap) {
        final teachers = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key, color: cs.primary),
                          const SizedBox(width: 8),
                          Text('Teacher Join Codes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share a code with teachers so they can register and join your school.',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _generateCode(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Generate code'),
                      ),
                      if (_joinCodes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final code in _joinCodes)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.vpn_key, size: 18, color: cs.onTertiaryContainer),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    code['code'],
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: cs.onTertiaryContainer),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy code',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: code['code']));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: const Text('Code copied'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    );
                                  },
                                  icon: Icon(Icons.copy_rounded, color: cs.onTertiaryContainer),
                                ),
                                IconButton(
                                  tooltip: 'Delete code',
                                  onPressed: () async {
                                    await context.read<DbService>().removeTeacherJoinCode(code['code']);
                                    _load();
                                  },
                                  icon: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (teachers.isEmpty)
                _EmptyState(
                  icon: Icons.people_outlined,
                  message: 'No teachers yet. Share a join code to let teachers register.',
                ),
              for (final t in teachers)
                _TeacherCard(
                  teacher: t,
                  classNames: _classNamesFor(t.classIds),
                  classes: _classes,
                  schoolId: widget.schoolId,
                  onRefresh: _load,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateCode(BuildContext context) async {
    final db = context.read<DbService>();
    final code = await db.createTeacherJoinCode(widget.schoolId);
    _load();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code generated: $code — share it with a teacher'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _TeacherCard extends StatelessWidget {
  final TeacherRecord teacher;
  final String classNames;
  final List<ClassInfo> classes;
  final String schoolId;
  final VoidCallback onRefresh;

  const _TeacherCard({
    required this.teacher,
    required this.classNames,
    required this.classes,
    required this.schoolId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasClass = teacher.classIds.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    teacher.name.isEmpty ? '?' : teacher.name[0].toUpperCase(),
                    style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teacher.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text(teacher.email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasClass)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.class_outlined, size: 16, color: cs.onSecondaryContainer),
                        const SizedBox(width: 6),
                        Text('Assigned classes', style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final classId in teacher.classIds)
                          Chip(
                            label: Text(_classNameFor(classId)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () async {
                              await context.read<DbService>().unassignTeacher(schoolId, classId, teacher.uid);
                              onRefresh();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('No class assigned', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showAssignDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Assign to class'),
            ),
          ],
        ),
      ),
    );
  }

  String _classNameFor(String classId) {
    return classes.where((c) => c.id == classId).map((c) => c.name).firstOrNull ?? classId;
  }

  void _showAssignDialog(BuildContext context) {
    final unassignedClasses = classes.where((c) => !c.teacherUids.contains(teacher.uid)).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.7,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Assign ${teacher.name} to a class', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            Expanded(
              child: unassignedClasses.isEmpty
                  ? const Center(child: Text('No unassigned classes available'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: unassignedClasses.length,
                      itemBuilder: (_, i) {
                        final c = unassignedClasses[i];
                        return ListTile(
                          leading: Icon(Icons.class_outlined, color: Theme.of(context).colorScheme.primary),
                          title: Text(c.name),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () async {
                            await context.read<DbService>().assignTeacher(schoolId, c.id, teacher.uid);
                            Navigator.pop(ctx);
                            onRefresh();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  DEVICES TAB
// ═══════════════════════════════════════════════════

class _DevicesTab extends StatefulWidget {
  final String schoolId;
  const _DevicesTab({required this.schoolId});

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  Future<List<DeviceRecord>> _devices = Future.value([]);
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
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: () => _linkDevice(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Link device by pair code'),
              ),
              const SizedBox(height: 12),
              if (devices.isEmpty)
                _EmptyState(
                  icon: Icons.devices_other,
                  message: 'No devices linked yet. Pair your first classroom device.',
                ),
              for (final d in devices) _DeviceCard(record: d, className: classNames[d.classId]),
            ],
          ),
        );
      },
    );
  }

  Future<void> _linkDevice(BuildContext context) async {
    final code = TextEditingController();
    final label = TextEditingController();
    String? pickedClass;
    var scanning = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(Icons.qr_code_2, color: Theme.of(context).colorScheme.primary, size: 36),
          title: const Text('Link device to a class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'On the ESP8266 boot it shows its PAIR CODE - a QR on the OLED '
                    '(headless: prints the 12-hex MAC over Serial). Scan the device '
                    'screen with your camera, or paste the code manually, then pick '
                    'the class. The device stays linked permanently.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                if (!scanning) ...[
                  OutlinedButton.icon(
                    onPressed: () => setState(() => scanning = true),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR from device screen'),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      child: MobileScanner(
                        fit: BoxFit.cover,
                        onDetect: (capture) {
                          for (final b in capture.barcodes) {
                            final raw = (b.rawValue ?? '').trim();
                            final cleaned = raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
                            if (cleaned.length == 12) {
                              code.text = cleaned;
                              setState(() => scanning = false);
                              break;
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => scanning = false),
                    child: const Text('Stop scanning, type manually'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'Pair code (12 hex, e.g. A4CF12F2C3DD)',
                    helperText: 'Shown as QR on OLED / over Serial on boot',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                TextField(controller: label, decoration: const InputDecoration(labelText: 'Device label (optional)', prefixIcon: Icon(Icons.label_outlined))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => pickedClass = v),
                  decoration: const InputDecoration(labelText: 'Class', prefixIcon: Icon(Icons.class_outlined)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (pickedClass == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Choose a class'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }
                final db = context.read<DbService>();
                try {
                  await db.linkDeviceByCode(widget.schoolId, code.text, pickedClass!, label.text);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Device $code linked successfully'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                  _load();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceRecord record;
  final String? className;

  const _DeviceCard({required this.record, required this.className});

  @override
  Widget build(BuildContext context) {
    final linked = record.isLinked;
    final online = record.presenceTs != null;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: linked ? cs.primaryContainer : cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    linked ? Icons.link : Icons.link_off,
                    color: linked ? cs.onPrimaryContainer : cs.onErrorContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    record.label.isEmpty ? record.id : record.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                // Status badges
                _StatusBadge(
                  label: linked ? 'LINKED' : 'UNLINKED',
                  color: linked ? cs.primary : cs.error,
                ),
                if (online) ...[
                  const SizedBox(width: 6),
                  _StatusBadge(label: 'ONLINE', color: Colors.green),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Device details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(icon: Icons.wifi, label: 'MAC', value: record.id),
                  if (record.classId.isNotEmpty)
                    _DetailRow(icon: Icons.class_outlined, label: 'Class', value: className ?? record.classId),
                  if (record.authEmail.isNotEmpty)
                    _DetailRow(icon: Icons.email_outlined, label: 'Auth', value: record.authEmail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════

class _AdminSummaryRow extends StatelessWidget {
  final int totalStudents;
  final double avgAttendance;
  final int totalClasses;
  const _AdminSummaryRow({required this.totalStudents, required this.avgAttendance, required this.totalClasses});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [cs.primaryContainer, cs.tertiaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryStat(
              icon: Icons.class_outlined,
              value: '$totalClasses',
              label: 'Classes',
            ),
            _SummaryStat(
              icon: Icons.people_outlined,
              value: '$totalStudents',
              label: 'Students',
            ),
            _SummaryStat(
              icon: Icons.pie_chart_outline,
              value: '${avgAttendance.toStringAsFixed(1)}%',
              label: 'Avg. Att.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SummaryStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: cs.onPrimaryContainer),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
