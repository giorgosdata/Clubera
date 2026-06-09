import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user_model.dart';

class AuthRepo {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  static const _cacheKey = 'cached_user';

  Future<UserModel> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = await _fetchUser(cred.user!.uid);
    await _saveCache(user);
    _saveFcmToken(user.uid);
    return user;
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    UserCredential? cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = UserModel(
        uid: cred.user!.uid,
        email: email.trim(),
        name: name.trim(),
        role: role,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(user.uid).set(user.toMap());
      await _saveCache(user);
      _saveFcmToken(user.uid);
      return user;
    } catch (e) {
      // If Firestore write failed after Auth account was created, clean up.
      if (cred != null) await cred.user?.delete().catchError((_) {});
      rethrow;
    }
  }

  void _saveFcmToken(String uid) {
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        _db.collection('users').doc(uid).update({'fcmToken': token});
      }
    }).catchError((_) {});
  }

  Future<UserModel> _fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User not found');
    return UserModel.fromMap(doc.data()!, uid);
  }

  Future<UserModel?> getCurrentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    try {
      final user = await _fetchUser(u.uid);
      await _saveCache(user);
      return user;
    } catch (_) {
      // Firebase Auth session is valid but Firestore unavailable — use cache
      return _loadCache();
    }
  }

  Future<void> signOut() async {
    await _clearCache();
    return _auth.signOut();
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> _saveCache(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode({
      'uid': user.uid,
      'email': user.email,
      'name': user.name,
      'role': user.role,
      'photoUrl': user.photoUrl,
      'clubId': user.clubId,
      'points': user.points,
      'streak': user.streak,
      'followedClubs': user.followedClubs,
      'balance': user.balance,
      'createdAt': user.createdAt?.millisecondsSinceEpoch,
    }));
  }

  Future<UserModel?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final uid = map['uid'] as String;
      final createdAtMs = map['createdAt'] as int?;
      return UserModel(
        uid: uid,
        email: map['email'] ?? '',
        name: map['name'] ?? '',
        role: map['role'] ?? 'fan',
        photoUrl: map['photoUrl'],
        clubId: map['clubId'],
        points: map['points'] ?? 0,
        streak: map['streak'] ?? 0,
        followedClubs: List<String>.from(map['followedClubs'] ?? []),
        balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
        createdAt: createdAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
