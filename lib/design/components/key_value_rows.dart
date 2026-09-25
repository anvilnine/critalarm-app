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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.label != null) ...[
            Flexible(
              child: Text(
                widget.label!,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 14,
                  color: colors.ink3,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              widget.value,
              textAlign: widget.label != null
                  ? TextAlign.right
                  : TextAlign.left,
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
      ),
    );
  }
}
