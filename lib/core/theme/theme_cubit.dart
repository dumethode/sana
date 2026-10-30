import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

/// Light / dark / system choice, persisted across restarts.
class ThemeCubit extends HydratedCubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  void set(ThemeMode mode) => emit(mode);

  @override
  ThemeMode? fromJson(Map<String, dynamic> json) =>
      ThemeMode.values.firstWhere((m) => m.name == json['mode'], orElse: () => ThemeMode.system);

  @override
  Map<String, dynamic>? toJson(ThemeMode state) => {'mode': state.name};
}
