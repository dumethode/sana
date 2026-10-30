import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_cubit.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/responsive.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/models/app_user.dart';
import '../incidents/models/incident_enums.dart';
import '../shell/session.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthBloc, AppUser?>((b) => b.state.user);
    if (user == null) return const SizedBox.shrink();
    final p = context.palette;
    final mine = context.watch<MyReportsBloc>().state.items;
    final resolved = mine.where((i) => i.status == IncidentStatus.resolved).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(Gap.l),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Profile', style: context.text.displaySmall),
                const SizedBox(height: Gap.xl),
                _Card(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: SanaPalette.tint(p.signal),
                        child: Text(user.initials,
                            style: context.text.titleLarge?.copyWith(color: p.signal)),
                      ),
                      const SizedBox(width: Gap.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.displayName, style: context.text.titleMedium),
                            Text(user.email, style: context.text.bodySmall),
                            const SizedBox(height: Gap.s),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: SanaPalette.tint(user.isStaff ? AppColors.statusAcknowledged : p.signal),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                user.isStaff ? '${user.role.label} · ${user.department ?? ''}' : user.role.label,
                                style: context.text.labelMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!user.isStaff) ...[
                  const SizedBox(height: Gap.m),
                  _Card(
                    child: Row(
                      children: [
                        Expanded(child: _Figure(label: 'Reports sent', value: '${mine.length}')),
                        Expanded(child: _Figure(label: 'Resolved', value: '$resolved')),
                        Expanded(
                          child: _Figure(
                            label: 'Open',
                            value: '${mine.where((i) => i.status.isOpen).length}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Gap.xl),
                const Overline('Appearance'),
                const SizedBox(height: Gap.s),
                BlocBuilder<ThemeCubit, ThemeMode>(
                  builder: (context, mode) => SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => context.read<ThemeCubit>().set(v.first),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                const Overline('Privacy'),
                const SizedBox(height: Gap.s),
                const _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bullet(text: 'Other students see your reports but never your name or email.'),
                      _Bullet(text: 'Campus staff see who reported, so false reports can be followed up.'),
                      _Bullet(text: 'Staff names appear on the updates they make, so you know who is handling it.'),
                      _Bullet(text: 'Photos are visible to signed-in ALU users only. Avoid capturing faces.'),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.xxl),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusRejected,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: 'Sign out?',
                      message: 'Your saved filters and draft stay on this phone for next time.',
                      confirmLabel: 'Sign out',
                    );
                    if (ok && context.mounted) context.read<AuthBloc>().add(const AuthSignOutRequested());
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
                const SizedBox(height: Gap.xl),
                Center(child: Text('Sana 1.0.0 · African Leadership University', style: context.text.bodySmall)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: context.text.displaySmall),
        const SizedBox(height: 2),
        Overline(label),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 16, color: context.palette.signal),
          const SizedBox(width: Gap.s),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
