import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models.dart';

class DbService {
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  DatabaseReference ref(String path) => _root.child(path);

  String schoolPath(String schoolId) => 'schools/$schoolId';

  Future<List<ClassInfo>> fetchClasses(String schoolId) async {
    final snap = await _root.child('${schoolPath(schoolId)}/classes').get();
    final map = snap.value is Map ? (snap.value as Map) : {};
    return map.entries
        .map((e) => ClassInfo.fromSnapshot(e.key.toString(), e.value))
        .toList();
  }

  Future<List<TeacherRecord>> fetchTeachers(String schoolId) async {
    final snap = await _root.child('${schoolPath(schoolId)}/teachers').get();
    final map = snap.value is Map ? (snap.value as Map) : {};
    return map.entries
        .map((e) => TeacherRecord.fromSnapshot(e.key.toString(), e.value))
        .toList();
  }

  Future<List<DeviceRecord>> fetchDevices(String schoolId) async {
    final snap = await _root.child('${schoolPath(schoolId)}/devices').get();
    final map = snap.value is Map ? (snap.value as Map) : {};
    return map.entries
        .map((e) => DeviceRecord.fromSnapshot(e.key.toString(), e.value))
        .where((d) => d.label.isNotEmpty || d.authEmail.isNotEmpty)
        .toList();
  }

  Future<List<StudentInfo>> fetchStudentsForClass(String schoolId, String classId) async {
    final clsSnap = await _root.child('${schoolPath(schoolId)}/classes/$classId/students').get();
    final ids = clsSnap.value is Map ? (clsSnap.value as Map).keys : <Object?>[];
    final result = <StudentInfo>[];
    for (final uid in ids) {
      final s = await _root.child('${schoolPath(schoolId)}/students/${uid.toString()}').get();
      if (s.exists) {
        result.add(StudentInfo.fromSnapshot(uid.toString(), s.value));
      }
    }
    return result;
  }

  Future<String> createClass(String schoolId, {
    required String name,
    required List<String> teacherUids,
  }) async {
    final cid = _root.child('${schoolPath(schoolId)}/classes').push().key!;
    final code = _generateCode();
    await _root.child('${schoolPath(schoolId)}/classes/$cid').set({
      'name': name,
      'teacherUid': teacherUids.isNotEmpty ? teacherUids.first : '',
      'deviceId': '',
      'entryCode': code,
      'windows': {
        'am': {'start': '08:00', 'end': '08:20'},
        'pm': {'start': '14:40', 'end': '15:00'},
      },
      'activeDays': [0, 1, 2, 3, 4, 5],
      'students': {},
      'sessions': {},
    });
    await _root.child('registrationCodes/$code').set({
      'schoolId': schoolId,
      'classId': cid,
      'className': name,
    });
    if (teacherUids.isNotEmpty) {
      await assignTeacher(schoolId, cid, teacherUids.first);
    }
    return code;
  }

  Future<void> assignTeacher(String schoolId, String classId, String teacherUid) async {
    await _root.child('${schoolPath(schoolId)}/classes/$classId/teacherUid').set(teacherUid);
    await _root.child('${schoolPath(schoolId)}/teachers/$teacherUid/classId').set(classId);
  }

  Future<Map<String, String>> createTeacher(String schoolId, {
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = cred.user!.uid;
    await _root.child('${schoolPath(schoolId)}/teachers/$uid').set({
      'name': name.trim(),
      'email': email.trim(),
      'classId': '',
    });
    await _root.child('userMeta/$uid').set({
      'role': 'teacher',
      'schoolId': schoolId,
      'classId': '',
    });
    return {'uid': uid};
  }

  Future<Map<String, String>> createDevice(String schoolId, String classId, String label) async {
    final password = _generatePassword();
    final email = 'device-${DateTime.now().millisecondsSinceEpoch}@attendor.in';
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final did = cred.user!.uid;
    await _root.child('${schoolPath(schoolId)}/devices/$did').set({
      'label': label.trim(),
      'schoolId': schoolId,
      'classId': classId,
      'authEmail': email,
    });
    await _root.child('${schoolPath(schoolId)}/classes/$classId/deviceId').set(did);
    return {'deviceId': did, 'authEmail': email, 'authPassword': password};
  }

  Stream<DatabaseEvent> watchClass(String schoolId, String classId) =>
      _root.child('${schoolPath(schoolId)}/classes/$classId').onValue;

  Future<Map<String, AttendanceWindow>> fetchAttendanceForClassOn(
    String schoolId,
    String classId,
    String date,
  ) async {
    final snap = await _root
        .child('${schoolPath(schoolId)}/attendance/$classId/$date')
        .get();
    final map = snap.value is Map ? (snap.value as Map) : {};
    final result = <String, AttendanceWindow>{};
    map.forEach((key, value) {
      result[key.toString()] = AttendanceWindow.fromSnapshot(value);
    });
    return result;
  }

  Future<void> endSession(String schoolId, String classId, String date, String window) async {
    await _root
        .child('${schoolPath(schoolId)}/classes/$classId/sessions/$date/$window')
        .set({'status': 'closed', 'closedBy': 'teacher'});
  }

  Future<void> requestCardAssignment(String schoolId, String deviceId, String studentUid) async {
    await _root.child('${schoolPath(schoolId)}/devices/$deviceId/enrollCommand').set({
      'studentUid': studentUid,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'expiresAt': DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    });
  }

  Future<Map<DateTime, Map<String, AttendanceWindow>>> fetchMyAttendance(
    String schoolId,
    String classId,
  ) async {
    final snap = await _root.child('${schoolPath(schoolId)}/attendance/$classId').get();
    final map = snap.value is Map ? (snap.value as Map) : {};
    final result = <DateTime, Map<String, AttendanceWindow>>{};
    final now = DateTime.now();
    map.forEach((dateStr, byUid) {
      final date = DateTime.tryParse(dateStr.toString());
      if (date == null) return;
      if (!now.difference(date).inDays.isNegative && now.difference(date).inDays <= 60) {
        final byUidMap = byUid as Map;
        final mine = byUidMap[currentUid];
        if (mine != null) {
          final w = mine as Map;
          final am = AttendanceWindow.fromSnapshot(w['am']);
          final pm = AttendanceWindow.fromSnapshot(w['pm']);
          result[date] = {'am': am, 'pm': pm};
        }
      }
    });
    final sorted = result.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final d in sorted) d: result[d]!};
  }

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final r = Random();
    return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
  }
}