/// Form validators shared by every form. Each returns `null` when valid or a
/// plain-language message when not, so they plug straight into
/// `TextFormField.validator` and are trivially unit-testable.
abstract final class Validators {
  /// Domains that identify an ALU account. Staff contractors outside these
  /// domains can still join if their email is on the staff allowlist; that
  /// check happens server-side after sign-up (see AuthRepository.signUp).
  static const aluDomains = ['alustudent.com', 'alueducation.com'];

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isAluEmail(String email) {
    final e = email.trim().toLowerCase();
    return aluDomains.any((d) => e.endsWith('@$d'));
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(v)) return 'That does not look like an email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Include at least one number';
    if (!v.contains(RegExp(r'[A-Za-z]'))) return 'Include at least one letter';
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if ((value?.trim() ?? '').isEmpty) return '$field is required';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2) return 'Enter your full name';
    if (v.length > 60) return 'Keep it under 60 characters';
    return null;
  }

  static String? length(String? value, {required int min, required int max, required String field}) {
    final v = value?.trim() ?? '';
    if (v.length < min) return '$field needs at least $min characters (${v.length} so far)';
    if (v.length > max) return '$field must be $max characters or fewer';
    return null;
  }

  // Limits mirrored in firestore.rules (validIncidentContent).
  static const titleMin = 5, titleMax = 80;
  static const descriptionMin = 20, descriptionMax = 1000;
  static const locationMin = 2, locationMax = 120;
  static const noteMin = 5, noteMax = 500;

  static String? title(String? v) => length(v, min: titleMin, max: titleMax, field: 'Title');
  static String? description(String? v) =>
      length(v, min: descriptionMin, max: descriptionMax, field: 'Description');
  static String? location(String? v) =>
      length(v, min: locationMin, max: locationMax, field: 'Location');
  static String? note(String? v) => length(v, min: noteMin, max: noteMax, field: 'Note');
}
