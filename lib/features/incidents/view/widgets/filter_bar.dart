import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../cubit/incident_filter_cubit.dart';
import '../../models/incident_enums.dart';
import '../../models/incident_filter.dart';

/// Search field, category chips and a filter/sort sheet, all bound to the
/// nearest [IncidentFilterCubit]. Because the cubit lives above the page,
/// this bar rebuilds with the previous choices after navigation.
class FilterBar extends StatefulWidget {
  const FilterBar({super.key, this.hint = 'Search reports, places or SN- codes'});

  final String hint;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late final TextEditingController _search;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<IncidentFilterCubit>().state.query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) context.read<IncidentFilterCubit>().setQuery(value);
    });
    setState(() {}); // toggles the clear button
  }

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<IncidentFilterCubit>().state;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.l),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _onChanged('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: Gap.s),
              Badge(
                isLabelVisible: filter.statuses.isNotEmpty,
                label: Text('${filter.statuses.length}'),
                backgroundColor: p.signal,
                child: IconButton.outlined(
                  tooltip: 'Status and sort',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    side: BorderSide(color: p.line),
                    backgroundColor: p.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
                  ),
                  onPressed: () => _openSheet(context),
                  icon: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.m),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.l),
            children: [
              for (final c in IncidentCategory.values) ...[
                FilterChip(
                  avatar: Icon(c.icon, size: 16, color: c.color),
                  label: Text(c.label),
                  selected: filter.categories.contains(c),
                  onSelected: (_) => context.read<IncidentFilterCubit>().toggleCategory(c),
                ),
                const SizedBox(width: Gap.s),
              ],
            ],
          ),
        ),
        if (filter.isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.s, 0),
            child: Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 16, color: p.inkMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${filter.activeCount} filter${filter.activeCount == 1 ? '' : 's'} on · ${filter.sort.label}',
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _search.clear();
                    context.read<IncidentFilterCubit>().clearFilters();
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _openSheet(BuildContext context) {
    final cubit = context.read<IncidentFilterCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(value: cubit, child: const _FilterSheet()),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<IncidentFilterCubit>().state;
    final cubit = context.read<IncidentFilterCubit>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: context.text.titleMedium),
            const SizedBox(height: Gap.m),
            Wrap(
              spacing: Gap.s,
              runSpacing: Gap.s,
              children: [
                for (final s in IncidentStatus.values)
                  FilterChip(
                    avatar: Icon(s.icon, size: 16, color: s.color),
                    label: Text(s.label),
                    selected: filter.statuses.contains(s),
                    onSelected: (_) => cubit.toggleStatus(s),
                  ),
              ],
            ),
            const SizedBox(height: Gap.xxl),
            Text('Sort by', style: context.text.titleMedium),
            const SizedBox(height: Gap.m),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<IncidentSort>(
                segments: [
                  for (final s in IncidentSort.values) ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {filter.sort},
                onSelectionChanged: (v) => cubit.setSort(v.first),
              ),
            ),
            const SizedBox(height: Gap.xxl),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Show results')),
          ],
        ),
      ),
    );
  }
}
