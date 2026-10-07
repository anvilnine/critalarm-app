import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// The rows of the Reliability screen come in two kinds.
//
// - A plain row sits on the white sheet with no surface of its own, the way
//   the rows of Topics and Settings do: a title, at most a line or two,
//   something at the end, and a rule between it and the next row.
// - A row that needs action keeps a card. All of them share one card
//   (`ReliabilityAttentionCard`) with a rule between them.

/// The rule between two rows of one list.
class ReliabilityRowDivider extends StatelessWidget {
  const ReliabilityRowDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppSectionDivider(padding: EdgeInsets.zero);
}

/// One card for every row that needs action, with a rule between the rows.
class ReliabilityAttentionCard extends StatelessWidget {
  const ReliabilityAttentionCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppHighlightCard(
      // Red is for a ringing critical alarm and nothing else, so a broken
      // check is told apart by its chip, its face and the title of the
      // screen, not by the card's colour.
      tone: AppHighlightTone.choice,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const ReliabilityRowDivider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A row with no surface: [title], an optional [badge] after it, [lines]
/// under it and [trailing] at the end.
///
/// A tap on the row, when [onTap] is given, makes it a button that screen
/// readers announce as one, with [label] when there is one. A row with no
/// [onTap] and no [label] adds no semantics of its own, so a switch in
/// [trailing] keeps its own.
class ReliabilityPlainRow extends StatelessWidget {
  const ReliabilityPlainRow({
    required this.title,
    this.badge,
    this.lines = const [],
    this.trailing,
    this.onTap,
    this.label,
    this.hint,
    this.onCard = false,
    super.key,
  });

  final String title;
  final Widget? badge;

  /// Quiet lines under the title.
  final List<String> lines;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// What a screen reader says for the row, in place of what is drawn.
  final String? label;
  final String? hint;

  /// The row sits on the cream card, so its text takes the card's colours.
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ink = onCard ? colors.onCanvas : colors.ink;
    final muted = onCard ? colors.onCanvasMuted : colors.ink3;
    final trailing = this.trailing;

    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: Spacing.s2,
                    runSpacing: Spacing.s1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body(
                          ink,
                          fontSize: 15,
                        ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                      ),
                      ?badge,
                    ],
                  ),
                  for (final line in lines)
                    Text(line, style: AppTypography.small(muted, fontSize: 13)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Spacing.s2),
              trailing,
            ],
          ],
        ),
      ),
    );

    if (onTap == null && label == null) return row;
    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      hint: hint,
      onTap: onTap,
      excludeSemantics: label != null,
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

/// A fix button that says which check it acts on, "Open settings,
/// Notifications", where the button alone would say only "Open settings".
class ReliabilityFixButton extends StatelessWidget {
  const ReliabilityFixButton({
    required this.label,
    required this.checkTitle,
    required this.variant,
    required this.isBusy,
    required this.onPressed,
    super.key,
  });

  final String label;

  /// The title of the check the button acts on.
  final String checkTitle;
  final AppButtonVariant variant;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isBusy;
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: reliabilityActionAnnouncement(label, checkTitle),
      value: isBusy ? LocaleKeys.common_loading.tr() : null,
      onTap: isEnabled ? onPressed : null,
      excludeSemantics: true,
      child: AppButton(
        label: label,
        size: AppButtonSize.sm,
        variant: variant,
        isLoading: isBusy,
        onPressed: onPressed,
      ),
    );
  }
}

/// One check on the Reliability screen.
///
/// A fine row is a plain row: the title, then a tick (or a value where the
/// tick would be) and an arrow when a tap opens something. It has no face.
///
/// A row that needs action goes inside a [ReliabilityAttentionCard]: the
/// face of its state, the title with a chip, at most one short line and one
/// action when the check has a fix. A check this screen has no words for
/// shows its id as the title.
class ReliabilityRow extends StatelessWidget {
  const ReliabilityRow({
    required this.check,
    required this.face,
    required this.now,
    this.actionLabel,
    this.actionVariant = AppButtonVariant.primary,
    this.isBusy = false,
    this.onAction,
    this.clearLabel,
    this.isClearing = false,
    this.onClear,
    this.onTap,
    super.key,
  });

