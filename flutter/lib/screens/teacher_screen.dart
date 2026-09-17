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

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final db = context.read<DbService>();
    final sid = auth.meta!.schoolId;
    final cid = auth.meta!.classId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My class'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthService>().logout(),
            icon: const Icon(Icons.logout),
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
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${classInfo.name} · $_date',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: _Roster(
                  schoolId: sid,
                  classId: cid,
                  classInfo: classInfo,
                  onAssignCard: (uid) => db.requestCardAssignment(sid, classInfo.deviceId, uid),
                  onEndSession: (window) => db.endSession(sid, cid, _date, window),
                  sessionFor: (window) {
                    final s = todaySessions[window];
                    return s is Map ? s['status']?.toString() ?? 'open' : 'open';
                  },
                  date: _date,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Roster extends StatefulWidget {
  final String schoolId;
  final String classId;
  final ClassInfo classInfo;
  final Future<void> Function(String uid) onAssignCard;
  final Future<void> Function(String window) onEndSession;
  final String Function(String window) sessionFor;
  final String date;

  const _Roster({
    required this.schoolId,
    required this.classId,
    required this.classInfo,
    required this.onAssignCard,
    required this.onEndSession,
    required this.sessionFor,
    required this.date,
  });

  @override
  State<_Roster> createState() => _RosterState();
}

class _RosterState extends State<_Roster> {
  late List<StudentInfo> _students;
  Map<String, AttendanceWindow>? _am;
  Map<String, AttendanceWindow>? _pm;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    final db = context.read<DbService>();
    _students = await db.fetchStudentsForClass(widget.schoolId, widget.classId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final am = widget.classInfo.windows['am'];
    final pm = widget.classInfo.windows['pm'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _SessionChip(
                label: 'AM ${am?['start']}-${am?['end']}',
                status: widget.sessionFor('am'),
                onClose: widget.sessionFor('am') == 'open'
                    ? () => widget.onEndSession('am')
                    : null,
              ),
              const SizedBox(width: 12),
              _SessionChip(
                label: 'PM ${pm?['start']}-${pm?['end']}',
                status: widget.sessionFor('pm'),
                onClose: widget.sessionFor('pm') == 'open'
                    ? () => widget.onEndSession('pm')
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder(
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
                return const Center(child: Text('No students yet. Share the entry code.'));
              }
              return RefreshIndicator(
                onRefresh: _loadRoster,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final s in _students)
                      ListTile(
                        leading: CircleAvatar(child: Text(s.name.isEmpty ? '?' : s.name[0])),
                        title: Text(s.name),
                        subtitle: Text(s.tagUid.isEmpty ? 'no card' : 'tag assigned'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusDot(present: _am?[s.uid]?.present ?? false, window: 'AM'),
                            const SizedBox(width: 16),
                            _StatusDot(present: _pm?[s.uid]?.present ?? false, window: 'PM'),
                            IconButton(
                              tooltip: 'Assign card',
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await widget.onAssignCard(s.uid);
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Scan the new card now')),
                                );
                              },
                              icon: const Icon(Icons.badge),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
    return InputChip(
      label: Text('$label · ${open ? 'open' : 'closed'}'),
      backgroundColor: open ? Colors.green.shade100 : Colors.grey.shade300,
      onPressed: onClose,
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
        present ? Icons.check_circle : Icons.circle_outlined,
        color: present ? Colors.green : Colors.grey,
      ),
    );
  }
}