enum Role { admin, teacher, student }

class UserMeta {
  final String uid;
  final Role role;
  final String schoolId;
  final String classId;

  UserMeta({
    required this.uid,
    required this.role,
    required this.schoolId,
    required this.classId,
  });

  static UserMeta? fromSnapshot(String uid, Object? value) {
    if (value is! Map) return null;
    final roleStr = value['role']?.toString();
    final role = Role.values.where((r) => r.name == roleStr).firstOrNull;
    if (role == null) return null;
    return UserMeta(
      uid: uid,
      role: role,
      schoolId: value['schoolId']?.toString() ?? '',
      classId: value['classId']?.toString() ?? '',
    );
  }
}

class ClassInfo {
  final String id;
  final String name;
  final String teacherUid;
  final String deviceId;
  final String entryCode;
  final Map<String, Map<String, String>> windows;
  final List<int> activeDays;
  final List<String> studentIds;

  ClassInfo({
    required this.id,
    required this.name,
    required this.teacherUid,
    required this.deviceId,
    required this.entryCode,
    required this.windows,
    required this.activeDays,
    required this.studentIds,
  });

  static ClassInfo fromSnapshot(String id, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};
    final windows = <String, Map<String, String>>{};
    (map['windows'] as Map?)?.forEach((k, v) {
      final w = (v as Map?) ?? {};
      windows[k.toString()] = {
        'start': w['start']?.toString() ?? '',
        'end': w['end']?.toString() ?? '',
      };
    });
    final students = (map['students'] as Map?)?.keys.map((e) => e.toString()).toList() ?? <String>[];
    final active = (map['activeDays'] as List?)?.map((e) => int.parse(e.toString())).toList() ?? <int>[];
    return ClassInfo(
      id: id,
      name: map['name']?.toString() ?? '',
      teacherUid: map['teacherUid']?.toString() ?? '',
      deviceId: map['deviceId']?.toString() ?? '',
      entryCode: map['entryCode']?.toString() ?? '',
      windows: windows,
      activeDays: active,
      studentIds: students,
    );
  }
}

class StudentInfo {
  final String uid;
  final String name;
  final String email;
  final String tagUid;

  StudentInfo({
    required this.uid,
    required this.name,
    required this.email,
    required this.tagUid,
  });

  static StudentInfo fromSnapshot(String uid, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};
    return StudentInfo(
      uid: uid,
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      tagUid: map['tagUid']?.toString() ?? '',
    );
  }
}

class TeacherRecord {
  final String uid;
  final String name;
  final String email;
  final String classId;

  TeacherRecord({
    required this.uid,
    required this.name,
    required this.email,
    required this.classId,
  });

  static TeacherRecord fromSnapshot(String uid, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};
    return TeacherRecord(
      uid: uid,
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      classId: map['classId']?.toString() ?? '',
    );
  }
}

class DeviceRecord {
  final String id;
  final String label;
  final String classId;
  final String authEmail;

  DeviceRecord({
    required this.id,
    required this.label,
    required this.classId,
    required this.authEmail,
  });

  static DeviceRecord fromSnapshot(String id, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};
    return DeviceRecord(
      id: id,
      label: map['label']?.toString() ?? '',
      classId: map['classId']?.toString() ?? '',
      authEmail: map['authEmail']?.toString() ?? '',
    );
  }
}

class AttendanceWindow {
  final bool present;
  final int? firstScan;
  final int? lastScan;

  AttendanceWindow({required this.present, this.firstScan, this.lastScan});

  static AttendanceWindow fromSnapshot(Object? value) {
    if (value is! Map) return AttendanceWindow(present: false);
    return AttendanceWindow(
      present: value['present'] == true,
      firstScan: value['firstScan'] as int?,
      lastScan: value['lastScan'] as int?,
    );
  }
}