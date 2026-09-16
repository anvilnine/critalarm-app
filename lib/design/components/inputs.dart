import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

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
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
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
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

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
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
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

    final inputTextStyle = widget.isMono
        ? AppTypography.mono(textColor, fontSize: 15)
        : AppTypography.body(textColor, fontSize: 15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.small(colors.onCanvas).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: AppDurations.quick,
            // A minimum, not a fixed height: the box has to grow for wrapped
            // text and for a large Dynamic Type setting.
            constraints: const BoxConstraints(minHeight: 48),
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
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              style: inputTextStyle,
              minLines: 1,
              maxLines: widget.growToFit ? null : 1,
              keyboardType: widget.growToFit ? TextInputType.multiline : null,
              textInputAction: widget.growToFit
                  ? TextInputAction.done
                  : null,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: widget.placeholder,
                hintStyle: (widget.isMono
                    ? AppTypography.mono(colors.ink3, fontSize: 15)
                    : AppTypography.body(colors.ink3, fontSize: 15)),
              ),
            ),
          ),
        ),
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
