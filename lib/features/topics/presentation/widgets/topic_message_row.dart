import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
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
    this.bottomPadding = 12,
    super.key,
  });

  final String title;
  final String timestamp;
  final String body;
  final String source;
  final bool isHigh;

  /// The room under the row. 12 unless a control follows that is taller than
  /// it was and takes the rest.
  final double bottomPadding;

  /// What a screen reader says for the share glyph.
  final String shareLabel;

  /// Called with where the glyph sits on screen, for the iPad popover.
  final ValueChanged<Rect> onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final row = Padding(
      padding: EdgeInsets.fromLTRB(14, 12, 14, bottomPadding),
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
                        child: Semantics(
                          // The bar is the only mark of a high message, so a
                          // screen reader hears it in front of the title.
                          label: isHigh
                              ? '${LocaleKeys.common_priority_high.tr()}, '
                                    '$title'
                              : null,
                          excludeSemantics: isHigh,
                          child: Text(
                            title,
                            maxLines: _kTitleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.fontBody,
                              fontFamilyFallback:
                                  AppTypography.fontBodyFallbacks,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
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
            ],
          ),
        ),
      ),
    );
    // The glyph is a 48 box around the same 16 glyph, 24 in from the right
    // edge and 24 down from the top. It is placed on the whole row and not on
    // the text column, because a tap outside the box that holds it is never
    // heard: the column's box stops 14 short of the right edge and 12 below
    // the top, and the glyph's old 44 box heard only the 30 by 34 inside it.
    // The box reaches 2 past the right edge, which stays unheard.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        row,
        Positioned(
          top: 0,
          right: -2,
          child: MessageShareGlyph(label: shareLabel, onShare: onShare),
        ),
      ],
    );
  }
}

/// The share glyph on a message row: small, with a thumb-sized target around
/// it. Called with where it sits on screen, for the iPad popover.
class MessageShareGlyph extends StatelessWidget {
  const MessageShareGlyph({
    required this.label,
    required this.onShare,
    super.key,
  });

  final String label;
  final ValueChanged<Rect> onShare;

  /// The tap box: the glyph is 16 in the middle of it. A row places it so the
  /// glyph stays where it was when the box was 44, which is 2 up and 2 out.
  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        radius: MessageShareGlyph.size / 2,
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          final origin = box == null || !box.hasSize
              ? Rect.zero
              : box.localToGlobal(Offset.zero) & box.size;
          onShare(origin);
        },
        child: SizedBox(
          width: MessageShareGlyph.size,
          height: MessageShareGlyph.size,
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
