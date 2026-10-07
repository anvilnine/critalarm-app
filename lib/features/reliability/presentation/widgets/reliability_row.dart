import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// One check on the Reliability screen: a face, a title, at most one short
/// line, the state, and one action when the check has a fix.
///
/// A fine row is quiet: no fill, no line, no action. A check this screen has
/// no words for shows its id as the title.
class ReliabilityRow extends StatelessWidget {
  const ReliabilityRow({
    required this.check,
    required this.face,
    this.actionLabel,
    this.isBusy = false,
    this.onAction,
    this.onTap,
    super.key,
  });

  final ReliabilityCheck check;
  final FaceState face;

  /// The action's label, or null when the check has no fix.
  final String? actionLabel;

  /// The action is running, so its button shows progress and takes no tap.
  final bool isBusy;
  final VoidCallback? onAction;

  /// Taps on the row itself. Null makes the row a plain display.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = check.state;
    final isFine = state == ReliabilityState.fine;
    final onSurface = isFine ? colors.ink : colors.onCanvas;
    final muted = isFine ? colors.ink3 : colors.onCanvasMuted;

    final titleKey = reliabilityTitleKey(check.id);
    final title = titleKey == null ? check.id.value : titleKey.tr();
    final lineKey = reliabilityLineKey(check);
    final stateWord = reliabilityStateKey(state).tr();

    final isSingleLine = lineKey == null && actionLabel == null;
    // At large text the face stands above the words, so the title keeps the
    // whole width of the card and no word has to break.
    final isStacked = MediaQuery.textScalerOf(context).scale(15) >= 15 * 1.8;

    final faceWidget = ExcludeSemantics(
      child: FaceWidget(
        state: face,
        size: 36,
        overrideFillColor: isFine ? colors.canvas : null,
      ),
    );
    // A fine row says it with a tick, not a word. The word is still in the
    // row's semantics label.
    final tick = AppGlyph(
      GlyphType.check,
      size: 18,
      color: colors.ink3,
      strokeWidth: 2.4,
    );

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The chip drops under the title when the text is large, so a word
        // never breaks to make room for it.
        Wrap(
          spacing: Spacing.s2,
          runSpacing: Spacing.s1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: AppTypography.body(
                onSurface,
                fontSize: 15,
              ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
            ),
            if (!isFine) ReliabilityStateChip(state: state, label: stateWord),
          ],
        ),
        if (lineKey != null)
          Text(
            lineKey.tr(),
            style: AppTypography.small(muted, fontSize: 13),
          ),
        if (actionLabel != null) ...[
          const SizedBox(height: Spacing.s2),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: actionLabel!,
              size: AppButtonSize.sm,
              isLoading: isBusy,
              onPressed: onAction,
            ),
          ),
        ],
      ],
    );

    final Widget content = isStacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  faceWidget,
                  if (isFine) ...[const Spacer(), tick],
                ],
              ),
              const SizedBox(height: Spacing.s2),
              words,
            ],
          )
        : Row(
            crossAxisAlignment: isSingleLine
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              faceWidget,
              const SizedBox(width: Spacing.s3),
              Expanded(child: words),
              if (isFine) ...[const SizedBox(width: Spacing.s2), tick],
            ],
          );

    final Widget row = isFine
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.ash,
              borderRadius: Radii.mdAll,
            ),
            child: content,
          )
        : AppHighlightCard(
            // Red is for a ringing critical alarm and nothing else, so a
            // broken check is told apart by its chip, its face and the
            // title of the screen, not by the card's colour.
            tone: AppHighlightTone.choice,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: content,
          );

    return Semantics(
      container: true,
      label: [
        title,
        stateWord,
        if (lineKey != null) lineKey.tr(),
      ].join(', '),
      // The action keeps its own button semantics.
      explicitChildNodes: true,
      child: onTap == null
          ? row
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: row,
            ),
    );
  }
}

/// The state word with a glyph, so a state never rests on colour alone.
class ReliabilityStateChip extends StatelessWidget {
  const ReliabilityStateChip({
    required this.state,
    required this.label,
    super.key,
  });

  final ReliabilityState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isFine = state == ReliabilityState.fine;
    final isBroken = state == ReliabilityState.broken;
    final fg = isBroken
        ? colors.onPanel
        : isFine
        ? colors.ink2
        : colors.onCanvas;
    final glyph = switch (state) {
      ReliabilityState.fine ||
      ReliabilityState.notOnThisPhone => GlyphType.check,
      ReliabilityState.needsLook => GlyphType.dot,
      ReliabilityState.broken => GlyphType.close,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isBroken ? colors.panel : colors.surface,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(glyph, size: 12, color: fg, strokeWidth: 2.4),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontMono,
              fontFamilyFallback: AppTypography.fontMonoFallbacks,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.2,
              color: fg,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The last row: opens the test alarm screen. It rings nothing by itself.
class ReliabilityTestRow extends StatelessWidget {
  const ReliabilityTestRow({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.mdAll,
            border: Border.all(color: colors.ink3.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const ExcludeSemantics(
                child: FaceWidget(state: FaceState.wakesUp, size: 36),
              ),
              const SizedBox(width: Spacing.s3),
              Expanded(
                child: Text(
                  LocaleKeys.reliability_ring_test_title.tr(),
                  style: AppTypography.body(
                    colors.ink,
                    fontSize: 15,
                  ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                ),
              ),
              AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
