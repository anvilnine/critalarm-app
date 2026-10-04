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
///
/// By default a line longer than the block scrolls sideways and the Copy
/// pill sits over the top right corner. With [isWrapped] the text wraps
/// inside the block and the copy action is a full-width button under it:
/// use that for one long command the user has to read and copy whole, where
/// nothing may hide behind a scroll at any text size.
class AppCodeBlock extends StatefulWidget {
  const AppCodeBlock({
    required this.code,
    this.onCopy,
    this.isWrapped = false,
    this.copyLabel,
    super.key,
  });

  final String code;
  final VoidCallback? onCopy;

  /// Wraps the text and puts the copy button under it.
  final bool isWrapped;

  /// The words on the copy button. Null shows the plain "Copy".
  final String? copyLabel;

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
    if (widget.isWrapped) return _wrapped(context, colors);

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
              // RichText ignores the system text size unless told, so the
              // code stayed small under Dynamic Type.
              child: RichText(
                textScaler: MediaQuery.textScalerOf(context),
                text: _buildSyntaxHighlightedSpan(widget.code, colors),
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

  /// The wrapped layout: the whole text, then one wide copy button.
  Widget _wrapped(BuildContext context, AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.lgAll,
      ),
      padding: const EdgeInsets.all(Spacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A screen reader hears the copy button, not a token spelled out.
          ExcludeSemantics(
            child: RichText(
              textScaler: MediaQuery.textScalerOf(context),
              text: _buildSyntaxHighlightedSpan(
                _keepAddressesWhole(widget.code),
                colors,
              ),
            ),
          ),
          const SizedBox(height: Spacing.s3),
          Semantics(
            button: true,
            liveRegion: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _copyHovered = true),
              onExit: (_) => setState(() => _copyHovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleCopy,
                child: AnimatedContainer(
                  duration: context.motion(AppDurations.quick),
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _copied || _copyHovered
                        ? colors.panelHover
                        : Colors.transparent,
                    borderRadius: Radii.fullAll,
                    border: Border.all(color: colors.panelLine, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _copied
                        ? LocaleKeys.common_copied.tr()
                        : widget.copyLabel ?? LocaleKeys.common_copy.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onPanel,
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

  /// A line may break after a slash or a hyphen, which splits an address
  /// at `https://` when it would have fitted on the next line whole. A word
  /// joiner after each takes those break points away. For drawing only:
  /// the copied text is the code as given.
  static String _keepAddressesWhole(String code) => code.replaceAllMapped(
    RegExp(r'https?://\S+'),
    (match) => match[0]!.replaceAllMapped(
      RegExp('[/-]'),
      (mark) => '${mark[0]}\u2060',
    ),
  );

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
          // A flag starts a word. A hyphen inside one, as in a topic
          // called `my-topic`, is not a flag.
          r'("(?:\\.|[^"\\])*")|((?<![\w-])-[a-zA-Z]+|\b(?:curl|POST|GET|Bearer)\b)',
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
