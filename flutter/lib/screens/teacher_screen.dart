import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final db = context.read<DbService>();
    final theme = Theme.of(context);
    final meta = auth.meta;
    final schoolId = meta?.schoolId ?? '';
    final teacherUid = auth.user?.uid ?? '';

    if (schoolId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No school profile linked.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.read<AuthService>().logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<ClassInfo>>(
      stream: db.watchClasses(schoolId),
      builder: (context, snap) {
        final allClasses = snap.data ?? [];
        // Classes assigned to this teacher
        final myClasses = allClasses.where((c) => c.teacherUids.contains(teacherUid)).toList();

        if (_selectedClassId == null || !myClasses.any((c) => c.id == _selectedClassId)) {
          if (myClasses.isNotEmpty) {
            _selectedClassId = myClasses.first.id;
          } else {
            _selectedClassId = null;
          }
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teacher Portal', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      meta?.name.isNotEmpty == true ? meta!.name : 'Classroom Attendance & RFID',
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Add another class using code',
                icon: const Icon(Icons.add_link_rounded),
                onPressed: () => _openClaimClassDialog(context, schoolId, teacherUid),
              ),
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => context.read<AuthService>().logout(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: myClasses.isEmpty
              ? _buildNoClassState(context, schoolId, teacherUid)
              : _buildTeacherDashboard(context, schoolId, myClasses, _selectedClassId!),
        );
      },
    );
  }

  Widget _buildNoClassState(BuildContext context, String schoolId, String teacherUid) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                  child: const Icon(Icons.school_outlined, size: 40, color: Color(0xFFD97706)),
                ),
                const SizedBox(height: 20),
                const Text('No Classes Claimed Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Enter the Teacher Join Code for your class below, or ask your school administrator to assign you to a classroom.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _openClaimClassDialog(context, schoolId, teacherUid),
                  icon: const Icon(Icons.pin_outlined),
                  label: const Text('Enter Teacher Join Code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherDashboard(
    BuildContext context,
    String schoolId,
    List<ClassInfo> myClasses,
    String selectedClassId,
  ) {
    final selectedClass = myClasses.firstWhere((c) => c.id == selectedClassId);

    return Column(
      children: [
        // ── Class Switcher & Student Code Banner ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.meeting_room_rounded, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              if (myClasses.length > 1)
                DropdownButton<String>(
                  value: selectedClassId,
                  underline: const SizedBox(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  items: myClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _selectedClassId = v),
                )
              else
                Text(selectedClass.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              // Student entry code pill for easy sharing
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, size: 14, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 6),
                    Text('Student Code: ${selectedClass.studentCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1D4ED8))),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: selectedClass.studentCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied Student Code: ${selectedClass.studentCode}')),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Tabs Navigation ──
        Container(
          color: Colors.white,
          child: Row(
            children: [
              _buildTabButton('Live Attendance Roster', 0, Icons.fact_check_rounded),
              _buildTabButton('RFID Badge Kiosk', 1, Icons.credit_card_rounded),
              _buildTabButton('History & Records', 2, Icons.history_rounded),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Active Tab Body ──
        Expanded(
          child: IndexedStack(
            index: _currentTab,
            children: [
              _TeacherLiveRosterTab(schoolId: schoolId, classInfo: selectedClass, date: _date),
              _TeacherRfidKioskTab(schoolId: schoolId, classInfo: selectedClass),
              _TeacherHistoryTab(schoolId: schoolId, classInfo: selectedClass),
            ],
          ),
        ),
      ],
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

  void _openClaimClassDialog(BuildContext context, String schoolId, String teacherUid) {
    final controller = TextEditingController();
    bool busy = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Claim Class via Teacher Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the Teacher Join Code provided by your school administrator (e.g. TCH-XXXXX).', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Teacher Join Code', prefixIcon: Icon(Icons.vpn_key_outlined)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final code = controller.text.trim();
                      if (code.isEmpty) return;

                      setDialogState(() => busy = true);
                      final db = context.read<DbService>();
                      final err = await db.claimClassWithTeacherCode(schoolId, teacherUid, code);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err.isEmpty ? 'Class successfully claimed!' : err)),
                      );
                    },
              child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Claim Class'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 1: LIVE ATTENDANCE ROSTER
// ══════════════════════════════════════════════════════════════════

class _TeacherLiveRosterTab extends StatelessWidget {
  final String schoolId;
  final ClassInfo classInfo;
  final String date;

  const _TeacherLiveRosterTab({
    required this.schoolId,
    required this.classInfo,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final am = classInfo.windows['am'];
    final pm = classInfo.windows['pm'];

    return StreamBuilder(
      stream: db.watchClassAttendanceDate(schoolId, classInfo.id, date),
      builder: (context, attSnap) {
        final attMap = attSnap.data?.snapshot.value is Map ? (attSnap.data!.snapshot.value as Map) : {};

        return StreamBuilder<List<StudentInfo>>(
          stream: db.watchStudentsForClass(schoolId, classInfo.id),
          builder: (context, studentSnap) {
            final students = studentSnap.data ?? [];

            int amPresentCount = 0;
            int pmPresentCount = 0;
            for (final s in students) {
              final userAtt = attMap[s.uid] as Map?;
              if (userAtt?['am']?['present'] == true) amPresentCount++;
              if (userAtt?['pm']?['present'] == true) pmPresentCount++;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Windows Overview Strip
                    Row(
                      children: [
                        Expanded(
                          child: _buildSessionCard(
                            title: 'Morning Window (AM)',
                            time: '${am?['start'] ?? '08:00'} - ${am?['end'] ?? '08:20'}',
                            present: amPresentCount,
                            total: students.length,
                            color: const Color(0xFF2563EB),
                            onClose: () => db.endSession(schoolId, classInfo.id, date, 'am'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSessionCard(
                            title: 'Afternoon Window (PM)',
                            time: '${pm?['start'] ?? '14:40'} - ${pm?['end'] ?? '15:00'}',
                            present: pmPresentCount,
                            total: students.length,
                            color: const Color(0xFF059669),
                            onClose: () => db.endSession(schoolId, classInfo.id, date, 'pm'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Student Roster Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Live Classroom Roster (${students.length} students)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Date: $date', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (students.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No students have enrolled in this class yet. Share the Student Entry Code.'),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: students.length,
                        itemBuilder: (context, i) {
                          final s = students[i];
                          final userAtt = attMap[s.uid] as Map?;
                          final amData = userAtt?['am'] as Map?;
                          final pmData = userAtt?['pm'] as Map?;
                          final amPresent = amData?['present'] == true;
                          final pmPresent = pmData?['present'] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (amPresent || pmPresent) ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                child: Text(
                                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: (amPresent || pmPresent) ? const Color(0xFF059669) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(s.hasTag ? 'Tag: ${s.tagUid}' : 'No RFID tag bound', style: const TextStyle(fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildAttendanceBadge('AM', amPresent, amData?['firstScan']),
                                  const SizedBox(width: 8),
                                  _buildAttendanceBadge('PM', pmPresent, pmData?['firstScan']),
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

  Widget _buildSessionCard({
    required String title,
    required String time,
    required int present,
    required int total,
    required Color color,
    required VoidCallback onClose,
  }) {
    final pct = total > 0 ? (present / total * 100).toInt() : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('$time IST', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('$present / $total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('Present ($pct%)', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const Spacer(),
                OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  child: const Text('Close Session', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceBadge(String window, bool present, dynamic firstScanTs) {
    String timeStr = '';
    if (firstScanTs is num && firstScanTs > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(firstScanTs.toInt());
      timeStr = ' • ${DateFormat('HH:mm').format(dt)}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: present ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: present ? const Color(0xFF10B981) : const Color(0xFFFCA5A5)),
      ),
      child: Text(
        '$window: ${present ? "Present$timeStr" : "Absent"}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: present ? const Color(0xFF059669) : const Color(0xFFDC2626),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 2: RFID BADGE ASSIGNMENT KIOSK
// ══════════════════════════════════════════════════════════════════

class _TeacherRfidKioskTab extends StatefulWidget {
  final String schoolId;
  final ClassInfo classInfo;

  const _TeacherRfidKioskTab({required this.schoolId, required this.classInfo});

  @override
  State<_TeacherRfidKioskTab> createState() => _TeacherRfidKioskTabState();
}

class _TeacherRfidKioskTabState extends State<_TeacherRfidKioskTab> {
  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final deviceId = widget.classInfo.deviceId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RFID Card Assignment Kiosk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              deviceId.isNotEmpty
                  ? 'Classroom Reader Linked: $deviceId'
                  : 'Warning: No classroom reader linked to this class. Ask admin to link reader MAC.',
              style: TextStyle(
                color: deviceId.isNotEmpty ? const Color(0xFF059669) : Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // Live Enrollment Status Banner
            if (deviceId.isNotEmpty)
              StreamBuilder<Map<String, dynamic>?>(
                stream: db.watchEnrollCommand(deviceId),
                builder: (context, snap) {
                  final cmd = snap.data;
                  if (cmd != null) {
                    final targetName = cmd['studentName'] ?? 'Student';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Waiting for Card Tap for: $targetName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1D4ED8))),
                                const SizedBox(height: 4),
                                const Text('Ask the student to tap their new RFID badge on the classroom reader now.', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 13)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => db.cancelCardAssignment(deviceId),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

            // Student Roster with Card Binding buttons
            StreamBuilder<List<StudentInfo>>(
              stream: db.watchStudentsForClass(widget.schoolId, widget.classInfo.id),
              builder: (context, snap) {
                final students = snap.data ?? [];

                if (students.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No students in this class yet.')),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.hasTag ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                          child: Icon(
                            s.hasTag ? Icons.credit_card_rounded : Icons.credit_card_off_rounded,
                            color: s.hasTag ? const Color(0xFF059669) : const Color(0xFFD97706),
                            size: 20,
                          ),
                        ),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(s.hasTag ? 'Tag UID: ${s.tagUid}' : 'Unassigned (Needs Card)'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: deviceId.isEmpty
                                  ? null
                                  : () async {
                                      await db.requestCardAssignment(deviceId, s.uid, studentName: s.name);
                                    },
                              icon: const Icon(Icons.sensors_rounded, size: 16),
                              label: Text(s.hasTag ? 'Reassign via Tap' : 'Assign via Tap'),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Enter UID manually',
                              onPressed: () => _openManualUidDialog(context, widget.schoolId, s),
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
  }

  void _openManualUidDialog(BuildContext context, String schoolId, StudentInfo student) {
    final controller = TextEditingController(text: student.tagUid);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Manual Card UID for ${student.name}'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Card UID (Hexadecimal e.g. 84F3EBA1)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<DbService>().setStudentTagUid(schoolId, student.uid, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 3: ATTENDANCE HISTORY & RECORDS
// ══════════════════════════════════════════════════════════════════

class _TeacherHistoryTab extends StatefulWidget {
  final String schoolId;
  final ClassInfo classInfo;

  const _TeacherHistoryTab({required this.schoolId, required this.classInfo});

  @override
  State<_TeacherHistoryTab> createState() => _TeacherHistoryTabState();
}

class _TeacherHistoryTabState extends State<_TeacherHistoryTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Attendance Archive', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(DateFormat('EEE, d MMM yyyy').format(_selectedDate)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _TeacherLiveRosterTab(
              schoolId: widget.schoolId,
              classInfo: widget.classInfo,
              date: dateStr,
            ),
          ],
        ),
      ),
    );
  }
}
