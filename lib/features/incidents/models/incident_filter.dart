import 'package:equatable/equatable.dart';

import 'incident_enums.dart';

enum IncidentSort {
  newest('Newest'),
  mostAffected('Most affected'),
  severity('Most severe');

  const IncidentSort(this.label);
  final String label;
}

/// What the user is looking at in a list: search text, chips and sort.
/// Serialisable so it can be persisted by a HydratedCubit.
class IncidentFilter extends Equatable {
  const IncidentFilter({
    this.query = '',
    this.categories = const {},
    this.statuses = const {},
    this.sort = IncidentSort.newest,
  });

  final String query;
  final Set<IncidentCategory> categories;
  final Set<IncidentStatus> statuses;
  final IncidentSort sort;

  bool get isActive => query.trim().isNotEmpty || categories.isNotEmpty || statuses.isNotEmpty;
  int get activeCount => categories.length + statuses.length + (query.trim().isEmpty ? 0 : 1);

  IncidentFilter copyWith({
    String? query,
    Set<IncidentCategory>? categories,
    Set<IncidentStatus>? statuses,
    IncidentSort? sort,
  }) {
    return IncidentFilter(
      query: query ?? this.query,
      categories: categories ?? this.categories,
      statuses: statuses ?? this.statuses,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toJson() => {
        'query': query,
        'categories': categories.map((c) => c.wire).toList(),
        'statuses': statuses.map((s) => s.wire).toList(),
        'sort': sort.name,
      };

  factory IncidentFilter.fromJson(Map<String, dynamic> json) => IncidentFilter(
        query: json['query'] as String? ?? '',
        categories: {for (final c in (json['categories'] as List? ?? const [])) IncidentCategory.parse(c)},
        statuses: {for (final s in (json['statuses'] as List? ?? const [])) IncidentStatus.parse(s)},
        sort: IncidentSort.values.firstWhere((s) => s.name == json['sort'], orElse: () => IncidentSort.newest),
      );

  @override
  List<Object?> get props => [query, categories, statuses, sort];
}