  final ReliabilityCheck check;

  /// The face of the row's state, or null for none.
  final FaceState? face;

  /// The moment the words are worked out for: "2 h ago", "Tue 13:23".
  final DateTime now;

  /// The action's label, or null when the check has no fix.
  final String? actionLabel;

  /// Primary on the first row with an action, ghost on every later one, so
  /// a screen with three things to fix has one loudest button.
  final AppButtonVariant actionVariant;

  /// The action is running, so its button shows progress and takes no tap.
  final bool isBusy;
  final VoidCallback? onAction;

  /// A second, quieter action beside the first, or null for none. A missed
  /// alarm has one: "Got it", which closes its entry.
  final String? clearLabel;
  final bool isClearing;
  final VoidCallback? onClear;

  /// Taps on the row itself. Null makes the row a plain display.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = check.state;
    final needsAction = reliabilityNeedsAction(state);

    final titleKey = reliabilityRowTitleKey(check);
    final title = titleKey == null ? check.id.value : titleKey.tr();
    final lineWords = reliabilityLine(check, now: now);
    final line = lineWords?.key.tr(namedArgs: lineWords.args);
    final stateWord = reliabilityStateKey(state).tr();
    final valueWords = reliabilityFineValue(check, now: now);
    final value = valueWords?.key.tr(namedArgs: valueWords.args);
    final semanticLabel = [title, stateWord, ?value, ?line].join(', ');

    if (!needsAction) {
      // A fine row says it with a tick, not a word. The word is still in the
      // row's semantics label.
      //
      // "Last push" shows when instead: a tick there would say a push arrived
      // on a phone that has never had one.
      return ReliabilityPlainRow(
        title: title,
        lines: [?line],
        label: semanticLabel,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              Text(value, style: AppTypography.small(colors.ink2, fontSize: 13))
            else
              AppGlyph(
                GlyphType.check,
                size: 18,
                color: colors.ink3,
                strokeWidth: 2.4,
              ),
            // A fine row that opens something says so.
            if (onTap != null) ...[
              const SizedBox(width: Spacing.s2),
              AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
            ],
          ],
        ),
      );
    }

    // At large text the face stands above the words, so the title keeps the
    // whole width of the card and no word has to break.
    final isStacked = MediaQuery.textScalerOf(context).scale(15) >= 15 * 1.8;
    final faceWidget = face == null
        ? null
        : ExcludeSemantics(child: FaceWidget(state: face!, size: 36));

    final action = actionLabel == null
        ? null
        : ReliabilityFixButton(
            label: actionLabel!,
            checkTitle: title,
            variant: actionVariant,
            isBusy: isBusy,
            onPressed: onAction,
          );
    final clear = clearLabel == null
        ? null
        : ReliabilityFixButton(
            label: clearLabel!,
            checkTitle: title,
            variant: AppButtonVariant.tinted,
            isBusy: isClearing,
            onPressed: onClear,
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
                colors.onCanvas,
                fontSize: 15,
              ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
            ),
            ReliabilityStateChip(state: state, label: stateWord),
          ],
        ),
        if (line != null)
          Text(
            line,
            style: AppTypography.small(colors.onCanvasMuted, fontSize: 13),
          ),
        if (action != null) ...[
          const SizedBox(height: Spacing.s2),
          if (clear == null)
            action
          else if (isStacked)
            // At large text each label gets the whole width.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                action,
                const SizedBox(height: Spacing.s2),
                clear,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: action),
                const SizedBox(width: Spacing.s2),
                Expanded(child: clear),
              ],
            ),
        ],
      ],
    );

    final isSingleLine = line == null && action == null;
    final Widget content = faceWidget == null
        ? words
        : isStacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [faceWidget]),
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
            ],
          );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: content,
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      onTap: onTap,
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

/// The free test: opens the test alarm screen. It rings nothing by itself.
/// A plain row that only opens another screen, so it has no face. It sits
/// right under the checks, above any extra group.
class ReliabilityTestRow extends StatelessWidget {
  const ReliabilityTestRow({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = LocaleKeys.reliability_ring_test_title.tr();
    return ReliabilityPlainRow(
      title: title,
      label: title,
      onTap: onTap,
      trailing: AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
    );
  }
}
