import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sana/features/auth/data/auth_repository.dart';
import 'package:sana/features/auth/data/user_repository.dart';
import 'package:sana/features/auth/models/app_user.dart';
import 'package:sana/features/incidents/data/incident_repository.dart';
import 'package:sana/features/incidents/models/incident.dart';
import 'package:sana/features/incidents/models/incident_enums.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockIncidentRepository extends Mock implements IncidentRepository {}

/// In-memory replacement for the on-disk HydratedStorage. Survives across
/// cubit instances, which is how the tests simulate "leave the page and come
/// back" and "restart the app".
class MemoryStorage implements Storage {
  final Map<String, dynamic> data = {};

  @override
  dynamic read(String key) => data[key];

  @override
  Future<void> write(String key, dynamic value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<void> close() async {}
}

const student = AppUser(uid: 'stu1', email: 'amina@alustudent.com', displayName: 'Amina K', role: UserRole.student);
const staff = AppUser(
  uid: 'staff1',
  email: 'facilities@alueducation.com',
  displayName: 'Jean P',
  role: UserRole.staff,
  department: 'Facilities',
);

Incident incident({
  String id = 'abcde12345',
  IncidentCategory category = IncidentCategory.water,
  IncidentStatus status = IncidentStatus.submitted,
  Severity severity = Severity.medium,
  CampusArea area = CampusArea.residence,
  String title = 'No water in Block B',
  String description = 'The third floor showers have had no water since morning.',
  String location = 'Block B, 3rd floor',
  String reporterId = 'stu1',
  List<String> affectedBy = const [],
  DateTime? createdAt,
  DateTime? resolvedAt,
  int reopenCount = 0,
}) {
  final created = createdAt ?? DateTime(2026, 10, 20, 9);
  return Incident(
    id: id,
    title: title,
    description: description,
    category: category,
    severity: severity,
    area: area,
    locationDetail: location,
    status: status,
    reporterId: reporterId,
    createdAt: created,
    updatedAt: created,
    affectedBy: affectedBy,
    resolvedAt: resolvedAt,
    reopenCount: reopenCount,
  );
}
