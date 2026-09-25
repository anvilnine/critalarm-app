import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Floating bottom card/sheet container matching index.html .sheet.
/// Features radius xl (32px) and warm shadow lg.
class AppSheet extends StatelessWidget {
  const AppSheet({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 16),
    this.margin,
    this.color,
    this.border,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BoxBorder? border;

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
        border: border,
      ),
      child: child,
    );
  }
}

/// Section header used inside sheets matching index.html .sheet h4.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(
    this.title, {
    this.padding = const EdgeInsets.fromLTRB(4, 10, 4, 6),
    super.key,
  });

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.ink3,
          ),
        ),
      ),
    );
  }
}

/// Thin rule between sections inside a sheet, so the card reads as one list.
class AppSectionDivider extends StatelessWidget {
  const AppSectionDivider({
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    super.key,
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: padding,
      child: Container(
        height: 1,
        width: double.infinity,
        color: colors.hairline,
      ),
    );
  }
}

/// Feature bullet row used on paywall/feature lists matching index.html .price li / .critband li.
class AppFeatureBullet extends StatelessWidget {
  const AppFeatureBullet({
    required this.text,
    this.glyph = GlyphType.check,
    this.glyphColor,
    super.key,
  });

  final String text;
  final GlyphType glyph;
  final Color? glyphColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveColor = glyphColor ?? colors.highlight;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.cobaltTint,
          ),
          alignment: Alignment.center,
          child: AppGlyph(
            glyph,
            size: 13,
            color: effectiveColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.ink,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Note / callout container matching index.html .note and self-host mention.
class AppNote extends StatelessWidget {
  const AppNote({
    required this.text,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    super.key,
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontFamilyFallback: AppTypography.fontBodyFallbacks,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: colors.ink2,
          height: 1.4,
        ),
      ),
    );
  }
}
