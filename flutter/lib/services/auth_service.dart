import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  User? user;
  UserMeta? meta;
  bool _loadingMeta = false;

  AuthService() {
    _auth.authStateChanges().listen((u) async {
      user = u;
      if (u == null) {
        meta = null;
        notifyListeners();
      } else {
        await loadMeta();
      }
    });
  }

  UserMeta? get currentMeta => meta;

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    // authStateChanges listener will fire and call loadMeta()
  }

  Future<String> registerStudent({required String code, required String name, required String email, required String password}) async {
    final codeSnap = await _root.child('registrationCodes/$code').get();
    if (!codeSnap.exists) {
      return 'Entry code is invalid or already used.';
    }
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await _root
        .child('pendingRegistrations/${cred.user!.uid}')
        .set({'code': code.trim(), 'name': name.trim(), 'email': email.trim()});
    return '';
  }

  Future<void> loadMeta() async {
    final u = user;
    if (u == null) {
      meta = null;
      notifyListeners();
      return;
    }
    if (_loadingMeta) return; // prevent double-load
    _loadingMeta = true;
    try {
      final snap = await _root.child('userMeta/${u.uid}').get();
      final newMeta = UserMeta.fromSnapshot(u.uid, snap.value);
      if (newMeta != null) {
        meta = newMeta;
        notifyListeners();
      } else {
        // meta not created yet, retry after delay
        await Future.delayed(const Duration(seconds: 2));
        final snap2 = await _root.child('userMeta/${u.uid}').get();
        meta = UserMeta.fromSnapshot(u.uid, snap2.value);
        notifyListeners();
      }
    } finally {
      _loadingMeta = false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
