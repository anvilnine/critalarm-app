import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A small yellow pill that says the account is on Pro.
class ProBadge extends StatelessWidget {
  const ProBadge({required this.label, super.key});

  /// The word on the pill, already translated.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.yellow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.ink, width: 1.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontFamilyFallback: AppTypography.fontMonoFallbacks,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          height: 1.2,
          color: colors.ink,
        ),
      ),
    );
  }
}
