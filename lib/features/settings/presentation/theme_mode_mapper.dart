import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:flutter/material.dart';

/// Presentation-only bridge from the domain [AppThemeMode] to Flutter's
/// [ThemeMode]. Keeps `ThemeMode` out of the domain layer.
extension AppThemeModeX on AppThemeMode {
  ThemeMode toThemeMode() => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}
