import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/failure.dart';
import '../../../core/utils/validators.dart';
import '../models/app_user.dart';
import 'user_repository.dart';

/// The only class that talks to Firebase Authentication.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, required UserRepository users})
      : _auth = auth ?? FirebaseAuth.instance,
        _users = users;

  final FirebaseAuth _auth;
  final UserRepository _users;

  /// Emits on sign-in, sign-out and token refresh. Session persistence across
  /// restarts is handled by the Firebase SDK (it restores the cached user).
  Stream<AuthAccount?> get accountChanges => _auth.userChanges().map(_toAccount);

  AuthAccount? get currentAccount => _toAccount(_auth.currentUser);

  static AuthAccount? _toAccount(User? u) {
    if (u == null) return null;
    return AuthAccount(
      uid: u.uid,
      email: (u.email ?? '').toLowerCase(),
      emailVerified: u.emailVerified,
      displayName: u.displayName,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } catch (e) {
      throw Failure.from(e);
    }
  }

  /// Creates the account, enforces the ALU-email rule and sends the
  /// verification email.
  ///
  /// Non-ALU addresses are only accepted when a campus admin has placed them
  /// on the staff allowlist (for contractors). The allowlist can only be read
  /// by an authenticated user for their own email, so the check has to run
  /// right after account creation; a rejected account is deleted at once.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalised = email.trim().toLowerCase();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: normalised, password: password);
      final user = cred.user!;
      if (!Validators.isAluEmail(normalised)) {
        final allowed = await _users.isAllowlisted(normalised);
        if (!allowed) {
          await user.delete();
          throw const Failure(
            'Use your ALU email (@alustudent.com or @alueducation.com). '
            'Other addresses only work for staff registered by campus administration.',
            code: 'not-alu-email',
          );
        }
      }
      await user.updateDisplayName(name.trim());
      await user.sendEmailVerification();
    } catch (e) {
      throw Failure.from(e);
    }
  }

  Future<void> resendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw Failure.from(e);
    }
  }

  /// Reloads the user from the server. When the email has just been verified
  /// the ID token is force-refreshed so that `email_verified` is true inside
  /// security rules for the very next request.
  Future<bool> refreshVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final fresh = _auth.currentUser;
      if (fresh != null && fresh.emailVerified) {
        await fresh.getIdToken(true);
        return true;
      }
      return false;
    } catch (e) {
      throw Failure.from(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } catch (e) {
      throw Failure.from(e);
    }
  }

  Future<void> signOut() => _auth.signOut();
}
