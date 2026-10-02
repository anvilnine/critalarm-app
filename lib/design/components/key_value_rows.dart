import 'dart:async';

import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Key-Value row container matching index.html .kv.
/// Displays a label or machine value with optional trailing copy button.
class AppKeyValueRow extends StatefulWidget {
  const AppKeyValueRow({
    required this.value,
    this.label,
    this.trailing,
    this.showCopyButton = false,
    this.isMono = true,
    this.onCopy,
    super.key,
  });

  final String value;
  final String? label;
  final Widget? trailing;
  final bool showCopyButton;
  final bool isMono;
  final VoidCallback? onCopy;

  @override
  State<AppKeyValueRow> createState() => _AppKeyValueRowState();
}

class _AppKeyValueRowState extends State<AppKeyValueRow> {
  bool _copied = false;

  void _copyValue() {
    unawaited(Clipboard.setData(ClipboardData(text: widget.value)));
    setState(() => _copied = true);
    widget.onCopy?.call();
    unawaited(
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final valueStyle = widget.isMono
        ? TextStyle(
            fontFamily: AppTypography.fontMono,
            fontFamilyFallback: AppTypography.fontMonoFallbacks,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          )
        : TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.ink,
          );

    final labelStyle = TextStyle(
      fontFamily: AppTypography.fontBody,
      fontFamilyFallback: AppTypography.fontBodyFallbacks,
      fontSize: 14,
      color: colors.ink3,
    );
    final hasLabel = widget.label != null;
    final hasTail = widget.trailing != null || widget.showCopyButton;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A label never shortens. When label and value cannot share the
          // line, the value drops under the label instead.
          if (hasLabel &&
              !hasTail &&
              _needsStack(context, constraints, labelStyle, valueStyle)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label!, style: labelStyle),
                const SizedBox(height: 2),
                Text(
                  widget.value,
                  style: valueStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            );
          }
          return _row(colors, labelStyle, valueStyle);
        },
      ),
    );
  }

  bool _needsStack(
    BuildContext context,
    BoxConstraints constraints,
    TextStyle labelStyle,
    TextStyle valueStyle,
  ) {
    double width(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    return width(widget.label!, labelStyle) +
            8 +
            width(widget.value, valueStyle) >
        constraints.maxWidth;
  }

  Widget _row(AppColors colors, TextStyle labelStyle, TextStyle valueStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: labelStyle),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            widget.value,
            textAlign: widget.label != null ? TextAlign.right : TextAlign.left,
            style: valueStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: widget.trailing!,
          ),
        ] else if (widget.showCopyButton) ...[
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Semantics(
              button: true,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _copyValue,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: Radii.fullAll,
                      border: Border.all(color: colors.hairline, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _copied
                          ? LocaleKeys.common_copied.tr()
                          : LocaleKeys.common_copy.tr(),
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
