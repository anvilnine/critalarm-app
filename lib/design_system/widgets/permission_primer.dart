import 'package:critalarm/design_system/tokens/colors.dart';
import 'package:critalarm/design_system/tokens/radii.dart';
import 'package:critalarm/design_system/tokens/spacing.dart';
import 'package:critalarm/design_system/widgets/primary_button.dart';
import 'package:flutter/material.dart';

/// The system permissions the app explains before the OS dialog fires. Each
/// maps to one explainer sheet.
///
/// Only [notifications] is live. PRD §6.8 screen 1 asks for it, then the iOS
/// Critical Alerts prompt right after, with one line of copy: "So it can ring
/// when your phone is on silent."
enum PermissionKind { notifications }

/// Explainer surface shown just before a system permission dialog: a solid
/// accent icon plate, an uppercase display title, body copy and the allow and
/// not-now actions. Purely presentational: copy and icon come from the caller.
/// No translucency, the sheet body is a solid panel, and only the framework
/// modal barrier dims behind it.
class PermissionPrimer extends StatelessWidget {
  const PermissionPrimer({
    required this.icon,
    required this.title,
    required this.body,
    required this.allowLabel,
    required this.notNowLabel,
    this.onAllow,
    this.onNotNow,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Uppercased inside [PrimaryButton], so pass sentence-case, for example
  /// "Allow notifications".
  final String allowLabel;
  final String notNowLabel;
  final VoidCallback? onAllow;
  final VoidCallback? onNotNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      // Scrolls rather than overflows on short viewports / large text scales.
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.lg,
          Spacing.lg,
          Spacing.lg + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Safety-orange icon plate with the hard offset shadow — the same
            // material as the capture plate, sized down.
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: Radii.smAll,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primaryShadow,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.sm + Spacing.xxs),
                  child: Icon(icon, size: 28, color: colors.onPrimary),
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(title.toUpperCase(), style: text.titleLarge),
            const SizedBox(height: Spacing.sm),
            Text(
              body,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceMuted),
            ),
            const SizedBox(height: Spacing.lg),
            PrimaryButton(label: allowLabel, onPressed: onAllow),
            const SizedBox(height: Spacing.xs),
            TextButton(
              onPressed: onNotNow,
              child: Text(notNowLabel.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
