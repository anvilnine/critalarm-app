import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_message_row.dart';
import 'package:flutter/material.dart';

/// How many lines a title takes before it ends in an ellipsis. A title wraps
/// so it can be read whole; the cap only guards against a runaway one.
const int _kTitleMaxLines = 4;

/// How many lines a body takes. A long one is cut here, and the share sheet
/// carries the whole message.
const int _kBodyMaxLines = 8;

/// Which mark runs down the left of a row.
enum MessageMark {
  /// A message that came in without ringing.
  quiet,

  /// A message with high priority.
  high,

  /// A message an alarm rang for.
  rang,
}

/// One message on the messages page: a mark down the left edge, the title and
/// the time on one line, the body, then the tags and the line about the ring
/// in mono.
///
/// The row sits flat on the white sheet with no card of its own. [mark] is
/// red for a message that rang, orange for high priority and a quiet grey
/// for the rest. The share glyph hangs in the row's right margin, so the row
/// is not taller for it.
class MessagesPageRow extends StatelessWidget {
  const MessagesPageRow({
    required this.title,
    required this.time,
    required this.body,
    required this.tags,
    required this.mark,
    required this.shareLabel,
    required this.onShare,
    this.rangText,
    super.key,
  });

  final String title;
  final String time;
  final String body;

  /// The tags, as one line. Empty for none.
  final String tags;
  final MessageMark mark;

  /// "rang 12 s · answered" and its kin, or null when the message did not
  /// ring or the incident says nothing about it.
  final String? rangText;

  /// What a screen reader says for the share glyph.
  final String shareLabel;

  /// Called with where the glyph sits on screen, for the iPad popover.
  final ValueChanged<Rect> onShare;

  /// The mark's width.
  static const double markWidth = 8;

  Color _markColor(AppColors colors) => switch (mark) {
    MessageMark.rang => colors.crit,
    MessageMark.high => colors.high,
    MessageMark.quiet => colors.hairline,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rang = rangText;
    // At large text the time drops under the title, so the title keeps the
    // width.
    final isLarge = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final timeText = Text(
      time,
      maxLines: 1,
      style: AppTypography.mono(colors.ink3, fontSize: 12),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _markColor(colors),
                borderRadius: BorderRadius.circular(markWidth / 2),
              ),
              child: const SizedBox(width: markWidth),
            ),
            const SizedBox(width: 10),
            Expanded(
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
                              style:
                                  AppTypography.small(
                                    colors.ink,
                                    fontSize: 15,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                          if (!isLarge) ...[
                            const SizedBox(width: 10),
                            timeText,
                          ],
                          // The share glyph hangs here.
                          const SizedBox(width: 26),
                        ],
                      ),
                      if (isLarge) timeText,
                      if (body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            body,
                            maxLines: _kBodyMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.small(
                              colors.ink2,
                            ).copyWith(fontWeight: FontWeight.w400),
                          ),
                        ),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            tags,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.mono(
                              colors.ink3,
                              fontSize: 11.5,
                            ).copyWith(height: 1.4),
                          ),
                        ),
                      if (rang != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            rang,
                            style: AppTypography.mono(
                              colors.ink3,
                              fontSize: 11.5,
                            ).copyWith(height: 1.4),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    top: -10,
                    right: -14,
                    child: MessageShareGlyph(
                      label: shareLabel,
                      onShare: onShare,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row's shape while the messages are still being read: the mark, a title
/// bone with a time bone, and two lines.
class MessagesPageRowSkeleton extends StatelessWidget {
  const MessagesPageRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 11),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeletonBone(
              width: MessagesPageRow.markWidth,
              borderRadius: BorderRadius.all(
                Radius.circular(MessagesPageRow.markWidth / 2),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppSkeletonBone(width: 130, height: 15),
                      AppSkeletonBone(width: 40, height: 12),
                    ],
                  ),
                  SizedBox(height: 8),
                  AppSkeletonBone(width: double.infinity, height: 13),
                  SizedBox(height: 5),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: AppSkeletonBone(height: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
