import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  late String _date;
  String? _selectedClassId;
  List<ClassInfo> _myClasses = [];
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final db = context.read<DbService>();
    final auth = context.read<AuthService>();
    final sid = auth.meta!.schoolId;
    final uid = auth.user!.uid;
    // Fetch teacher's assigned classes from DB
    final teacherSnap = await db.ref('${db.schoolPath(sid)}/teachers/$uid/classIds').get();
    final classIds = teacherSnap.value is Map ? (teacherSnap.value as Map).keys.map((e) => e.toString()).toList() : <String>[];
    final classes = <ClassInfo>[];
    for (final cid in classIds) {
      final snap = await db.ref('${db.schoolPath(sid)}/classes/$cid').get();
      if (snap.exists && snap.value is Map) {
        classes.add(ClassInfo.fromSnapshot(cid, snap.value));
      }
    }
    if (mounted) {
      setState(() {
        _myClasses = classes;
        _loadingClasses = false;
        if (classes.isNotEmpty && _selectedClassId == null) {
          _selectedClassId = classes.first.id;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final db = context.read<DbService>();
    final sid = auth.meta!.schoolId;
    final cs = Theme.of(context).colorScheme;

    if (_loadingClasses) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cs.primary, cs.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          title: const Text('My classes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_myClasses.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cs.primary, cs.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          title: const Text('My classes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(onPressed: () => context.read<AuthService>().logout(), icon: const Icon(Icons.logout, color: Colors.white)),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_outlined, size: 56, color: cs.outline),
              const SizedBox(height: 12),
              Text('No classes assigned yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Ask your admin to assign you to a class.', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final cid = _selectedClassId!;

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
        title: const Text('My class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthService>().logout(),
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: db.watchClass(sid, cid),
        builder: (context, classSnap) {
          final value = classSnap.data?.snapshot.value;
          if (classSnap.connectionState != ConnectionState.active || value is! Map) {
            return const Center(child: CircularProgressIndicator());
          }
          final classInfo = ClassInfo.fromSnapshot(cid, value);
          final todaySessions = (value['sessions'] as Map?)?[_date] as Map? ?? {};
          return Column(
            children: [
              // Class selector (if multiple classes)
              if (_myClasses.length > 1)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    items: _myClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedClassId = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select class',
                      prefixIcon: Icon(Icons.class_outlined),
                      isDense: true,
                    ),
                  ),
                ),
              // Class info header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.class_outlined, color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(classInfo.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text(_date, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Session controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _SessionChip(
                      label: 'AM ${classInfo.windows['am']?['start'] ?? '-'}-${classInfo.windows['am']?['end'] ?? '-'}',
                      status: _sessionStatus(todaySessions, 'am'),
                      onClose: _sessionStatus(todaySessions, 'am') == 'open'
                          ? () => db.endSession(sid, cid, _date, 'am')
                          : null,
                    ),
                    const SizedBox(width: 12),
                    _SessionChip(
                      label: 'PM ${classInfo.windows['pm']?['start'] ?? '-'}-${classInfo.windows['pm']?['end'] ?? '-'}',
                      status: _sessionStatus(todaySessions, 'pm'),
                      onClose: _sessionStatus(todaySessions, 'pm') == 'open'
                          ? () => db.endSession(sid, cid, _date, 'pm')
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _ClassAttendanceSummary(schoolId: sid, classId: cid, date: _date),
              const SizedBox(height: 4),
              // Roster
              Expanded(
                child: _Roster(
                  schoolId: sid,
                  classId: cid,
                  classInfo: classInfo,
                  onAssignCard: (uid) => db.requestCardAssignment(sid, classInfo.deviceId, uid),
                  date: _date,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _sessionStatus(Map todaySessions, String window) {
    final s = todaySessions[window];
    return s is Map ? s['status']?.toString() ?? 'open' : 'open';
  }
}

class _Roster extends StatefulWidget {
  final String schoolId;
  final String classId;
  final ClassInfo classInfo;
  final Future<void> Function(String uid) onAssignCard;
  final String date;

  const _Roster({
    required this.schoolId,
    required this.classId,
    required this.classInfo,
    required this.onAssignCard,
    required this.date,
  });

  @override
  State<_Roster> createState() => _RosterState();
}

class _RosterState extends State<_Roster> {
  late List<StudentInfo> _students;
  Map<String, AttendanceWindow>? _am;
  Map<String, AttendanceWindow>? _pm;
  Map<String, Map<String, dynamic>> _studentStats = {};

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    final db = context.read<DbService>();
    _students = await db.fetchStudentsForClass(widget.schoolId, widget.classId);
    final allData = await db.ref(
        '${DbService().schoolPath(widget.schoolId)}/attendance/${widget.classId}').get();
    final map = allData.value is Map ? (allData.value as Map) : {};
    final tempStats = <String, Map<String, dynamic>>{};
    for (final s in _students) {
      int present = 0, total = 0;
      map.forEach((dateStr, byUid) {
        if (byUid is Map) {
          final userData = byUid[s.uid];
          if (userData is Map) {
            if (userData['am'] is Map) {
              total++;
              if ((userData['am'] as Map)['present'] == true) present++;
            }
            if (userData['pm'] is Map) {
              total++;
              if ((userData['pm'] as Map)['present'] == true) present++;
            }
          }
        }
      });
      tempStats[s.uid] = {
        'present': present,
        'total': total,
        'percentage': total > 0 ? (present / total) * 100.0 : 0.0,
      };
    }
    if (mounted) setState(() { _studentStats = tempStats; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder(
      stream: context.read<DbService>().ref(
          '${DbService().schoolPath(widget.schoolId)}/attendance/${widget.classId}/${widget.date}').onValue,
      builder: (context, snap) {
        final map = snap.data?.snapshot.value is Map
            ? (snap.data!.snapshot.value as Map)
            : <Object?, Object?>{};
        _am = {};
        _pm = {};
        map.forEach((uid, v) {
          final m = (v as Map);
          _am![uid.toString()] = AttendanceWindow.fromSnapshot(m['am']);
          _pm![uid.toString()] = AttendanceWindow.fromSnapshot(m['pm']);
        });
        if (_students.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 56, color: cs.outline),
                const SizedBox(height: 12),
                Text('No students yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('Share the entry code with students to enroll them.', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _loadRoster,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (_, i) {
              final s = _students[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase(), style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: _studentStats.containsKey(s.uid)
                      ? Text(
                          _studentStats[s.uid]!['total'] > 0
                              ? '${_studentStats[s.uid]!['percentage'].toStringAsFixed(1)}% (${_studentStats[s.uid]!['present']}/${_studentStats[s.uid]!['total']})'
                              : 'No records yet',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        )
                      : Text(s.tagUid.isEmpty ? 'No card assigned' : 'Tag assigned', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusDot(present: _am?[s.uid]?.present ?? false, window: 'AM'),
                      const SizedBox(width: 16),
                      _StatusDot(present: _pm?[s.uid]?.present ?? false, window: 'PM'),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Assign card',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await widget.onAssignCard(s.uid);
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Scan the new card now'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: Icon(Icons.badge, color: cs.primary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ClassAttendanceSummary extends StatefulWidget {
  final String schoolId;
  final String classId;
  final String date;
  const _ClassAttendanceSummary({required this.schoolId, required this.classId, required this.date});

  @override
  State<_ClassAttendanceSummary> createState() => _ClassAttendanceSummaryState();
}

class _ClassAttendanceSummaryState extends State<_ClassAttendanceSummary> {
  double _percentage = 0;
  int _todayPresent = 0;
  int _todayTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ClassAttendanceSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) _load();
  }

  Future<void> _load() async {
    final db = context.read<DbService>();
    final pct = await db.fetchAttendancePercentage(widget.schoolId, widget.classId);
    final todaySnap = await db.ref(
        '${DbService().schoolPath(widget.schoolId)}/attendance/${widget.classId}/${widget.date}').get();
    final map = todaySnap.value is Map ? (todaySnap.value as Map) : {};
    int present = 0, total = 0;
    map.forEach((uid, v) {
      if (v is Map) {
        if (v['am'] is Map) { total++; if ((v['am'] as Map)['present'] == true) present++; }
        if (v['pm'] is Map) { total++; if ((v['pm'] as Map)['present'] == true) present++; }
      }
    });
    if (mounted) setState(() { _percentage = pct; _todayPresent = present; _todayTotal = total; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [cs.primaryContainer, cs.tertiaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: _percentage / 100,
                        strokeWidth: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _percentage >= 75 ? Colors.green : _percentage >= 50 ? Colors.orange : cs.error,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${_percentage.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class Attendance', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Overall: ${_percentage.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                    Text(
                      'Today: $_todayPresent / $_todayTotal recorded',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  final String label;
  final String status;
  final VoidCallback? onClose;

  const _SessionChip({required this.label, required this.status, this.onClose});

  @override
  Widget build(BuildContext context) {
    final open = status == 'open';
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: open ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: open ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            open ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            size: 16,
            color: open ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '$label \u00b7 ${open ? 'open' : 'closed'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: open ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
          if (open && onClose != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close_rounded, size: 16, color: cs.onPrimaryContainer),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool present;
  final String window;

  const _StatusDot({required this.present, required this.window});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$window: ${present ? 'present' : 'absent'}',
      child: Icon(
        present ? Icons.check_circle_rounded : Icons.cancel_outlined,
        color: present ? Colors.green : Colors.grey.shade400,
        size: 22,
      ),
    );
  }
}
