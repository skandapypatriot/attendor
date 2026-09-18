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
  late Future<Map<DateTime, Map<String, AttendanceWindow>>> _attendance;
  ClassInfo? _class;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final db = context.read<DbService>();
    final meta = auth.meta!;
    final classSnap = await db.ref('${DbService().schoolPath(meta.schoolId)}/classes/${meta.classId}').get();
    if (classSnap.exists) {
      _class = ClassInfo.fromSnapshot(meta.classId, classSnap.value);
    }
    setState(() {
      _attendance = db.fetchMyAttendance(meta.schoolId, meta.classId);
    });
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
        title: Text(
          _class?.name ?? 'Attendance',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthService>().logout(),
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _attendance,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final days = snap.data ?? {};
          if (days.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available_outlined, size: 56, color: cs.outline),
                  const SizedBox(height: 12),
                  Text('No attendance records yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('Your attendance will appear here once recorded.', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AttendanceStatsCard(days: days),
                const SizedBox(height: 8),
                for (final entry in days.entries)
                  _DayCard(date: entry.key, windows: entry.value),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime date;
  final Map<String, AttendanceWindow> windows;

  const _DayCard({required this.date, required this.windows});

  @override
  Widget build(BuildContext context) {
    final am = windows['am'];
    final pm = windows['pm'];
    final anyPresent = (am?.present ?? false) || (pm?.present ?? false);
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: anyPresent ? Colors.green.withValues(alpha: 0.12) : cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                anyPresent ? Icons.check_circle_rounded : Icons.cancel_outlined,
                color: anyPresent ? Colors.green : cs.onErrorContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE, dd MMM yyyy').format(date),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _WindowRow(label: 'AM', present: am?.present ?? false, time: _fmt(am?.firstScan)),
                  const SizedBox(height: 2),
                  _WindowRow(label: 'PM', present: pm?.present ?? false, time: _fmt(pm?.firstScan)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int? ms) {
    if (ms == null) return '-';
    return DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));
  }
}

class _WindowRow extends StatelessWidget {
  final String label;
  final bool present;
  final String time;
  const _WindowRow({required this.label, required this.present, required this.time});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          present ? Icons.circle : Icons.circle_outlined,
          size: 8,
          color: present ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(
          present ? 'Present ($time)' : 'Absent',
          style: TextStyle(
            fontSize: 13,
            fontWeight: present ? FontWeight.w600 : FontWeight.normal,
            color: present ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AttendanceStatsCard extends StatelessWidget {
  final Map<DateTime, Map<String, AttendanceWindow>> days;
  const _AttendanceStatsCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    int present = 0;
    int total = 0;
    for (final entry in days.entries) {
      final am = entry.value['am'];
      final pm = entry.value['pm'];
      if (am != null) { total++; if (am.present) present++; }
      if (pm != null) { total++; if (pm.present) present++; }
    }
    final pct = total > 0 ? present / total : 0.0;

    int streak = 0;
    final sortedDates = days.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final d in sortedDates) {
      final w = days[d];
      final amP = w?['am']?.present ?? false;
      final pmP = w?['pm']?.present ?? false;
      if (amP || pmP) {
        streak++;
      } else {
        break;
      }
    }

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
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 0.75 ? Colors.green : pct >= 0.5 ? Colors.orange : cs.error,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attendance Overview', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatItem(
                        icon: Icons.check_circle_outline,
                        label: 'Present',
                        value: '$present',
                        color: Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _StatItem(
                        icon: Icons.cancel_outlined,
                        label: 'Absent',
                        value: '${total - present}',
                        color: cs.error,
                      ),
                      const SizedBox(width: 16),
                      _StatItem(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Streak',
                        value: '$streak',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
