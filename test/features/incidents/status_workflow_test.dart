import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sana/features/incidents/logic/status_workflow.dart';
import 'package:sana/features/incidents/models/incident_enums.dart';

void main() {
  test('closing a report requires a note; other moves do not', () {
    expect(StatusWorkflow.requiresNote(IncidentStatus.resolved), isTrue);
    expect(StatusWorkflow.requiresNote(IncidentStatus.rejected), isTrue);
    expect(StatusWorkflow.requiresNote(IncidentStatus.acknowledged), isFalse);
  });

  test('work cannot go backwards to submitted', () {
    for (final s in IncidentStatus.values) {
      expect(StatusWorkflow.canMove(s, IncidentStatus.submitted), isFalse, reason: '$s -> submitted');
    }
  });

  test('a resolved report can only be reopened into in progress', () {
    expect(StatusWorkflow.nextFor(IncidentStatus.resolved), [IncidentStatus.inProgress]);
  });

  // The workflow exists twice: here for the UI and in firestore.rules for the
  // server. This test parses the rules file so the two can never drift.
  test('matches validTransition() in firestore.rules exactly', () {
    final rules = File('firestore.rules').readAsStringSync();
    final block = RegExp(r'function validTransition[\s\S]*?\}\[from\]').firstMatch(rules)!.group(0)!;
    final entries = RegExp(r"'(\w+)':\s*\[([^\]]*)\]").allMatches(block);
    final fromRules = {
      for (final e in entries)
        e.group(1)!: RegExp(r"'(\w+)'").allMatches(e.group(2)!).map((m) => m.group(1)!).toList(),
    };
    final fromDart = {
      for (final s in IncidentStatus.values) s.wire: StatusWorkflow.nextFor(s).map((t) => t.wire).toList(),
    };
    expect(fromRules, fromDart);
  });
}
