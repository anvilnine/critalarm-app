import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Button variants defined by the Crit Alarm Design System.
enum AppButtonVariant {
  /// Cobalt fill (#2A3BD8), white text. The primary CTA on every screen.
  primary,

  /// Ink background (#1A140F), canvas/yellow text.
  ink,

  /// Transparent background with 2px stroke. Secondary actions.
  ghost,

  /// Paper white/cream surface with ink text and subtle shadow.
  paper,

  /// Dark panel background (#1A140F) with onPanel text (#F7F1EA).
  crit,

  /// Transparent background with critical red text. Destructive text action.
  dangerText,

  /// Critical red fill with white text. Destructive primary action.
  destructive,
}

/// Button sizes defined by the Crit Alarm Design System.
enum AppButtonSize {
  /// Compact 36px height, 14px text.
  sm,

  /// Standard 48px height, 16px text.
  md,

  /// Large hero / alarm action 60px height, 19px text.
  lg,
}

/// Snappy, tactile button adhering to the Crit Alarm design specifications.
class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.trailingIcon,
    this.isFocused = false,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? icon;
  final Widget? trailingIcon;
  final bool isFocused;

  /// Overrides the variant's computed foreground colour, and the ghost
  /// variant's border with it. Lets a ghost button sit on the dark panel.
  final Color? foregroundColor;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;
  bool _isActive = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Dimensions based on size
    final (height, horizontalPadding, fontSize) = switch (widget.size) {
      AppButtonSize.sm => (36.0, 14.0, 14.0),
      AppButtonSize.md => (48.0, 22.0, 16.0),
      AppButtonSize.lg => (60.0, 30.0, 19.0),
    };

    // Colors based on variant and hover state
    Color bg;
    Color fg;
    var border = BorderSide.none;
    var shadows = <BoxShadow>[];

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = _isHovered ? colors.highlightHover : colors.highlight;
        fg = colors.onHighlight;
        shadows = AppShadows.lightSm;
      case AppButtonVariant.ink:
        bg = _isHovered ? colors.inkHover : colors.ink;
        fg = colors.canvas;
      case AppButtonVariant.ghost:
        bg = _isHovered ? colors.canvasGhost : Colors.transparent;
        fg = colors.onCanvas;
        border = BorderSide(color: fg, width: 2);
      case AppButtonVariant.paper:
        bg = _isHovered ? colors.cream : colors.surface;
        fg = colors.ink;
        shadows = AppShadows.lightSm;
      case AppButtonVariant.crit:
        bg = colors.panel;
        fg = colors.onPanel;
        shadows = AppShadows.lightSm;
      case AppButtonVariant.dangerText:
        bg = _isHovered ? colors.canvasGhost : Colors.transparent;
        fg = colors.crit;
      case AppButtonVariant.destructive:
        bg = _isHovered ? colors.critAlt : colors.crit;
        fg = colors.onError;
        shadows = AppShadows.lightSm;
    }

    // An off button keeps flat colours of its own. It used to be wrapped in an
    // Opacity, which made a filled button see-through, so whatever sat behind
    // it showed through the fill.
    if (!_isEnabled) {
      switch (widget.variant) {
        case AppButtonVariant.primary:
        case AppButtonVariant.ink:
        case AppButtonVariant.paper:
        case AppButtonVariant.crit:
          bg = colors.ash;
          fg = colors.ink2;
          shadows = const <BoxShadow>[];
        case AppButtonVariant.ghost:
          // A ghost button has no fill to see through, so it only needs a
          // quieter label and stroke.
          fg = colors.ink3;
          border = BorderSide(color: fg, width: 2);
        case AppButtonVariant.dangerText:
          fg = colors.ink3;
        case AppButtonVariant.destructive:
          bg = colors.ash;
          fg = colors.ink2;
          shadows = const <BoxShadow>[];
      }
    }

    if (widget.foregroundColor != null) {
      fg = widget.foregroundColor!;
      if (widget.variant == AppButtonVariant.ghost) {
        border = BorderSide(color: fg, width: 2);
      }
    }

    // Scale / translation transforms for tactile interaction
    final scale = _isActive ? 0.97 : 1.0;
    final translateY = (_isHovered && !_isActive && _isEnabled) ? -1.0 : 0.0;

    // Focus ring if focused
    final decoration = BoxDecoration(
      color: bg,
      borderRadius: Radii.fullAll,
      border: border == BorderSide.none ? null : Border.fromBorderSide(border),
      boxShadow: widget.isFocused
          ? [
              BoxShadow(
                color: colors.focusGap,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: colors.focus,
                spreadRadius: 6,
              ),
              ...shadows,
            ]
          : shadows,
    );

    final textStyle = TextStyle(
      fontFamily: AppTypography.fontDisplay,
      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      letterSpacing: -0.01 * fontSize,
      color: fg,
      height: 1,
    );

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: 8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.label,
              style: textStyle,
              maxLines: 1,
            ),
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          widget.trailingIcon!,
        ],
      ],
    );

    if (widget.isLoading) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: content),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
        ],
      );
    }

    final buttonCore = AnimatedSlide(
      duration: AppDurations.quick,
      curve: AppCurves.easeSpring,
      offset: Offset(0, translateY / height),
      child: AnimatedScale(
        duration: AppDurations.quick,
        curve: AppCurves.easeSpring,
        scale: scale,
        // easeOut, not easeSpring: the spring overshoots past 1, and a shadow
        // animating to none then gets a negative blur, which Flutter rejects.
        child: AnimatedContainer(
          duration: AppDurations.quick,
          curve: AppCurves.easeOut,
          constraints: BoxConstraints(minHeight: height),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 8,
          ),
          decoration: decoration,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    // Without this a screen reader reads the label as plain text: it never
    // says "button", never says the button is off, and never mentions that
    // the button is busy.
    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: _isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) {
          if (_isEnabled) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (_isEnabled) setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTapDown: (_) {
            if (_isEnabled) setState(() => _isActive = true);
          },
          onTapUp: (_) {
            if (_isEnabled) setState(() => _isActive = false);
          },
          onTapCancel: () {
            if (_isEnabled) setState(() => _isActive = false);
          },
          onTap: _isEnabled ? widget.onPressed : null,
          child: widget.isFullWidth
              ? SizedBox(width: double.infinity, child: buttonCore)
              : buttonCore,
        ),
      ),
    );
  }
}

