import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final db = context.read<DbService>();
    final meta = auth.meta;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (meta == null || meta.schoolId.isEmpty || meta.classId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Your student account is not linked to an active class.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.read<AuthService>().logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      );
    }

    final schoolId = meta.schoolId;
    final classId = meta.classId;

    return StreamBuilder<DatabaseEvent>(
      stream: db.watchClass(schoolId, classId),
      builder: (context, classSnap) {
        final classData = classSnap.data?.snapshot.value;
        final classInfo = (classData is Map) ? ClassInfo.fromSnapshot(classId, classData) : null;

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
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.name.isNotEmpty ? meta.name : 'Student Portal',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      classInfo?.name ?? 'Classroom Dashboard',
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
          body: Column(
            children: [
              // Tab Navigation
              Container(
                color: Colors.white,
                child: Row(
                  children: [
                    _buildTabButton('Today & Badge', 0, Icons.badge_outlined),
                    _buildTabButton('Attendance History', 1, Icons.history_rounded),
                    _buildTabButton('Class Timetable', 2, Icons.schedule_rounded),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Tab Views
              Expanded(
                child: IndexedStack(
                  index: _currentTab,
                  children: [
                    _StudentTodayTab(schoolId: schoolId, classId: classId, classInfo: classInfo, studentUid: auth.user!.uid),
                    _StudentHistoryTab(schoolId: schoolId, classId: classId, studentUid: auth.user!.uid),
                    _StudentTimetableTab(classInfo: classInfo),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 1: TODAY'S STATUS & RFID BADGE
// ══════════════════════════════════════════════════════════════════

class _StudentTodayTab extends StatelessWidget {
  final String schoolId;
  final String classId;
  final ClassInfo? classInfo;
  final String studentUid;

  const _StudentTodayTab({
    required this.schoolId,
    required this.classId,
    required this.classInfo,
    required this.studentUid,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final am = classInfo?.windows['am'];
    final pm = classInfo?.windows['pm'];

    return StreamBuilder<DatabaseEvent>(
      stream: db.ref('${db.schoolPath(schoolId)}/students/$studentUid').onValue,
      builder: (context, studentSnap) {
        final studentVal = studentSnap.data?.snapshot.value;
        final studentInfo = (studentVal is Map) ? StudentInfo.fromSnapshot(studentUid, studentVal) : null;
        final hasTag = studentInfo?.hasTag == true;

        return StreamBuilder<DatabaseEvent>(
          stream: db.watchClassAttendanceDate(schoolId, classId, today),
          builder: (context, attSnap) {
            final attVal = attSnap.data?.snapshot.value;
            final userAtt = (attVal is Map) ? attVal[studentUid] as Map? : null;
            final amData = userAtt?['am'] as Map?;
            final pmData = userAtt?['pm'] as Map?;
            final amPresent = amData?['present'] == true;
            final pmPresent = pmData?['present'] == true;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Digital RFID Badge Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hasTag
                              ? [const Color(0xFF065F46), const Color(0xFF059669), const Color(0xFF10B981)]
                              : [const Color(0xFF92400E), const Color(0xFFD97706), const Color(0xFFF59E0B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (hasTag ? const Color(0xFF059669) : const Color(0xFFD97706)).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.nfc_rounded, color: Colors.white, size: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    hasTag ? 'RFID PASS ACTIVE' : 'UNASSIGNED BADGE',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                                  ),
                                ],
                              ),
                              const Icon(Icons.contactless_rounded, color: Colors.white70, size: 24),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            studentInfo?.name ?? 'Student',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            classInfo?.name ?? 'Classroom',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                hasTag ? 'CARD UID: ${studentInfo!.tagUid}' : 'TAP IN CLASSROOM TO BIND CARD',
                                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Icon(hasTag ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Today's Attendance Windows
                    Text("Today's Attendance ($today)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAttendanceStatusCard(
                            window: 'Morning (AM)',
                            time: '${am?['start'] ?? '08:00'} - ${am?['end'] ?? '08:20'}',
                            present: amPresent,
                            scanTs: amData?['firstScan'],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAttendanceStatusCard(
                            window: 'Afternoon (PM)',
                            time: '${pm?['start'] ?? '14:40'} - ${pm?['end'] ?? '15:00'}',
                            present: pmPresent,
                            scanTs: pmData?['firstScan'],
                          ),
                        ),
                      ],
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

  Widget _buildAttendanceStatusCard({
    required String window,
    required String time,
    required bool present,
    dynamic scanTs,
  }) {
    String tapTime = '';
    if (scanTs is num && scanTs > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(scanTs.toInt());
      tapTime = 'Tapped at ${DateFormat('HH:mm:ss').format(dt)}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(window, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Icon(
                  present ? Icons.check_circle_rounded : Icons.cancel_outlined,
                  color: present ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(time, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: present ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                present ? 'PRESENT' : 'NOT RECORDED',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: present ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
              ),
            ),
            if (tapTime.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tapTime, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 2: ATTENDANCE HISTORY
// ══════════════════════════════════════════════════════════════════

class _StudentHistoryTab extends StatelessWidget {
  final String schoolId;
  final String classId;
  final String studentUid;

  const _StudentHistoryTab({
    required this.schoolId,
    required this.classId,
    required this.studentUid,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();

    return FutureBuilder<Map<String, dynamic>>(
      future: db.fetchStudentAttendance(schoolId, classId, studentUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data ?? {};
        final pct = (data['percentage'] as num?)?.toDouble() ?? 0.0;
        final presentCount = data['present'] ?? 0;
        final totalCount = data['total'] ?? 0;
        final days = (data['days'] as Map?) ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                const SizedBox(height: 4),
                                const Text('Attendance Rate', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('$presentCount', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                const SizedBox(height: 4),
                                const Text('Windows Present', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('$totalCount', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                const Text('Total Sessions', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: pct / 100, backgroundColor: const Color(0xFFE2E8F0), minHeight: 8, borderRadius: BorderRadius.circular(4)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Daily Attendance Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                if (days.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No attendance history recorded yet.')),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: days.length,
                    itemBuilder: (context, i) {
                      final dateKey = days.keys.elementAt(i).toString();
                      final dayData = days[dateKey] as Map?;
                      final am = dayData?['am'] == true;
                      final pm = dayData?['pm'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            (am || pm) ? Icons.check_circle_rounded : Icons.cancel_outlined,
                            color: (am || pm) ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                          title: Text(dateKey, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text('AM: ${am ? "Present" : "Absent"}'),
                                backgroundColor: am ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: am ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                              ),
                              const SizedBox(width: 6),
                              Chip(
                                label: Text('PM: ${pm ? "Present" : "Absent"}'),
                                backgroundColor: pm ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pm ? const Color(0xFF059669) : const Color(0xFFDC2626)),
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
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 3: CLASS TIMETABLE
// ══════════════════════════════════════════════════════════════════

class _StudentTimetableTab extends StatelessWidget {
  final ClassInfo? classInfo;

  const _StudentTimetableTab({required this.classInfo});

  @override
  Widget build(BuildContext context) {
    final am = classInfo?.windows['am'];
    final pm = classInfo?.windows['pm'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Class Attendance Timetable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Attendance cards must be tapped on the classroom reader during these windows.', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.wb_sunny_rounded, color: Color(0xFF2563EB))),
                      title: const Text('Morning Arrival Window', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${am?['start'] ?? '08:00'} to ${am?['end'] ?? '08:20'} IST'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFECFDF5), child: Icon(Icons.nights_stay_rounded, color: Color(0xFF059669))),
                      title: const Text('Afternoon Entry Window', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${pm?['start'] ?? '14:40'} to ${pm?['end'] ?? '15:00'} IST'),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.calendar_today_rounded, color: Color(0xFFD97706))),
                      title: Text('Operating Days', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Monday through Saturday (Sunday Closed)'),
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
