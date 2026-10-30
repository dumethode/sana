import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Wire values below are stored in Firestore and checked by firestore.rules.
/// Changing one is a data migration, not a refactor.

enum IncidentCategory {
  water('water', 'Water', 'Shortage, leak, no hot water', Icons.water_drop_outlined, AppColors.water),
  electricity('electricity', 'Electricity', 'Outage, faulty socket, exposed wire', Icons.bolt_outlined, AppColors.electricity),
  facilities('facilities', 'Facilities', 'Furniture, doors, windows, AC', Icons.chair_outlined, AppColors.facilities),
  sanitation('sanitation', 'Sanitation', 'Toilets, drains, waste, pests', Icons.cleaning_services_outlined, AppColors.sanitation),
  safety('safety', 'Safety', 'Lighting, access, hazards, security', Icons.health_and_safety_outlined, AppColors.safety),
  internet('internet', 'Wi-Fi & IT', 'No signal, slow network, devices', Icons.wifi_off_outlined, AppColors.internet),
  other('other', 'Other', 'Anything else on campus', Icons.more_horiz, AppColors.other);

  const IncidentCategory(this.wire, this.label, this.hint, this.icon, this.color);

  final String wire;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;

  /// Safety reports start at High so they surface at the top of the staff
  /// queue even if the reporter leaves severity untouched.
  Severity get defaultSeverity => this == IncidentCategory.safety ? Severity.high : Severity.medium;

  static IncidentCategory parse(Object? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => IncidentCategory.other);
}

enum IncidentStatus {
  submitted('submitted', 'Submitted', AppColors.statusSubmitted),
  acknowledged('acknowledged', 'Acknowledged', AppColors.statusAcknowledged),
  inProgress('in_progress', 'In progress', AppColors.statusInProgress),
  resolved('resolved', 'Resolved', AppColors.statusResolved),
  rejected('rejected', 'Not actioned', AppColors.statusRejected);

  const IncidentStatus(this.wire, this.label, this.color);

  final String wire;
  final String label;
  final Color color;

  bool get isOpen => this == submitted || this == acknowledged || this == inProgress;

  /// Position on the four-stop status rail; rejected is shown separately.
  int get railIndex => switch (this) {
        submitted => 0,
        acknowledged => 1,
        inProgress => 2,
        resolved => 3,
        rejected => -1,
      };

  IconData get icon => switch (this) {
        submitted => Icons.outbox_outlined,
        acknowledged => Icons.visibility_outlined,
        inProgress => Icons.construction_outlined,
        resolved => Icons.check_circle_outline,
        rejected => Icons.block_outlined,
      };

  static IncidentStatus parse(Object? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => IncidentStatus.submitted);
}

enum Severity {
  low('low', 'Low', 1, 'Inconvenient, can wait'),
  medium('medium', 'Medium', 2, 'Affects daily use'),
  high('high', 'High', 3, 'Many people affected or unsafe soon'),
  critical('critical', 'Critical', 4, 'Danger to people right now');

  const Severity(this.wire, this.label, this.weight, this.hint);

  final String wire;
  final String label;
  final int weight;
  final String hint;

  Color get color => switch (this) {
        low => AppColors.statusSubmitted,
        medium => AppColors.statusInProgress,
        high => AppColors.safety,
        critical => AppColors.statusRejected,
      };

  static Severity parse(Object? raw) => values.firstWhere((v) => v.wire == raw, orElse: () => Severity.medium);
}

enum CampusArea {
  residence('residence', 'Residence'),
  classrooms('classrooms', 'Classrooms'),
  library('library', 'Library & study spaces'),
  dining('dining', 'Dining area'),
  sports('sports', 'Sports & fitness'),
  grounds('grounds', 'Grounds & paths'),
  offices('offices', 'Offices'),
  other('other', 'Other');

  const CampusArea(this.wire, this.label);

  final String wire;
  final String label;

  static CampusArea parse(Object? raw) => values.firstWhere((v) => v.wire == raw, orElse: () => CampusArea.other);
}
