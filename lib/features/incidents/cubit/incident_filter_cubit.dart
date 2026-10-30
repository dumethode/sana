import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../models/incident_enums.dart';
import '../models/incident_filter.dart';

/// The search text, chips and sort for one list, persisted to disk.
///
/// Because it lives above the tabs, a filter set on the feed is still there
/// after opening a report and coming back, after switching tabs, and after
/// the app is killed and restarted. [storageId] keeps the student feed and
/// the staff queue independent.
class IncidentFilterCubit extends HydratedCubit<IncidentFilter> {
  IncidentFilterCubit({required this.storageId, IncidentFilter initial = const IncidentFilter()})
      : super(initial);

  final String storageId;

  @override
  String get id => storageId;

  void setQuery(String query) => emit(state.copyWith(query: query));

  void toggleCategory(IncidentCategory c) {
    final next = {...state.categories};
    next.contains(c) ? next.remove(c) : next.add(c);
    emit(state.copyWith(categories: next));
  }

  void toggleStatus(IncidentStatus s) {
    final next = {...state.statuses};
    next.contains(s) ? next.remove(s) : next.add(s);
    emit(state.copyWith(statuses: next));
  }

  void setSort(IncidentSort sort) => emit(state.copyWith(sort: sort));

  void clearFilters() => emit(IncidentFilter(sort: state.sort));

  @override
  IncidentFilter? fromJson(Map<String, dynamic> json) => IncidentFilter.fromJson(json);

  @override
  Map<String, dynamic>? toJson(IncidentFilter state) => state.toJson();
}
