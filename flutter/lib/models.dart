enum Role { admin, teacher, student }

class UserMeta {
  final String uid;
  final Role role;
  final String schoolId;
  final String classId;
  final List<String> classIds;
  final String name;
  final String email;

  UserMeta({
    required this.uid,
    required this.role,
    required this.schoolId,
    required this.classId,
    this.classIds = const [],
    this.name = '',
    this.email = '',
  });

  static UserMeta? fromSnapshot(String uid, Object? value) {
    if (value is! Map) return null;
    final roleStr = value['role']?.toString();
    final role = Role.values.where((r) => r.name == roleStr).firstOrNull;
    if (role == null) return null;

    final classIdsRaw = value['classIds'];
    List<String> parsedClassIds = [];
    if (classIdsRaw is List) {
      parsedClassIds = classIdsRaw.map((e) => e.toString()).toList();
    } else if (classIdsRaw is Map) {
      parsedClassIds = classIdsRaw.keys.map((e) => e.toString()).toList();
    }

    final primaryClassId = value['classId']?.toString() ??
        (parsedClassIds.isNotEmpty ? parsedClassIds.first : '');

    return UserMeta(
      uid: uid,
      role: role,
      schoolId: value['schoolId']?.toString() ?? '',
      classId: primaryClassId,
      classIds: parsedClassIds,
      name: value['name']?.toString() ?? '',
      email: value['email']?.toString() ?? '',
    );
  }
}

class ClassInfo {
  final String id;
  final String name;
  final List<String> teacherUids;
  final String deviceId;
  final String studentCode;
  final String teacherCode;
  final Map<String, Map<String, String>> windows;
  final List<int> activeDays;
  final List<String> studentIds;

  ClassInfo({
    required this.id,
    required this.name,
    required this.teacherUids,
    required this.deviceId,
    required this.studentCode,
    required this.teacherCode,
    required this.windows,
    required this.activeDays,
    required this.studentIds,
  });

  // Legacy alias for student code
  String get entryCode => studentCode;

  static ClassInfo fromSnapshot(String id, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};

    // Parse time windows
    final windows = <String, Map<String, String>>{
      'am': {'start': '08:00', 'end': '08:20'},
      'pm': {'start': '14:40', 'end': '15:00'},
    };
    if (map['windows'] is Map) {
      (map['windows'] as Map).forEach((k, v) {
        if (v is Map) {
          windows[k.toString()] = {
            'start': v['start']?.toString() ?? '08:00',
            'end': v['end']?.toString() ?? '08:20',
          };
        }
      });
    }

    // Parse students (can be Map of uid->true or List of uids)
    List<String> students = [];
    final studentsRaw = map['students'];
    if (studentsRaw is Map) {
      students = studentsRaw.keys.map((e) => e.toString()).toList();
    } else if (studentsRaw is List) {
      students = studentsRaw.map((e) => e.toString()).toList();
    }

    // Parse active days (safe int conversion, default Mon-Sat [0..5])
    List<int> active = [0, 1, 2, 3, 4, 5];
    final activeRaw = map['activeDays'];
    if (activeRaw is List) {
      active = activeRaw
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
      if (active.isEmpty) active = [0, 1, 2, 3, 4, 5];
    } else if (activeRaw is Map) {
      active = activeRaw.values
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
      if (active.isEmpty) active = [0, 1, 2, 3, 4, 5];
    }

    // Parse teachers (map, list, or single legacy string)
    List<String> teacherUids = [];
    final teacherUidsRaw = map['teacherUids'];
    if (teacherUidsRaw is List) {
      teacherUids = teacherUidsRaw.map((e) => e.toString()).toList();
    } else if (teacherUidsRaw is Map) {
      teacherUids = teacherUidsRaw.keys.map((e) => e.toString()).toList();
    } else {
      final single = map['teacherUid']?.toString() ?? '';
      if (single.isNotEmpty) {
        teacherUids = [single];
      }
    }

    final studentCode = map['studentCode']?.toString() ??
        map['entryCode']?.toString() ??
        '';
    final teacherCode = map['teacherCode']?.toString() ?? '';

    return ClassInfo(
      id: id,
      name: map['name']?.toString() ?? 'Untitled Class',
      teacherUids: teacherUids,
      deviceId: map['deviceId']?.toString() ?? '',
      studentCode: studentCode,
      teacherCode: teacherCode,
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
  final String classId;
  final String schoolId;

  StudentInfo({
    required this.uid,
    required this.name,
    required this.email,
    required this.tagUid,
    this.classId = '',
    this.schoolId = '',
  });

  bool get hasTag => tagUid.isNotEmpty;

  static StudentInfo fromSnapshot(String uid, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};
    return StudentInfo(
      uid: uid,
      name: map['name']?.toString() ?? 'Student',
      email: map['email']?.toString() ?? '',
      tagUid: map['tagUid']?.toString() ?? '',
      classId: map['classId']?.toString() ?? '',
      schoolId: map['schoolId']?.toString() ?? '',
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
    List<String> classIds = [];
    if (classIdsRaw is List) {
      classIds = classIdsRaw.map((e) => e.toString()).toList();
    } else if (classIdsRaw is Map) {
      classIds = classIdsRaw.keys.map((e) => e.toString()).toList();
    } else {
      final single = map['classId']?.toString() ?? '';
      if (single.isNotEmpty) classIds = [single];
    }
    return TeacherRecord(
      uid: uid,
      name: map['name']?.toString() ?? 'Teacher',
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
  bool get isOnline {
    if (presenceTs == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - presenceTs!) < 45000; // ping every 10-30s
  }

  static DeviceRecord fromSnapshot(String id, Object? value) {
    final map = (value is Map) ? value : <String, Object?>{};
    final pr = map['presence'];
    return DeviceRecord(
      id: id,
      label: map['label']?.toString() ?? 'Attendance Reader',
      schoolId: map['schoolId']?.toString() ?? '',
      classId: map['classId']?.toString() ?? '',
      authEmail: map['authEmail']?.toString() ?? '',
      presenceLinked: pr is Map ? pr['linked'] == true : false,
      presenceTs: pr is Map ? (pr['ts'] as num?)?.toInt() : null,
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
      firstScan: (value['firstScan'] as num?)?.toInt(),
      lastScan: (value['lastScan'] as num?)?.toInt(),
    );
  }
}