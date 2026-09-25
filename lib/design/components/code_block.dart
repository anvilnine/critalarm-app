import 'dart:async';

import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Syntax-highlighted code container with copy action.
class AppCodeBlock extends StatefulWidget {
  const AppCodeBlock({
    required this.code,
    this.onCopy,
    super.key,
  });

  final String code;
  final VoidCallback? onCopy;

  @override
  State<AppCodeBlock> createState() => _AppCodeBlockState();
}

class _AppCodeBlockState extends State<AppCodeBlock> {
  bool _copied = false;
  bool _copyHovered = false;

  void _handleCopy() {
    unawaited(Clipboard.setData(ClipboardData(text: widget.code)));
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

    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.lgAll,
      ),
      padding: const EdgeInsets.all(Spacing.s5),
      child: Stack(
        children: [
          // Code text
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              // Room for the Copy pill, which grows with the text size.
              padding: EdgeInsets.only(
                right: MediaQuery.textScalerOf(context).scale(80),
                top: 4,
              ),
              // Text.rich, not RichText: RichText ignores the system text
              // size, so the code stayed small under Dynamic Type.
              child: Text.rich(
                _buildSyntaxHighlightedSpan(widget.code, colors),
              ),
            ),
          ),
          // Copy button pinned to top right
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              button: true,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _copyHovered = true),
                onExit: (_) => setState(() => _copyHovered = false),
                child: GestureDetector(
                  onTap: _handleCopy,
                  child: AnimatedContainer(
                    duration: context.motion(AppDurations.quick),
                    constraints: const BoxConstraints(minHeight: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _copyHovered
                          ? colors.panelHover
                          : Colors.transparent,
                      borderRadius: Radii.fullAll,
                      border: Border.all(color: colors.panelLine, width: 1.5),
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
                        color: colors.onPanel,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildSyntaxHighlightedSpan(String text, AppColors colors) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('#')) {
        // Comment
        spans.add(
          TextSpan(
            text: line,
            style: TextStyle(color: colors.onPanelMuted),
          ),
        );
      } else {
        // Tokenize line by strings vs code
        final regex = RegExp(
          r'("(?:\\.|[^"\\])*")|(-[a-zA-Z]+|\b(?:curl|POST|GET|Bearer)\b)',
        );
        var lastIndex = 0;
        for (final match in regex.allMatches(line)) {
          if (match.start > lastIndex) {
            spans.add(
              TextSpan(
                text: line.substring(lastIndex, match.start),
                style: TextStyle(color: colors.onPanel),
              ),
            );
          }
          final matchedText = match.group(0)!;
          if (matchedText.startsWith('"')) {
            // String literal
            spans.add(
              TextSpan(
                text: matchedText,
                style: TextStyle(color: colors.codeString),
              ),
            );
          } else {
            // Keyword / flag
            spans.add(
              TextSpan(
                text: matchedText,
                style: TextStyle(
                  color: colors.yellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          lastIndex = match.end;
        }
        if (lastIndex < line.length) {
          spans.add(
            TextSpan(
              text: line.substring(lastIndex),
              style: TextStyle(color: colors.onPanel),
            ),
          );
        }
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(
      style: const TextStyle(
        fontFamily: AppTypography.fontMono,
        fontFamilyFallback: AppTypography.fontMonoFallbacks,
        fontSize: 14,
        height: 1.65,
        fontWeight: FontWeight.w500,
      ),
      children: spans,
    );
  }
}
