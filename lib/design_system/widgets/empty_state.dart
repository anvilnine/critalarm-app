import 'package:critalarm/design_system/tokens/colors.dart';
import 'package:critalarm/design_system/tokens/spacing.dart';
import 'package:flutter/material.dart';

/// Centered empty or zero-data state with an optional call to action.
///
/// The [icon] heads the copy, [title] and [message] sit under it, and [action]
/// renders as a full-width plate. [secondaryAction] is the lighter option
/// beneath it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.secondaryAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// A lighter alternative sitting under [action], for example a text button.
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    // Scrollable so short viewports (landscape phones) never overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        // Cap the content width so a stretched primary plate stays a plate and
        // copy stays a comfortable measure on wide screens.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: colors.onSurfaceMuted),
              const SizedBox(height: Spacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Spacing.lg),
                // Full-width primary plate: the loud, unmissable next step.
                SizedBox(width: double.infinity, child: action),
              ],
              if (secondaryAction != null) ...[
                SizedBox(height: action != null ? Spacing.sm : Spacing.lg),
                secondaryAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
