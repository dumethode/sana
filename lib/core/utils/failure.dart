import 'package:firebase_auth/firebase_auth.dart';

/// A user-presentable error. Repositories translate SDK exceptions into this
/// type so that blocs and widgets never deal with Firebase error codes.
class Failure implements Exception {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  /// Maps any thrown object to a [Failure] with a plain-language message.
  factory Failure.from(Object error) {
    if (error is Failure) return error;
    if (error is FirebaseAuthException) return Failure(_authMessage(error.code), code: error.code);
    if (error is FirebaseException) return Failure(_firebaseMessage(error.code), code: error.code);
    return const Failure('Something went wrong. Please try again.');
  }

  static String _authMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact campus IT.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Sign in instead.';
      case 'weak-password':
        return 'Choose a stronger password (8+ characters with a number).';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      default:
        return 'Authentication failed ($code).';
    }
  }

  static String _firebaseMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'You do not have permission to do that.';
      case 'unavailable':
        return 'The service is unreachable. Your change will sync when you are back online.';
      case 'not-found':
      case 'object-not-found':
        return 'This item no longer exists.';
      case 'canceled':
        return 'The upload was cancelled.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Contact campus IT.';
      case 'retry-limit-exceeded':
        return 'The upload kept failing. Check your connection and retry.';
      default:
        return 'Something went wrong ($code). Please try again.';
    }
  }

  @override
  String toString() => 'Failure($code): $message';
}
