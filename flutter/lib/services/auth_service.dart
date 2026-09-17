import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  User? user;
  UserMeta? meta;

  AuthService() {
    _auth.authStateChanges().listen((u) {
      user = u;
      meta = null;
      loadMeta();
    });
  }

  UserMeta? get currentMeta => meta;

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    await loadMeta();
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
    final snap = await _root.child('userMeta/${u.uid}').get();
    meta = UserMeta.fromSnapshot(u.uid, snap.value);
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}