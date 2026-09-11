import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// A scope widget that retints the canvas and semantic palette
/// for a [SeverityMode].
class SeverityScope extends StatelessWidget {
  const SeverityScope({
    required this.child,
    SeverityMode? severity,
    SeverityMode? mode,
    super.key,
  })  : severity = mode ?? severity ?? SeverityMode.none,
        mode = mode ?? severity ?? SeverityMode.none;

  final SeverityMode severity;
  final SeverityMode mode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (severity == SeverityMode.none) {
      return child;
    }

    final theme = Theme.of(context);
    final colors = context.appColors.withSeverity(severity);

    final retintedTheme = theme.copyWith(
      scaffoldBackgroundColor: colors.canvas,
      colorScheme: theme.colorScheme.copyWith(
        surface: colors.surface,
        onSurface: colors.onCanvas,
        primary: colors.highlight,
      ),
      extensions: [
        ...theme.extensions.values.where((ext) => ext is! AppColors),
        colors,
      ],
    );

    return Theme(
      data: retintedTheme,
      child: child,
    );
  }
}
