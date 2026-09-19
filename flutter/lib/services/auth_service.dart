import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import 'db_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  User? user;
  UserMeta? meta;
  bool _loadingMeta = false;
  bool initialized = false;

  AuthService() {
    _auth.authStateChanges().listen((u) async {
      user = u;
      if (u == null) {
        meta = null;
        initialized = true;
        notifyListeners();
      } else {
        await loadMeta();
        initialized = true;
        notifyListeners();
      }
    });
  }

  UserMeta? get currentMeta => meta;

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await loadMeta();
  }

  Future<String> registerStudent({
    required String code,
    required String name,
    required String email,
    required String password,
    required DbService db,
  }) async {
    final err = await db.registerStudentWithCode(
      code: code,
      name: name,
      email: email,
      password: password,
    );
    if (err.isEmpty) {
      await loadMeta();
    }
    return err;
  }

  Future<String> registerTeacher({
    required String code,
    required String name,
    required String email,
    required String password,
    required DbService db,
  }) async {
    final err = await db.registerTeacherWithCode(
      code: code,
      name: name,
      email: email,
      password: password,
    );
    if (err.isEmpty) {
      await loadMeta();
    }
    return err;
  }

  Future<void> loadMeta() async {
    final u = user;
    if (u == null) {
      meta = null;
      notifyListeners();
      return;
    }
    if (_loadingMeta) return;
    _loadingMeta = true;

    try {
      // 1. First try reading userMeta/$uid directly
      final snap = await _root.child('userMeta/${u.uid}').get();
      var newMeta = UserMeta.fromSnapshot(u.uid, snap.value);

      // 2. If not found, look for fallback across schools
      if (newMeta == null) {
        newMeta = await _recoverMeta(u.uid);
      }

      meta = newMeta;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading userMeta: $e');
    } finally {
      _loadingMeta = false;
    }
  }

  /// Self-healing fallback: detects role from school nodes if userMeta was missing
  Future<UserMeta?> _recoverMeta(String uid) async {
    try {
      final schoolsSnap = await _root.child('schools').get();
      if (!schoolsSnap.exists || schoolsSnap.value is! Map) return null;
      final schoolsMap = schoolsSnap.value as Map;

      for (final entry in schoolsMap.entries) {
        final sid = entry.key.toString();
        final sdata = entry.value as Map;

        // Check Admin
        final admins = sdata['admins'];
        if (admins is Map && admins[uid] == true) {
          final m = UserMeta(
            uid: uid,
            role: Role.admin,
            schoolId: sid,
            classId: '',
            name: sdata['profile']?['name']?.toString() ?? 'Admin',
            email: user?.email ?? '',
          );
          // Restore userMeta node
          await _root.child('userMeta/$uid').set({
            'role': 'admin',
            'schoolId': sid,
            'classId': '',
            'name': m.name,
            'email': m.email,
          });
          return m;
        }

        // Check Teacher
        final teachers = sdata['teachers'];
        if (teachers is Map && teachers[uid] != null) {
          final tdata = teachers[uid] as Map;
          final cids = (tdata['classIds'] as Map?)?.keys.map((e) => e.toString()).toList() ?? <String>[];
          final m = UserMeta(
            uid: uid,
            role: Role.teacher,
            schoolId: sid,
            classId: cids.isNotEmpty ? cids.first : '',
            classIds: cids,
            name: tdata['name']?.toString() ?? 'Teacher',
            email: tdata['email']?.toString() ?? (user?.email ?? ''),
          );
          await _root.child('userMeta/$uid').set({
            'role': 'teacher',
            'schoolId': sid,
            'classId': m.classId,
            'classIds': {for (final c in cids) c: true},
            'name': m.name,
            'email': m.email,
          });
          return m;
        }

        // Check Student
        final students = sdata['students'];
        if (students is Map && students[uid] != null) {
          final s = students[uid] as Map;
          final cid = s['classId']?.toString() ?? '';
          final m = UserMeta(
            uid: uid,
            role: Role.student,
            schoolId: sid,
            classId: cid,
            name: s['name']?.toString() ?? 'Student',
            email: s['email']?.toString() ?? (user?.email ?? ''),
          );
          await _root.child('userMeta/$uid').set({
            'role': 'student',
            'schoolId': sid,
            'classId': cid,
            'name': m.name,
            'email': m.email,
          });
          return m;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> logout() async {
    meta = null;
    await _auth.signOut();
    notifyListeners();
  }
}
