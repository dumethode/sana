import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UserRole {
  student,
  staff;

  static UserRole parse(Object? raw) => raw == 'staff' ? UserRole.staff : UserRole.student;

  String get label => this == UserRole.staff ? 'Campus staff' : 'Student';
}

/// The signed-in Firebase Auth account, reduced to the fields the app needs.
/// Keeping Firebase's `User` type out of blocs makes them testable with plain
/// values.
class AuthAccount extends Equatable {
  const AuthAccount({
    required this.uid,
    required this.email,
    required this.emailVerified,
    this.displayName,
  });

  final String uid;
  final String email;
  final bool emailVerified;
  final String? displayName;

  @override
  List<Object?> get props => [uid, email, emailVerified, displayName];
}

/// A user profile document: `users/{uid}`.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.department,
    this.lastReportAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  /// Staff only, copied from their allowlist entry (e.g. "Facilities").
  final String? department;

  /// Server time of this user's last report. Used for the 60 second
  /// reporting cooldown that firestore.rules enforces.
  final DateTime? lastReportAt;

  bool get isStaff => role == UserRole.staff;

  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: UserRole.parse(data['role']),
      department: data['department'] as String?,
      lastReportAt: (data['lastReportAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  List<Object?> get props => [uid, email, displayName, role, department, lastReportAt];
}
