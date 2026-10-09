import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// How many lines a title takes before it ends in an ellipsis. A title wraps
/// so it can be read whole; the cap only guards against a runaway one.
const int _kTitleMaxLines = 4;

/// How many lines the body takes on this screen. The messages screen shows
/// the rest.
const int _kBodyMaxLines = 6;

/// One message on the Topic screen's white sheet: the title and the time on
/// one line, the body under it, and the tags in mono when there are any.
///
/// It sits flat on the sheet, with no card of its own, so a list of them reads
/// as one page of text. A high priority message gets an orange bar down its
/// left edge. The share glyph hangs in the row's right margin, so the row is
/// not taller for it.
class TopicMessageRow extends StatelessWidget {
  const TopicMessageRow({
    required this.title,
    required this.timestamp,
    required this.body,
    required this.source,
    required this.shareLabel,
    required this.onShare,
    this.isHigh = false,
    super.key,
  });

  final String title;
  final String timestamp;
  final String body;
  final String source;
  final bool isHigh;

  /// What a screen reader says for the share glyph.
  final String shareLabel;

  /// Called with where the glyph sits on screen, for the iPad popover.
  final ValueChanged<Rect> onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: isHigh
              ? Border(left: BorderSide(color: colors.high, width: 3))
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.only(left: isHigh ? 10 : 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: _kTitleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.fontBody,
                            fontFamilyFallback: AppTypography.fontBodyFallbacks,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timestamp,
                        style: AppTypography.mono(colors.ink3, fontSize: 12),
                      ),
                      // The share glyph hangs here.
                      const SizedBox(width: 26),
                    ],
                  ),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        body,
                        maxLines: _kBodyMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.small(
                          colors.ink2,
                        ).copyWith(height: 1.35),
                      ),
                    ),
                  if (source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.mono(colors.ink3, fontSize: 11),
                      ),
                    ),
                ],
              ),
              Positioned(
                top: -10,
                right: -14,
                child: _ShareGlyph(label: shareLabel, onShare: onShare),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareGlyph extends StatelessWidget {
  const _ShareGlyph({required this.label, required this.onShare});

  final String label;
  final ValueChanged<Rect> onShare;

  @override
  Widget build(BuildContext context) {
    return Semantics(
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
    );
  }
}
