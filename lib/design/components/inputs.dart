import 'dart:math' as math;

import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The text scale a field that fits its text draws the input at.
///
/// [systemScale] is the scale the phone asks for and [widthAtSystemScale] how
/// wide the text is at it. The answer is the scale at which the text fills
/// [maxWidth], never above [systemScale] and never below [floorScale], so a
/// name that is still too long at the floor scrolls instead of shrinking
/// further. A phone set below [floorScale] keeps its own scale.
double fittedInputTextScale({
  required double systemScale,
  required double widthAtSystemScale,
  required double maxWidth,
  double floorScale = 1,
}) {
  if (widthAtSystemScale <= maxWidth || widthAtSystemScale <= 0) {
    return systemScale;
  }
  final floor = math.min(floorScale, systemScale);
  final fitted = systemScale * maxWidth / widthAtSystemScale;
  return fitted.clamp(floor, systemScale);
}

/// Text field component following the Crit Alarm Design System.
class AppTextField extends StatefulWidget {
  const AppTextField({
    this.label,
    this.initialValue,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.isFocused = false,
    this.isMono = true,
    this.growToFit = false,
    this.fitText = false,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.maxLength,
    this.headerTrailing,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.scrollPadding = const EdgeInsets.all(20),
    super.key,
  });

  final String? label;
  final String? initialValue;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool readOnly;
  final bool isFocused;
  final bool isMono;

  /// Lets the field grow downwards instead of scrolling sideways, so a long
  /// server URL or token can be read in full. Still one logical line: there is
  /// no Enter key behaviour, the text just wraps.
  final bool growToFit;

  /// Steps the typed text down, to no less than the default size, until it
  /// fits the line, so a name stays whole at a large text size. Past that
  /// floor the line scrolls sideways. The box keeps the height it has at the
  /// phone's own text size, so what is under it never moves as the text
  /// changes. For a one line field.
  final bool fitText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? headerTrailing;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;

  /// How much room the field keeps around itself when focus scrolls it into
  /// view. On a screen with a pinned bottom bar, pass the bar's height as the
  /// bottom, or the field comes to rest behind the bar.
  final EdgeInsets scrollPadding;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);
  bool _hasFocus = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null &&
        widget.initialValue != null &&
        widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  /// The box height of a one line field, before any text is fitted.
  static const double _minHeight = 48;

  /// Padding and border around the input, added to the line it holds.
  static const double _chrome = 24 + 3;

  /// How the input of a [AppTextField.fitText] field is drawn: the text scale
  /// and the box height. Text that fits at the phone's own size, or a scale
  /// the phone keeps below the default, is left at it.
  ({double minHeight, TextScaler scaler}) _fitFor(
    BuildContext context, {
    required TextStyle style,
    required double maxWidth,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final fontSize = style.fontSize ?? 15;
    final systemScale = scaler.scale(fontSize) / fontSize;

    TextPainter painter(String text) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();

    final line = painter(' ');
    final lineHeight = line.preferredLineHeight;
    line.dispose();
    final typed = painter(_controller.text);
    final width = typed.width;
    typed.dispose();

    // Room for the caret after the last letter, and a hair of slack so
    // rounding never tips the last letter over the edge.
    const caretRoom = 4.0;
    final fitted = fittedInputTextScale(
      systemScale: systemScale,
      widthAtSystemScale: width,
      // 16 of padding and 1.5 of border on each side.
      maxWidth: maxWidth - 35 - caretRoom,
    );
    return (
      minHeight: math.max(_minHeight, _chrome + lineHeight),
      scaler: fitted == systemScale ? scaler : TextScaler.linear(fitted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final isEffectiveFocus = _hasFocus || widget.isFocused;

    final Color borderColor;
    var shadows = <BoxShadow>[];

    if (!widget.enabled) {
      borderColor = colors.hairline;
    } else if (isError) {
      borderColor = colors.crit;
      shadows = [
        BoxShadow(
          color: colors.critTint,
          spreadRadius: 3,
        ),
      ];
    } else if (isEffectiveFocus) {
      borderColor = colors.cobalt;
      shadows = [
        BoxShadow(
          color: colors.cobaltTint,
          spreadRadius: 3,
        ),
      ];
    } else if (_isHovered) {
      borderColor = colors.ink3;
    } else {
      borderColor = colors.hairline;
    }

    final bg = widget.enabled ? colors.surface : colors.ash;
    final textColor = widget.enabled ? colors.ink : colors.ink3;

    final hintColor = colors.ink3.withValues(alpha: 0.6);
    final inputTextStyle = widget.isMono
        ? AppTypography.mono(textColor, fontSize: 15)
        : AppTypography.body(textColor, fontSize: 15);

    Widget inputScaled(Widget field, TextScaler? scaler) => scaler == null
        ? field
        : MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: field,
          );

    Widget fieldBox(double minHeight, TextScaler? scaler) => MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: context.motion(AppDurations.quick),
        // A minimum, not a fixed height: the box has to grow for wrapped
        // text and for a large Dynamic Type setting.
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.mdAll,
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          boxShadow: shadows,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.center,
        child: inputScaled(
          TextField(
            scrollPadding: widget.scrollPadding,
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            style: inputTextStyle,
            minLines: 1,
            maxLines: widget.growToFit ? null : 1,
            keyboardType: widget.growToFit ? TextInputType.multiline : null,
            textInputAction:
                widget.textInputAction ??
                (widget.growToFit ? TextInputAction.done : null),
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            textCapitalization: widget.textCapitalization,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: widget.placeholder,
              // Lighter than the helper text, so an empty field never reads
              // as one somebody already filled in.
              hintStyle: (widget.isMono
                  ? AppTypography.mono(hintColor, fontSize: 15)
                  : AppTypography.body(hintColor, fontSize: 15)),
            ),
          ),
          scaler,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null || widget.headerTrailing != null) ...[
          Row(
            children: [
              if (widget.label != null)
                Expanded(
                  child: Text(
                    widget.label!,
                    style: AppTypography.small(colors.onCanvas).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (widget.headerTrailing != null) widget.headerTrailing!,
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (widget.fitText && !widget.growToFit)
          LayoutBuilder(
            builder: (context, constraints) => ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final fit = _fitFor(
                  context,
                  style: inputTextStyle,
                  maxWidth: constraints.maxWidth,
                );
                return fieldBox(fit.minHeight, fit.scaler);
              },
            ),
          )
        else
          fieldBox(_minHeight, null),
        if (isError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              // 45 degree rotated red square indicator
              Transform.rotate(
                angle: 45 * 3.14159 / 180,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.crit,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 12,
              color: colors.ink3,
            ),
          ),
        ],
      ],
    );
  }
}
