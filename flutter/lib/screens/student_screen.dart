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
    return Scaffold(
      appBar: AppBar(
        title: Text(_class?.name ?? 'Attendance'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthService>().logout(),
            icon: const Icon(Icons.logout),
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
            return const Center(child: Text('No attendance records yet.'));
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final entry in days.entries) _DayTile(date: entry.key, windows: entry.value),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DateTime date;
  final Map<String, AttendanceWindow> windows;

  const _DayTile({required this.date, required this.windows});

  @override
  Widget build(BuildContext context) {
    final am = windows['am'];
    final pm = windows['pm'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          (am?.present ?? false) || (pm?.present ?? false) ? Icons.check_circle : Icons.cancel,
          color: (am?.present ?? false) || (pm?.present ?? false) ? Colors.green : Colors.red,
        ),
        title: Text(DateFormat('EEE, dd MMM yyyy').format(date)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AM: ${am?.present ?? false ? _fmt(am?.firstScan) : 'absent'}'),
            Text('PM: ${pm?.present ?? false ? _fmt(pm?.firstScan) : 'absent'}'),
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