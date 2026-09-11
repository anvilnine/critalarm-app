import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:flutter/material.dart';

/// Floating bottom card/sheet container matching index.html .sheet.
/// Features radius xl (32px) and warm shadow lg.
class AppSheet extends StatelessWidget {
  const AppSheet({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 16),
    this.margin,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: Radii.xlAll,
        boxShadow: AppShadows.lg,
      ),
      child: child,
    );
  }
}
