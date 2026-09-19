import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models.dart';

class DbService {
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  DatabaseReference ref(String path) => _root.child(path);

  String schoolPath(String schoolId) => 'schools/$schoolId';

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Creates a brand-new school with its first admin account (in-app sign-up).
  /// Returns the new school id.
  Future<String> createSchool({
    required String schoolName,
    required String adminName,
    required String email,
    required String password,
  }) async {
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = cred.user!.uid;
    final sid = _root.child('schools').push().key!;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _root.child('schools/$sid').set({
      'name': schoolName.trim(),
      'createdAt': now,
      'profile': {
        'name': adminName.trim(),
        'email': email.trim(),
        'timezone': 'Asia/Kolkata',
        'createdAt': now,
      },
      'admins': {uid: true},
      'classes': {},
      'devices': {},
      'teachers': {},
      'students': {},
      'entryLogs': {},
      'attendance': {},
    });
    await _root.child('userMeta/$uid').set({
      'role': 'admin',
      'schoolId': sid,
      'classId': '',
      'name': adminName.trim(),
      'email': email.trim(),
    });
    return sid;
  }

  // ──────────────────────────── CLASSES ────────────────────────────

  Future<List<ClassInfo>> fetchClasses(String schoolId) async {
    try {
      final snap = await _root.child('${schoolPath(schoolId)}/classes').get();
      final map = snap.value is Map ? (snap.value as Map) : {};
      return map.entries
          .map((e) => ClassInfo.fromSnapshot(e.key.toString(), e.value))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<ClassInfo>> watchClasses(String schoolId) {
    return _root.child('${schoolPath(schoolId)}/classes').onValue.map((event) {
      final map = event.snapshot.value is Map ? (event.snapshot.value as Map) : {};
      return map.entries
          .map((e) => ClassInfo.fromSnapshot(e.key.toString(), e.value))
          .toList();
    });
  }

  /// Creates a new class with distinct Student and Teacher join codes.
  Future<Map<String, String>> createClass(
    String schoolId, {
    required String name,
    List<String> teacherUids = const [],
    String amStart = '08:00',
    String amEnd = '08:20',
    String pmStart = '14:40',
    String pmEnd = '15:00',
  }) async {
    final cid = _root.child('${schoolPath(schoolId)}/classes').push().key!;
    final studentCode = 'STU-${_generateShortCode(5)}';
    final teacherCode = 'TCH-${_generateShortCode(5)}';
    final now = DateTime.now().millisecondsSinceEpoch;

    final teacherMap = <String, bool>{};
    for (final uid in teacherUids) {
      teacherMap[uid] = true;
    }

    // 1. Write class object
    await _root.child('${schoolPath(schoolId)}/classes/$cid').set({
      'name': name.trim(),
      'studentCode': studentCode,
      'teacherCode': teacherCode,
      'entryCode': studentCode, // legacy fallback
      'deviceId': '',
      'teacherUids': teacherMap,
      'teacherUid': teacherUids.isNotEmpty ? teacherUids.first : '',
      'windows': {
        'am': {'start': amStart, 'end': amEnd},
        'pm': {'start': pmStart, 'end': pmEnd},
      },
      'activeDays': [0, 1, 2, 3, 4, 5],
      'students': {},
      'sessions': {},
      'createdAt': now,
    });

    // 2. Write Student Registration Code
    await _root.child('registrationCodes/$studentCode').set({
      'schoolId': schoolId,
      'classId': cid,
      'className': name.trim(),
      'type': 'student',
      'createdAt': now,
    });

    // 3. Write Teacher Join Code
    await _root.child('registrationCodes/$teacherCode').set({
      'schoolId': schoolId,
      'classId': cid,
      'className': name.trim(),
      'type': 'teacher',
      'createdAt': now,
    });

    // Also write to legacy teacherJoinCodes path
    await _root.child('teacherJoinCodes/$teacherCode').set({
      'schoolId': schoolId,
      'classId': cid,
      'className': name.trim(),
      'createdAt': now,
      'used': false,
    });

    // 4. Assign initial teachers if provided
    for (final uid in teacherUids) {
      await assignTeacher(schoolId, cid, uid);
    }

    return {
      'classId': cid,
      'studentCode': studentCode,
      'teacherCode': teacherCode,
    };
  }

  Stream<DatabaseEvent> watchClass(String schoolId, String classId) =>
      _root.child('${schoolPath(schoolId)}/classes/$classId').onValue;

  Future<void> deleteClass(String schoolId, String classId, String studentCode, String teacherCode) async {
    await _root.child('${schoolPath(schoolId)}/classes/$classId').remove();
    if (studentCode.isNotEmpty) {
      await _root.child('registrationCodes/$studentCode').remove();
    }
    if (teacherCode.isNotEmpty) {
      await _root.child('registrationCodes/$teacherCode').remove();
      await _root.child('teacherJoinCodes/$teacherCode').remove();
    }
  }

  // ──────────────────────────── TEACHERS ────────────────────────────

  Future<List<TeacherRecord>> fetchTeachers(String schoolId) async {
    try {
      final snap = await _root.child('${schoolPath(schoolId)}/teachers').get();
      final map = snap.value is Map ? (snap.value as Map) : {};
      return map.entries
          .map((e) => TeacherRecord.fromSnapshot(e.key.toString(), e.value))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<TeacherRecord>> watchTeachers(String schoolId) {
    return _root.child('${schoolPath(schoolId)}/teachers').onValue.map((event) {
      final map = event.snapshot.value is Map ? (event.snapshot.value as Map) : {};
      return map.entries
          .map((e) => TeacherRecord.fromSnapshot(e.key.toString(), e.value))
          .toList();
    });
  }

  Future<void> assignTeacher(String schoolId, String classId, String teacherUid) async {
    await _root.child('${schoolPath(schoolId)}/teachers/$teacherUid/classIds/$classId').set(true);
    await _root.child('${schoolPath(schoolId)}/classes/$classId/teacherUids/$teacherUid').set(true);
    await _root.child('userMeta/$teacherUid/classIds/$classId').set(true);
    await _root.child('userMeta/$teacherUid/classId').set(classId);
  }

  Future<void> unassignTeacher(String schoolId, String classId, String teacherUid) async {
    await _root.child('${schoolPath(schoolId)}/teachers/$teacherUid/classIds/$classId').remove();
    await _root.child('${schoolPath(schoolId)}/classes/$classId/teacherUids/$teacherUid').remove();
    await _root.child('userMeta/$teacherUid/classIds/$classId').remove();
  }

  /// Self-registration for Teacher using a Teacher Code.
  Future<String> registerTeacherWithCode({
    required String code,
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanCode = code.trim().toUpperCase();

    // Look up in registrationCodes first
    final regSnap = await _root.child('registrationCodes/$cleanCode').get();
    Map? codeData;
    if (regSnap.exists && regSnap.value is Map) {
      codeData = regSnap.value as Map;
      if (codeData['type'] != null && codeData['type'] != 'teacher') {
        return 'This is a student entry code, not a teacher join code.';
      }
    } else {
      // Fallback check legacy teacherJoinCodes
      final legSnap = await _root.child('teacherJoinCodes/$cleanCode').get();
      if (legSnap.exists && legSnap.value is Map) {
        codeData = legSnap.value as Map;
      }
    }

    if (codeData == null) {
      return 'Invalid teacher join code. Please check with your school administrator.';
    }

    final schoolId = codeData['schoolId']?.toString() ?? '';
    final classId = codeData['classId']?.toString() ?? '';
    if (schoolId.isEmpty) return 'Invalid school code data.';

    // Create Firebase Auth account
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = cred.user!.uid;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Save teacher profile under school
    await _root.child('${schoolPath(schoolId)}/teachers/$uid').set({
      'name': name.trim(),
      'email': email.trim(),
      'classIds': classId.isNotEmpty ? {classId: true} : {},
      'createdAt': now,
    });

    // Assign to class if code has classId
    if (classId.isNotEmpty) {
      await _root.child('${schoolPath(schoolId)}/classes/$classId/teacherUids/$uid').set(true);
    }

    // Set user metadata
    await _root.child('userMeta/$uid').set({
      'role': 'teacher',
      'schoolId': schoolId,
      'classId': classId,
      'classIds': classId.isNotEmpty ? {classId: true} : {},
      'name': name.trim(),
      'email': email.trim(),
    });

    return '';
  }

  /// Allows a logged-in teacher to claim another class via teacher code
  Future<String> claimClassWithTeacherCode(String schoolId, String teacherUid, String code) async {
    final cleanCode = code.trim().toUpperCase();
    final snap = await _root.child('registrationCodes/$cleanCode').get();
    if (!snap.exists || snap.value is! Map) {
      return 'Invalid teacher code.';
    }
    final data = snap.value as Map;
    if (data['type'] != null && data['type'] != 'teacher') {
      return 'This is a student code, not a teacher code.';
    }
    if (data['schoolId'] != schoolId) {
      return 'This code belongs to a different school.';
    }
    final classId = data['classId']?.toString() ?? '';
    if (classId.isEmpty) return 'Code is not linked to a class.';

    await assignTeacher(schoolId, classId, teacherUid);
    return '';
  }

  // ──────────────────────────── STUDENTS ────────────────────────────

  Future<List<StudentInfo>> fetchStudentsForClass(String schoolId, String classId) async {
    try {
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
    } catch (_) {
      return [];
    }
  }

  Stream<List<StudentInfo>> watchStudentsForClass(String schoolId, String classId) {
    return _root.child('${schoolPath(schoolId)}/students').onValue.map((event) {
      final map = event.snapshot.value is Map ? (event.snapshot.value as Map) : {};
      final list = <StudentInfo>[];
      map.forEach((uid, val) {
        if (val is Map && val['classId'] == classId) {
          list.add(StudentInfo.fromSnapshot(uid.toString(), val));
        }
      });
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Self-registration for Student using a Student Entry Code.
  Future<String> registerStudentWithCode({
    required String code,
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanCode = code.trim().toUpperCase();

    String schoolId = '';
    String classId = '';

    // 1. Try registrationCodes (new format)
    final codeSnap = await _root.child('registrationCodes/$cleanCode').get();
    if (codeSnap.exists && codeSnap.value is Map) {
      final codeData = codeSnap.value as Map;
      if (codeData['type'] == 'teacher') {
        return 'This is a teacher code. Please use the Teacher Registration tab.';
      }
      schoolId = codeData['schoolId']?.toString() ?? '';
      classId = codeData['classId']?.toString() ?? '';
    }

    // 2. Fallback: search all schools/classes for matching entryCode or studentCode
    if (schoolId.isEmpty || classId.isEmpty) {
      final schoolsSnap = await _root.child('schools').get();
      if (schoolsSnap.exists && schoolsSnap.value is Map) {
        final schools = schoolsSnap.value as Map;
        outer:
        for (final schoolEntry in schools.entries) {
          final sid = schoolEntry.key.toString();
          final schoolData = schoolEntry.value as Map?;
          final classesMap = schoolData?['classes'];
          if (classesMap is Map) {
            for (final classEntry in classesMap.entries) {
              final cid = classEntry.key.toString();
              final classData = classEntry.value as Map?;
              if (classData == null) continue;
              final ec = classData['entryCode']?.toString() ?? '';
              final sc = classData['studentCode']?.toString() ?? '';
              if (ec.toUpperCase() == cleanCode || sc.toUpperCase() == cleanCode) {
                schoolId = sid;
                classId = cid;
                // Backfill registrationCodes for future lookups
                await _root.child('registrationCodes/$cleanCode').set({
                  'schoolId': sid,
                  'classId': cid,
                  'className': classData['name']?.toString() ?? '',
                  'type': 'student',
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                });
                break outer;
              }
            }
          }
        }
      }
    }

    if (schoolId.isEmpty || classId.isEmpty) {
      return 'Entry code is invalid. Please ask your teacher for the class student code.';
    }

    // Create Firebase Auth user
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = cred.user!.uid;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Add student to school student registry
    await _root.child('${schoolPath(schoolId)}/students/$uid').set({
      'name': name.trim(),
      'email': email.trim(),
      'classId': classId,
      'schoolId': schoolId,
      'tagUid': '',
      'createdAt': now,
    });

    // 2. Add student to class membership roster
    await _root.child('${schoolPath(schoolId)}/classes/$classId/students/$uid').set(true);

    // 3. Set user metadata for dynamic role routing
    await _root.child('userMeta/$uid').set({
      'role': 'student',
      'schoolId': schoolId,
      'classId': classId,
      'name': name.trim(),
      'email': email.trim(),
    });

    // 4. Also store in pendingRegistrations for audit
    await _root.child('pendingRegistrations/$uid').set({
      'code': cleanCode,
      'name': name.trim(),
      'email': email.trim(),
      'schoolId': schoolId,
      'classId': classId,
      'ts': now,
    });

    return '';
  }

  // ──────────────────────────── DEVICES & RFID ────────────────────────────

  Future<List<DeviceRecord>> fetchDevices(String schoolId) async {
    try {
      final snap = await _root.child('devices').get();
      final map = snap.value is Map ? (snap.value as Map) : {};
      return map.entries
          .map((e) => DeviceRecord.fromSnapshot(e.key.toString(), e.value))
          .where((d) => d.schoolId == schoolId)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<DeviceRecord>> watchDevices(String schoolId) {
    return _root.child('devices').onValue.map((event) {
      final map = event.snapshot.value is Map ? (event.snapshot.value as Map) : {};
      return map.entries
          .map((e) => DeviceRecord.fromSnapshot(e.key.toString(), e.value))
          .where((d) => d.schoolId == schoolId)
          .toList();
    });
  }

  Future<void> linkDeviceByCode(String schoolId, String code, String classId, String label) async {
    final mac = code.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (mac.isEmpty || mac.length != 12) {
      throw ArgumentError('Invalid pair code. Expected the 12-hex hardware MAC code.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _root.child('devices/$mac').update({
      'label': label.trim().isEmpty ? 'Classroom Reader' : label.trim(),
      'schoolId': schoolId,
      'classId': classId,
      'linkedAt': now,
    });
    await _root.child('${schoolPath(schoolId)}/classes/$classId/deviceId').set(mac);
    await _root.child('devices/$mac/presence').set(null);
  }

  Future<void> unlinkDevice(String schoolId, String mac, String classId) async {
    await _root.child('devices/$mac/schoolId').set('');
    await _root.child('devices/$mac/classId').set('');
    await _root.child('devices/$mac/presence').update({
      'linked': false,
      'schoolId': '',
      'classId': '',
    });
    if (classId.isNotEmpty) {
      await _root.child('${schoolPath(schoolId)}/classes/$classId/deviceId').set('');
    }
  }

  /// Sends a card assignment command to the hardware reader.
  Future<void> requestCardAssignment(String deviceId, String studentUid, {String studentName = ''}) async {
    if (deviceId.isEmpty) return;
    await _root.child('devices/$deviceId/enrollCommand').set({
      'studentUid': studentUid,
      'studentName': studentName,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'expiresAt': DateTime.now().add(const Duration(seconds: 90)).millisecondsSinceEpoch,
    });
  }

  Future<void> cancelCardAssignment(String deviceId) async {
    if (deviceId.isEmpty) return;
    await _root.child('devices/$deviceId/enrollCommand').remove();
  }

  Stream<Map<String, dynamic>?> watchEnrollCommand(String deviceId) {
    if (deviceId.isEmpty) return Stream.value(null);
    return _root.child('devices/$deviceId/enrollCommand').onValue.map((event) {
      final val = event.snapshot.value;
      if (val is Map) {
        return Map<String, dynamic>.from(val);
      }
      return null;
    });
  }

  /// Manually bind or unbind an RFID card UID to a student
  Future<void> setStudentTagUid(String schoolId, String studentUid, String tagUid) async {
    final clean = tagUid.trim().toUpperCase();
    await _root.child('${schoolPath(schoolId)}/students/$studentUid/tagUid').set(clean);
  }

  // ──────────────────────────── ATTENDANCE & SESSIONS ────────────────────────────

  Future<double> fetchAttendancePercentage(String schoolId, String classId) async {
    try {
      final snap = await _root.child('${schoolPath(schoolId)}/attendance/$classId').get();
      final map = snap.value is Map ? (snap.value as Map) : {};
      int totalWindows = 0;
      int presentWindows = 0;
      map.forEach((dateStr, byUid) {
        if (byUid is Map) {
          byUid.forEach((uid, userData) {
            if (userData is Map) {
              final am = userData['am'];
              final pm = userData['pm'];
              if (am is Map) {
                totalWindows++;
                if (am['present'] == true) presentWindows++;
              }
              if (pm is Map) {
                totalWindows++;
                if (pm['present'] == true) presentWindows++;
              }
            }
          });
        }
      });
      if (totalWindows == 0) return 0.0;
      return (presentWindows / totalWindows) * 100.0;
    } catch (_) {
      return 0.0;
    }
  }

  Future<Map<String, AttendanceWindow>> fetchAttendanceForClassOn(
    String schoolId,
    String classId,
    String date,
  ) async {
    try {
      final snap = await _root.child('${schoolPath(schoolId)}/attendance/$classId/$date').get();
      final map = snap.value is Map ? (snap.value as Map) : {};
      final result = <String, AttendanceWindow>{};
      map.forEach((uid, value) {
        if (value is Map) {
          // Check AM or PM
          final am = value['am'];
          final pm = value['pm'];
          final isPresent = (am is Map && am['present'] == true) || (pm is Map && pm['present'] == true);
          result[uid.toString()] = AttendanceWindow(
            present: isPresent,
            firstScan: (am is Map ? am['firstScan'] : pm is Map ? pm['firstScan'] : null) as int?,
            lastScan: (pm is Map ? pm['lastScan'] : am is Map ? am['lastScan'] : null) as int?,
          );
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Stream<DatabaseEvent> watchClassAttendanceDate(String schoolId, String classId, String date) {
    return _root.child('${schoolPath(schoolId)}/attendance/$classId/$date').onValue;
  }

  Future<void> endSession(String schoolId, String classId, String date, String window) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _root.child('${schoolPath(schoolId)}/classes/$classId/sessions/$date/$window').set({
      'status': 'closed',
      'closedBy': 'teacher',
      'closedAt': now,
    });
  }

  Future<Map<String, dynamic>> fetchStudentAttendance(
    String schoolId,
    String classId,
    String studentUid,
  ) async {
    try {
      final snap = await _root.child('${schoolPath(schoolId)}/attendance/$classId').get();
      final map = snap.value is Map ? (snap.value as Map) : {};
      int present = 0, total = 0;
      final days = <String, Map<String, bool>>{};
      map.forEach((dateStr, byUid) {
        if (byUid is Map) {
          final userData = byUid[studentUid];
          if (userData is Map) {
            final dateKey = dateStr.toString();
            final amPresent = userData['am'] is Map && (userData['am'] as Map)['present'] == true;
            final pmPresent = userData['pm'] is Map && (userData['pm'] as Map)['present'] == true;
            days[dateKey] = {'am': amPresent, 'pm': pmPresent};
            if (userData['am'] is Map) {
              total++;
              if (amPresent) present++;
            }
            if (userData['pm'] is Map) {
              total++;
              if (pmPresent) present++;
            }
          }
        }
      });
      final sortedDays = Map.fromEntries(days.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
      return {
        'present': present,
        'total': total,
        'percentage': total > 0 ? (present / total) * 100.0 : 0.0,
        'days': sortedDays,
      };
    } catch (_) {
      return {'present': 0, 'total': 0, 'percentage': 0.0, 'days': <String, Map<String, bool>>{}};
    }
  }

  // ──────────────────────────── CODE HELPERS ────────────────────────────

  String _generateShortCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }
}