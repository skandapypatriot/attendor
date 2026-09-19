import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final meta = auth.meta;
    final schoolId = meta?.schoolId ?? '';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (schoolId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('No school profile associated with this admin account.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.read<AuthService>().logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      );
    }

    final pages = [
      _AdminOverviewPage(schoolId: schoolId, onNavigate: (i) => setState(() => _currentIndex = i)),
      _AdminClassesPage(schoolId: schoolId),
      _AdminTeachersPage(schoolId: schoolId),
      _AdminStudentsPage(schoolId: schoolId),
      _AdminDevicesPage(schoolId: schoolId),
      _AdminSettingsPage(schoolId: schoolId),
    ];

    final navItems = const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Overview'),
      NavigationDestination(icon: Icon(Icons.class_outlined), selectedIcon: Icon(Icons.class_rounded), label: 'Classes'),
      NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school_rounded), label: 'Teachers'),
      NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Students'),
      NavigationDestination(icon: Icon(Icons.sensors_outlined), selectedIcon: Icon(Icons.sensors_rounded), label: 'Devices'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendor Admin',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.3),
                ),
                Text(
                  meta?.name.isNotEmpty == true ? meta!.name : 'School Management Portal',
                  style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthService>().logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              destinations: navItems
                  .map((d) => NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.selectedIcon ?? d.icon,
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
          if (isDesktop) const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
          Expanded(child: pages[_currentIndex]),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: navItems,
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PAGE 1: OVERVIEW & REAL-TIME SUMMARY
// ══════════════════════════════════════════════════════════════════

class _AdminOverviewPage extends StatelessWidget {
  final String schoolId;
  final ValueChanged<int> onNavigate;

  const _AdminOverviewPage({required this.schoolId, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard Overview', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Live school telemetry, class roster status, and reader heartbeats', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 24),

            // StreamBuilders for Real-Time Stats
            StreamBuilder<List<ClassInfo>>(
              stream: db.watchClasses(schoolId),
              builder: (context, classSnap) {
                final classes = classSnap.data ?? [];
                return StreamBuilder<List<TeacherRecord>>(
                  stream: db.watchTeachers(schoolId),
                  builder: (context, teacherSnap) {
                    final teachers = teacherSnap.data ?? [];
                    return StreamBuilder<List<DeviceRecord>>(
                      stream: db.watchDevices(schoolId),
                      builder: (context, deviceSnap) {
                        final devices = deviceSnap.data ?? [];
                        final onlineDevices = devices.where((d) => d.isOnline).length;
                        final totalStudents = classes.fold<int>(0, (sum, c) => sum + c.studentIds.length);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stat Cards Row
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 800;
                                return Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    _buildStatCard('Classes', '${classes.length}', Icons.class_outlined, const Color(0xFF2563EB), isWide ? 220 : 160),
                                    _buildStatCard('Students', '$totalStudents', Icons.people_outline_rounded, const Color(0xFF059669), isWide ? 220 : 160),
                                    _buildStatCard('Teachers', '${teachers.length}', Icons.school_outlined, const Color(0xFFD97706), isWide ? 220 : 160),
                                    _buildStatCard('Readers', '$onlineDevices / ${devices.length} Online', Icons.sensors_rounded, const Color(0xFF7C3AED), isWide ? 240 : 160),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 32),

                            // Quick Actions Strip
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Quick Class & Device Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () => _openCreateClassDialog(context, schoolId, teachers),
                                          icon: const Icon(Icons.add_rounded, size: 18),
                                          label: const Text('Add New Class'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _openLinkDeviceDialog(context, schoolId, classes),
                                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                          label: const Text('Link Reader Device'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => onNavigate(1),
                                          icon: const Icon(Icons.vpn_key_rounded, size: 18),
                                          label: const Text('View All Access Codes'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Recent Classes Table Preview
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Active Classes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        TextButton(
                                          onPressed: () => onNavigate(1),
                                          child: const Text('Manage Classes ->'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (classes.isEmpty)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 24),
                                          child: Text('No classes added yet. Click "Add New Class" to create one.'),
                                        ),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: classes.length > 5 ? 5 : classes.length,
                                        separatorBuilder: (_, _) => const Divider(height: 1),
                                        itemBuilder: (context, i) {
                                          final c = classes[i];
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(
                                              backgroundColor: const Color(0xFFEFF6FF),
                                              child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C', style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                                            ),
                                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: Text('Student Code: ${c.studentCode}  •  Teacher Code: ${c.teacherCode}', style: const TextStyle(fontSize: 12)),
                                            trailing: Chip(
                                              label: Text('${c.studentIds.length} students'),
                                              backgroundColor: const Color(0xFFF1F5F9),
                                              labelStyle: const TextStyle(fontSize: 12),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double minWidth) {
    return Container(
      width: minWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PAGE 2: CLASSES MANAGEMENT (WITH STUDENT & TEACHER CODES)
// ══════════════════════════════════════════════════════════════════

class _AdminClassesPage extends StatefulWidget {
  final String schoolId;

  const _AdminClassesPage({required this.schoolId});

  @override
  State<_AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends State<_AdminClassesPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final theme = Theme.of(context);

    return StreamBuilder<List<TeacherRecord>>(
      stream: db.watchTeachers(widget.schoolId),
      builder: (context, teacherSnap) {
        final teachers = teacherSnap.data ?? [];

        return StreamBuilder<List<ClassInfo>>(
          stream: db.watchClasses(widget.schoolId),
          builder: (context, classSnap) {
            final classes = classSnap.data ?? [];
            final filtered = classes.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Classrooms & Join Codes', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('Manage classrooms, distinct access codes, time windows, and reader links', style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () => _openCreateClassDialog(context, widget.schoolId, teachers),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Add Class'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Search field
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: const InputDecoration(
                        hintText: 'Search classes by name...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (classSnap.connectionState == ConnectionState.waiting && classes.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                    else if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(Icons.class_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text('No classes found.', style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF64748B))),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: () => _openCreateClassDialog(context, widget.schoolId, teachers),
                                child: const Text('Create First Class'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          return _ClassCard(
                            classInfo: filtered[i],
                            schoolId: widget.schoolId,
                            teachers: teachers,
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassInfo classInfo;
  final String schoolId;
  final List<TeacherRecord> teachers;

  const _ClassCard({
    required this.classInfo,
    required this.schoolId,
    required this.teachers,
  });

  @override
  Widget build(BuildContext context) {
    final assignedTeachers = teachers.where((t) => classInfo.teacherUids.contains(t.uid)).toList();
    final am = classInfo.windows['am'];
    final pm = classInfo.windows['pm'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(classInfo.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.sensors_rounded, size: 16, color: classInfo.deviceId.isNotEmpty ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            classInfo.deviceId.isNotEmpty ? 'Reader MAC: ${classInfo.deviceId}' : 'No reader linked yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: classInfo.deviceId.isNotEmpty ? const Color(0xFF059669) : const Color(0xFF64748B),
                              fontWeight: classInfo.deviceId.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Class',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmDeleteClass(context, schoolId, classInfo),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Join Codes Row (Student Code & Teacher Code)
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildCodePill(
                  context,
                  title: 'Student Entry Code',
                  code: classInfo.studentCode,
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
                _buildCodePill(
                  context,
                  title: 'Teacher Join Code',
                  code: classInfo.teacherCode,
                  icon: Icons.school_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Timetable Windows & Teachers summary
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                  label: Text('AM Window: ${am?['start'] ?? '08:00'} - ${am?['end'] ?? '08:20'}'),
                  backgroundColor: const Color(0xFFF8FAFC),
                ),
                Chip(
                  avatar: const Icon(Icons.nights_stay_outlined, size: 16),
                  label: Text('PM Window: ${pm?['start'] ?? '14:40'} - ${pm?['end'] ?? '15:00'}'),
                  backgroundColor: const Color(0xFFF8FAFC),
                ),
                Chip(
                  avatar: const Icon(Icons.people_outline_rounded, size: 16),
                  label: Text('${classInfo.studentIds.length} Students Enrolled'),
                  backgroundColor: const Color(0xFFF8FAFC),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Assigned teachers
            Row(
              children: [
                const Text('Teachers: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Expanded(
                  child: Text(
                    assignedTeachers.isNotEmpty
                        ? assignedTeachers.map((t) => t.name).join(', ')
                        : 'None assigned yet (Share teacher code to assign)',
                    style: TextStyle(
                      fontSize: 13,
                      color: assignedTeachers.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAssignTeacherDialog(context, schoolId, classInfo, teachers),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Manage Teachers'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodePill(
    BuildContext context, {
    required String title,
    required String code,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              Text(code.isNotEmpty ? code : 'N/A', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: color,
            tooltip: 'Copy $title',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied $title: $code to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClass(BuildContext context, String schoolId, ClassInfo c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: const Text('This will remove the classroom and its join codes. Enrolled students will be unlinked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<DbService>().deleteClass(schoolId, c.id, c.studentCode, c.teacherCode);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openAssignTeacherDialog(BuildContext context, String schoolId, ClassInfo c, List<TeacherRecord> allTeachers) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Manage Teachers for ${c.name}'),
              content: SizedBox(
                width: 400,
                child: allTeachers.isEmpty
                    ? const Text('No registered teachers in this school yet. Share the Teacher Join Code so teachers can register.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: allTeachers.length,
                        itemBuilder: (context, i) {
                          final t = allTeachers[i];
                          final isAssigned = c.teacherUids.contains(t.uid);
                          return CheckboxListTile(
                            title: Text(t.name),
                            subtitle: Text(t.email),
                            value: isAssigned,
                            onChanged: (bool? val) async {
                              final db = context.read<DbService>();
                              if (val == true) {
                                await db.assignTeacher(schoolId, c.id, t.uid);
                              } else {
                                await db.unassignTeacher(schoolId, c.id, t.uid);
                              }
                              setDialogState(() {});
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PAGE 3: TEACHERS DIRECTORY
// ══════════════════════════════════════════════════════════════════

class _AdminTeachersPage extends StatelessWidget {
  final String schoolId;

  const _AdminTeachersPage({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final theme = Theme.of(context);

    return StreamBuilder<List<TeacherRecord>>(
      stream: db.watchTeachers(schoolId),
      builder: (context, snap) {
        final teachers = snap.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Teacher Directory', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Staff assigned to classes. Teachers register automatically using their Class Teacher Code.', style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 24),

                if (teachers.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No teachers registered yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('Share the Teacher Join Code from any class card with your teachers so they can sign up.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: teachers.length,
                    itemBuilder: (context, i) {
                      final t = teachers[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFEF3C7),
                            child: Text(t.name.isNotEmpty ? t.name[0].toUpperCase() : 'T', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                          ),
                          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${t.email}  •  ${t.classIds.length} Assigned Classes'),
                          trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PAGE 4: STUDENTS DIRECTORY & RFID BADGE MANAGEMENT
// ══════════════════════════════════════════════════════════════════

class _AdminStudentsPage extends StatefulWidget {
  final String schoolId;

  const _AdminStudentsPage({required this.schoolId});

  @override
  State<_AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<_AdminStudentsPage> {
  String _selectedClassId = '';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final theme = Theme.of(context);

    return StreamBuilder<List<ClassInfo>>(
      stream: db.watchClasses(widget.schoolId),
      builder: (context, classSnap) {
        final classes = classSnap.data ?? [];
        if (_selectedClassId.isEmpty && classes.isNotEmpty) {
          _selectedClassId = classes.first.id;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student Roster & RFID Cards', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('View enrolled students and bind 13.56 MHz RFID cards to student IDs', style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 20),

                // Class Selector & Search
                Row(
                  children: [
                    if (classes.isNotEmpty)
                      DropdownButton<String>(
                        value: _selectedClassId,
                        items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() => _selectedClassId = v ?? ''),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Search student by name or email...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_selectedClassId.isEmpty)
                  const Text('No classes found. Create a class first.')
                else
                  StreamBuilder<List<StudentInfo>>(
                    stream: db.watchStudentsForClass(widget.schoolId, _selectedClassId),
                    builder: (context, studentSnap) {
                      final students = studentSnap.data ?? [];
                      final filtered = students.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()) || s.email.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                      if (students.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  const Text('No students joined this class yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text('Share the Student Entry Code for this class to invite students.', style: TextStyle(color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final s = filtered[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFEFF6FF),
                                child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                              ),
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(s.email),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: s.hasTag ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: s.hasTag ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.credit_card_rounded, size: 14, color: s.hasTag ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                        const SizedBox(width: 6),
                                        Text(
                                          s.hasTag ? 'Tag: ${s.tagUid}' : 'Unassigned',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: s.hasTag ? const Color(0xFF059669) : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Edit Tag UID manually',
                                    onPressed: () => _openManualTagDialog(context, widget.schoolId, s),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openManualTagDialog(BuildContext context, String schoolId, StudentInfo student) {
    final controller = TextEditingController(text: student.tagUid);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign RFID Tag to ${student.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the card UID (hexadecimal) or tap on reader.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Tag UID (e.g. 84F3EB)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<DbService>().setStudentTagUid(schoolId, student.uid, controller.text);
            },
            child: const Text('Save Tag'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PAGE 5: HARDWARE DEVICES MANAGEMENT
// ══════════════════════════════════════════════════════════════════

class _AdminDevicesPage extends StatelessWidget {
  final String schoolId;

  const _AdminDevicesPage({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final theme = Theme.of(context);

    return StreamBuilder<List<ClassInfo>>(
      stream: db.watchClasses(schoolId),
      builder: (context, classSnap) {
        final classes = classSnap.data ?? [];

        return StreamBuilder<List<DeviceRecord>>(
          stream: db.watchDevices(schoolId),
          builder: (context, snap) {
            final devices = snap.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Classroom Hardware Readers', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('ESP32 & ESP8266 NodeMCU RFID Readers with OLED Display', style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () => _openLinkDeviceDialog(context, schoolId, classes),
                          icon: const Icon(Icons.link_rounded, size: 20),
                          label: const Text('Link Device by MAC'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (devices.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.sensors_off_rounded, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text('No devices linked to this school yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                const Text('Boot up your ESP32 or ESP8266 reader. Read the 12-digit MAC code on the OLED or Serial, and click "Link Device by MAC".', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: devices.length,
                        itemBuilder: (context, i) {
                          final d = devices[i];
                          final assignedClass = classes.where((c) => c.id == d.classId).firstOrNull;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: d.isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.sensors_rounded,
                                      color: d.isOnline ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(d.label.isNotEmpty ? d.label : 'Attendance Reader', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: d.isOnline ? const Color(0xFFD1FAE5) : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                d.isOnline ? 'ONLINE' : 'OFFLINE',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: d.isOnline ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Hardware MAC: ${d.id}  •  Linked Class: ${assignedClass?.name ?? 'None'}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _confirmUnlinkDevice(context, schoolId, d),
                                    child: const Text('Unlink'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmUnlinkDevice(BuildContext context, String schoolId, DeviceRecord d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unlink device ${d.id}?'),
        content: const Text('The reader will revert to UNLINKED mode and will need to be paired again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<DbService>().unlinkDevice(schoolId, d.id, d.classId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Device ${d.id} unlinked. Reader will show QR on next boot.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to unlink: $e')),
                  );
                }
              }
            },
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PAGE 6: SCHOOL SETTINGS
// ══════════════════════════════════════════════════════════════════

class _AdminSettingsPage extends StatelessWidget {
  final String schoolId;

  const _AdminSettingsPage({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('School Settings', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('School Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.domain_rounded),
                      title: const Text('School ID'),
                      subtitle: Text(schoolId),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.admin_panel_settings_rounded),
                      title: const Text('Administrator Email'),
                      subtitle: Text(auth.user?.email ?? 'Unknown'),
                    ),
                    const Divider(),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.schedule_rounded),
                      title: Text('Timezone'),
                      subtitle: Text('Asia/Kolkata (IST, UTC+05:30)'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => auth.logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out from Attendor'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SHARED DIALOGS: CREATE CLASS & LINK HARDWARE DEVICE
// ══════════════════════════════════════════════════════════════════

void _openCreateClassDialog(BuildContext context, String schoolId, List<TeacherRecord> teachers) {
  final nameController = TextEditingController();
  final amStart = TextEditingController(text: '08:00');
  final amEnd = TextEditingController(text: '08:20');
  final pmStart = TextEditingController(text: '14:40');
  final pmEnd = TextEditingController(text: '15:00');
  bool busy = false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Classroom'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Class Name',
                        hintText: 'e.g. Grade 10-A, Physics Lab',
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Morning Attendance Window', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: amStart, decoration: const InputDecoration(labelText: 'Start (HH:mm)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: amEnd, decoration: const InputDecoration(labelText: 'End (HH:mm)'))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Afternoon Attendance Window', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: pmStart, decoration: const InputDecoration(labelText: 'Start (HH:mm)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: pmEnd, decoration: const InputDecoration(labelText: 'End (HH:mm)'))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        setDialogState(() => busy = true);
                        try {
                          final db = context.read<DbService>();
                          final res = await db.createClass(
                            schoolId,
                            name: name,
                            amStart: amStart.text.trim(),
                            amEnd: amEnd.text.trim(),
                            pmStart: pmStart.text.trim(),
                            pmEnd: pmEnd.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Class created! Student Code: ${res['studentCode']}  |  Teacher Code: ${res['teacherCode']}'),
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => busy = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error creating class: $e')),
                            );
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Class'),
              ),
            ],
          );
        },
      );
    },
  );
}

void _openLinkDeviceDialog(BuildContext context, String schoolId, List<ClassInfo> classes) {
  final macController = TextEditingController();
  final labelController = TextEditingController(text: 'Classroom Reader');
  String selectedClassId = classes.isNotEmpty ? classes.first.id : '';
  bool busy = false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Link Reader to Class'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter the 12-character MAC address shown on the reader display at boot (e.g. 84F3EBE4A1A7).', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: macController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Device MAC Code',
                      hintText: 'e.g. 84F3EBE4A1A7',
                      prefixIcon: Icon(Icons.qr_code_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: 'Device Label',
                      hintText: 'e.g. Room 101 Door',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassId.isNotEmpty ? selectedClassId : null,
                    decoration: const InputDecoration(labelText: 'Assign to Classroom'),
                    items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setDialogState(() => selectedClassId = v ?? ''),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final mac = macController.text.trim();
                        if (mac.isEmpty || selectedClassId.isEmpty) return;

                        setDialogState(() => busy = true);
                        try {
                          final db = context.read<DbService>();
                          await db.linkDeviceByCode(schoolId, mac, selectedClassId, labelController.text);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Device linked successfully!')),
                          );
                        } catch (e) {
                          setDialogState(() => busy = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error linking device: $e')),
                            );
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Link Device'),
              ),
            ],
          );
        },
      );
    },
  );
}
