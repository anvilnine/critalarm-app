import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/design_system/tokens/colors.dart';
import 'package:critalarm/design_system/tokens/durations.dart';
import 'package:critalarm/design_system/tokens/radii.dart';
import 'package:critalarm/design_system/tokens/spacing.dart';
import 'package:flutter/material.dart';

/// The safety-orange action plate: uppercase display type, hard offset
/// shadow (a plate resting on the mat, not a floating pill). Dips a hair on
/// press — a mechanical push, not a bounce.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = widget.onPressed != null && !widget.isLoading;

    void setPressed({required bool value}) {
      if (enabled && _pressed != value) setState(() => _pressed = value);
    }

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: context.motion(AppDurations.tap),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? colors.primary : colors.tile,
          borderRadius: Radii.mdAll,
          border: enabled ? null : Border.all(color: colors.outline),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colors.primaryShadow,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            onTapDown: (_) => setPressed(value: true),
            onTapUp: (_) => setPressed(value: false),
            onTapCancel: () => setPressed(value: false),
            borderRadius: Radii.mdAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md - Spacing.xxs,
              ),
              child: Center(
                widthFactor: 1,
                child: widget.isLoading
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onSurfaceMuted,
                        ),
                      )
                    : Text(
                        widget.label.toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 17,
                              color: enabled
                                  ? colors.onPrimary
                                  : colors.onSurfaceFaint,
                            ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
