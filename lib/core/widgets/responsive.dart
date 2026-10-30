import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Breakpoint from docs/DESIGN.md: rail navigation and two columns at 720.
abstract final class Breakpoints {
  static const wide = 720.0;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wide;
}

/// Limits content width on tablets so lines stay readable.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 640});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child),
    );
  }
}

/// A sliver that shows items in one column on phones and two on wide
/// screens. Rows size to their tallest card, so variable-height tickets
/// never overflow (unlike a fixed-ratio grid).
class ResponsiveSliverList<T> extends StatelessWidget {
  const ResponsiveSliverList({super.key, required this.items, required this.itemBuilder});

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(builder: (context, constraints) {
      final columns = constraints.crossAxisExtent >= Breakpoints.wide ? 2 : 1;
      final rows = (items.length / columns).ceil();
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, 96),
        sliver: SliverList.separated(
          itemCount: rows,
          separatorBuilder: (_, _) => const SizedBox(height: Gap.m),
          itemBuilder: (context, row) {
            if (columns == 1) return itemBuilder(context, items[row]);
            final left = row * 2;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: itemBuilder(context, items[left])),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: left + 1 < items.length ? itemBuilder(context, items[left + 1]) : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}
