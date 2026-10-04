import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// Holds a drawn copy of the prompt a permission step is about to open.
///
/// The picture inside is one platform's own widget, chosen by the step. This
/// frame only makes it one control: tapping anywhere on it opens the real
/// prompt, because people read it as the real thing and tap it.
class PermissionPreviewFrame extends StatelessWidget {
  const PermissionPreviewFrame({
    required this.child,
    required this.semanticLabel,
    super.key,
    this.onTap,
  });

  final Widget child;

  /// What a screen reader announces for the card as a whole.
  final String semanticLabel;

  /// Opens the real system prompt.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        // One control, not three. A screen reader would otherwise read the
        // drawn Allow / Don't Allow rows as if they were buttons, and tapping
        // one of them does nothing: the whole card opens the real prompt.
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: semanticLabel,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The card every drawn prompt sits on. Only [radius] differs by platform.
BoxDecoration permissionPreviewDecoration(AppColors colors, double radius) =>
    BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colors.hairline.withValues(alpha: 0.6),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: colors.ink.withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
