import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Where the user is in the permission steps: one dot per step, the current
/// one drawn as a longer bar.
///
/// [count] is the number of steps this phone will draw, so two phones can
/// show a different number of dots. With one step there is nothing to count
/// and it draws nothing.
class PermissionStepDots extends StatelessWidget {
  const PermissionStepDots({
    required this.count,
    required this.index,
    super.key,
  });

  final int count;

  /// The current step, from zero.
  final int index;

  static const double _dot = 6;
  static const double _bar = 20;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final colors = context.appColors;
    final duration = context.motion(AppDurations.base);

    return Semantics(
      label: LocaleKeys.onboarding_permissions_step_progress.tr(
        namedArgs: {'step': '${index + 1}', 'count': '$count'},
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: _dot),
            AnimatedContainer(
              duration: duration,
              curve: AppCurves.easeOut,
              width: i == index ? _bar : _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: i == index
                    ? colors.onCanvas
                    : colors.onCanvas.withValues(alpha: 0.3),
                borderRadius: Radii.fullAll,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
