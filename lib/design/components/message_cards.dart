import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Message card for topic detail views matching index.html .msg.
class AppMessageCard extends StatelessWidget {
  const AppMessageCard({
    required this.title,
    required this.timestamp,
    required this.body,
    required this.source,
    this.isHigh = false,
    this.onShare,
    this.shareLabel,
    super.key,
  });

  final String title;
  final String timestamp;
  final String body;
  final String source;
  final bool isHigh;

  /// Puts a share button at the bottom right. Called with where the button
  /// sits on screen, for the iPad share popover to point at.
  final ValueChanged<Rect>? onShare;

  /// What VoiceOver says for the share button.
  final String? shareLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final bg = isHigh ? colors.surface : colors.cream;
    final border = isHigh ? Border.all(color: colors.high, width: 2) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.mdAll,
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.01 * 15,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                timestamp,
                style: TextStyle(
                  fontFamily: AppTypography.fontMono,
                  fontFamilyFallback: AppTypography.fontMonoFallbacks,
                  fontSize: 12,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  source,
                  style: TextStyle(
                    fontFamily: AppTypography.fontMono,
                    fontFamilyFallback: AppTypography.fontMonoFallbacks,
                    fontSize: 11,
                    color: colors.ink3,
                  ),
                ),
              ),
              if (onShare != null)
                _ShareButton(label: shareLabel, onShare: onShare!),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small share glyph with a thumb-sized target around it. It hangs into the
/// card's padding so the card does not grow to fit it.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.label, required this.onShare});

  final String? label;
  final ValueChanged<Rect> onShare;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(12, 12),
      child: Semantics(
        button: true,
        label: label,
        child: InkResponse(
          radius: 22,
          onTap: () {
            final box = context.findRenderObject() as RenderBox?;
            final origin = box == null || !box.hasSize
                ? Rect.zero
                : box.localToGlobal(Offset.zero) & box.size;
            onShare(origin);
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AppGlyph(
                GlyphType.share,
                size: 16,
                strokeWidth: 2.2,
                color: context.appColors.ink3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
