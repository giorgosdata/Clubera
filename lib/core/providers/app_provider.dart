import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../features/auth/data/auth_repo.dart';

class AppProvider extends ChangeNotifier {
  final AuthRepo _authRepo = AuthRepo();

  UserModel? _user;
  bool _initialized = false;
  StreamSubscription<DocumentSnapshot>? _userSub;

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get initialized => _initialized;
  bool get isClub => _user?.role == 'club';
  bool get isAdmin => _user?.role == 'admin';

  Future<void> init() async {
    _user = await _authRepo.getCurrentUser();
    _initialized = true;
    notifyListeners();
    if (_user != null) _startListening(_user!.uid);
  }

  void _startListening(String uid) {
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (_user?.uid != uid) return; // signed out or different user
      if (!snap.exists) return;
      final raw = snap.data();
      if (raw == null) return;
      _user = UserModel.fromMap(raw, uid);
      notifyListeners();
    });
  }

  Future<void> login(String email, String password) async {
    _user = await _authRepo.login(email, password);
    notifyListeners();
    if (_user != null) _startListening(_user!.uid);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    _user = await _authRepo.register(
      email: email,
      password: password,
      name: name,
      role: role,
    );
    notifyListeners();
    if (_user != null) _startListening(_user!.uid);
  }

  Future<void> signOut() async {
    _userSub?.cancel();
    _userSub = null;
    await _authRepo.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> resetPassword(String email) => _authRepo.resetPassword(email);

  void updateUser(UserModel updated) {
    _user = updated;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
