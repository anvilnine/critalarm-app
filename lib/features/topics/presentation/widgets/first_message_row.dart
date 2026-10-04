import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// One row that waits for the first message from the user's own tool.
///
/// While [isReceived] is false the face watches and the row says it is
/// waiting. When it turns true the row retints to the settled tone and the
/// tick plays, once. Built already received, it shows finished and nothing
/// moves. With animations switched off it goes straight to the end.
///
/// The row draws what it is told. It does not poll and holds no state:
/// `FirstMessageWatcher` says when the message landed.
class FirstMessageRow extends StatelessWidget {
  const FirstMessageRow({required this.isReceived, super.key});

  final bool isReceived;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = isReceived
        ? LocaleKeys.onboarding_hook_up_arrived_title.tr()
        : LocaleKeys.onboarding_hook_up_waiting_title.tr();
    final line = isReceived
        ? LocaleKeys.onboarding_hook_up_arrived_line.tr()
        : LocaleKeys.onboarding_hook_up_waiting_line.tr();

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title $line',
      child: ExcludeSemantics(
        child: AppHighlightCard(
          tone: isReceived ? AppHighlightTone.calm : AppHighlightTone.pending,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              FaceWidget(
                state: isReceived ? FaceState.calm : FaceState.watching,
                size: 36,
                isLive: !isReceived,
              ),
              const SizedBox(width: Spacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.small(
                        colors.onCanvas,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: AppTypography.small(
                        colors.onCanvasMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.s3),
              // The one thing on the screen that moves.
              AppAnimatedTick(done: isReceived, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