/// Circular icon button (40x40) matching index.html .phone .bar .ib.
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    required this.glyph,
    this.onPressed,
    this.ariaLabel,
    this.size = 40.0,
    this.glyphSize = 18.0,
    this.color,
    super.key,
  });

  final GlyphType glyph;
  final VoidCallback? onPressed;
  final String? ariaLabel;
  final double size;
  final double glyphSize;
  final Color? color;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isHovered = false;
  bool _isActive = false;

  bool get _isEnabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // An off icon button has no fill to see through, so a quieter glyph and
    // stroke stand in for the Opacity this used to be wrapped in.
    final fg = widget.color ?? (_isEnabled ? colors.onCanvas : colors.ink3);

    final bg = _isActive
        ? colors.canvasGhostStrong
        : (_isHovered ? colors.canvasGhost : Colors.transparent);

    final scale = _isActive ? 0.95 : 1.0;

    Widget button = AnimatedScale(
      duration: AppDurations.quick,
      curve: AppCurves.easeSpring,
      scale: scale,
      child: AnimatedContainer(
        duration: AppDurations.quick,
        curve: AppCurves.easeSpring,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: fg, width: 2),
        ),
        alignment: Alignment.center,
        child: AppGlyph(
          widget.glyph,
          size: widget.glyphSize,
          color: fg,
        ),
      ),
    );

    if (widget.ariaLabel != null) {
      button = Semantics(
        label: widget.ariaLabel,
        button: true,
        child: button,
      );
    }

    return MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (_isEnabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isEnabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (_isEnabled) setState(() => _isActive = true);
        },
        onTapUp: (_) {
          if (_isEnabled) setState(() => _isActive = false);
        },
        onTapCancel: () {
          if (_isEnabled) setState(() => _isActive = false);
        },
        onTap: _isEnabled ? widget.onPressed : null,
        child: button,
      ),
    );
  }
}
