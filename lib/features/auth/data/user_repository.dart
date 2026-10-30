import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/failure.dart';
import '../models/app_user.dart';

/// Reads and writes `users/{uid}` and reads `staffAllowlist/{email}`.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Future<bool> isAllowlisted(String email) async {
    final doc = await _db.collection('staffAllowlist').doc(email.toLowerCase()).get();
    return doc.exists;
  }

  /// Returns the profile for a verified account, creating it on first sign-in.
  ///
  /// The role is decided here from the allowlist, but the client is not
  /// trusted with it: firestore.rules only accepts `role: 'staff'` when the
  /// allowlist document exists, and every staff-only write re-checks the
  /// allowlist, so a tampered client gains nothing.
  Future<AppUser> ensureProfile(AuthAccount account) async {
    try {
      final ref = _users.doc(account.uid);
      final snap = await ref.get();
      if (snap.exists) return AppUser.fromMap(account.uid, snap.data()!);

      final allow = await _db.collection('staffAllowlist').doc(account.email).get();
      final isStaff = allow.exists;
      final name = (account.displayName?.trim().isNotEmpty ?? false)
          ? account.displayName!.trim()
          : account.email.split('@').first;

      await ref.set({
        'uid': account.uid,
        'email': account.email,
        'displayName': name,
        'role': isStaff ? 'staff' : 'student',
        if (isStaff) 'department': (allow.data()?['department'] as String?) ?? 'Campus operations',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return AppUser(
        uid: account.uid,
        email: account.email,
        displayName: name,
        role: isStaff ? UserRole.staff : UserRole.student,
        department: isStaff ? (allow.data()?['department'] as String?) ?? 'Campus operations' : null,
      );
    } catch (e) {
      throw Failure.from(e);
    }
  }

  Stream<AppUser?> watch(String uid) {
    return _users.doc(uid).snapshots().map((s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null);
  }

  Future<void> updateDisplayName(String uid, String name) async {
    try {
      await _users.doc(uid).update({'displayName': name.trim()});
    } catch (e) {
      throw Failure.from(e);
    }
  }
}
