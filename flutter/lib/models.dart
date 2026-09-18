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
  final List<String> teacherUids;
  final String deviceId;
  final String entryCode;
  final Map<String, Map<String, String>> windows;
  final List<int> activeDays;
  final List<String> studentIds;

  ClassInfo({
    required this.id,
    required this.name,
    required this.teacherUids,
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
    final teacherUidsRaw = map['teacherUids'];
    List<String> teacherUids;
    if (teacherUidsRaw is List) {
      teacherUids = teacherUidsRaw.map((e) => e.toString()).toList();
    } else if (teacherUidsRaw is Map) {
      teacherUids = teacherUidsRaw.keys.map((e) => e.toString()).toList();
    } else {
      final single = map['teacherUid']?.toString() ?? '';
      teacherUids = single.isNotEmpty ? [single] : [];
    }
    return ClassInfo(
      id: id,
      name: map['name']?.toString() ?? '',
      teacherUids: teacherUids,
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
  final List<String> classIds;

  TeacherRecord({
    required this.uid,
    required this.name,
    required this.email,
    required this.classIds,
  });

  static TeacherRecord fromSnapshot(String uid, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};
    final classIdsRaw = map['classIds'];
    List<String> classIds;
    if (classIdsRaw is List) {
      classIds = classIdsRaw.map((e) => e.toString()).toList();
    } else if (classIdsRaw is Map) {
      classIds = classIdsRaw.keys.map((e) => e.toString()).toList();
    } else {
      final single = map['classId']?.toString() ?? '';
      classIds = single.isNotEmpty ? [single] : [];
    }
    return TeacherRecord(
      uid: uid,
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      classIds: classIds,
    );
  }
}

class DeviceRecord {
  final String id;
  final String label;
  final String schoolId;
  final String classId;
  final String authEmail;
  final bool presenceLinked;
  final int? presenceTs;

  DeviceRecord({
    required this.id,
    required this.label,
    required this.schoolId,
    required this.classId,
    required this.authEmail,
    this.presenceLinked = false,
    this.presenceTs,
  });

  bool get isLinked => classId.isNotEmpty;

  static DeviceRecord fromSnapshot(String id, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};
    final pr = map['presence'];
    return DeviceRecord(
      id: id,
      label: map['label']?.toString() ?? '',
      schoolId: map['schoolId']?.toString() ?? '',
      classId: map['classId']?.toString() ?? '',
      authEmail: map['authEmail']?.toString() ?? '',
      presenceLinked: pr is Map ? pr['linked'] == true : false,
      presenceTs: pr is Map ? pr['ts'] as int? : null,
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