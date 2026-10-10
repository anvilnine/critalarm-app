import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// What sits under the path. When every check passes it is one quiet chip.
// Otherwise it is a white sheet with one row for each problem, a button on
// each, and a last row that folds away the checks that pass.

/// The chip under the path when every check passes. It is not a button.
class WakeAllPassChip extends StatelessWidget {
  const WakeAllPassChip({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = LocaleKeys.wake_chip_pass.plural(count);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          container: true,
          label: text,
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.6),
              borderRadius: Radii.fullAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppGlyph(
                  GlyphType.check,
                  size: 16,
                  color: colors.ink,
                  strokeWidth: 3.4,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: AppTypography.small(
                      colors.ink,
                      fontSize: 14.5,
                    ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The white sheet: [problems] first, then, when there are checks that pass,
/// a row that opens [passing].
class WakeProblemList extends StatefulWidget {
  const WakeProblemList({
    required this.problems,
    required this.passing,
    required this.passCount,
    this.tails = const [],
    this.initiallyOpen = false,
    super.key,
  });

  /// One widget for each problem, in attention order.
  final List<Widget> problems;

  /// The rows of the checks that pass.
  final List<Widget> passing;

  /// How many checks pass, for the folded row.
  final int passCount;

  /// Parts of a group that stay plain at the end of the sheet, such as the
  /// way to the weekly check's past rounds. Each draws nothing when it has
  /// nothing to show, so they get no rule of their own.
  final List<Widget> tails;

  /// Whether the folded row starts open.
  final bool initiallyOpen;

  @override
  State<WakeProblemList> createState() => _WakeProblemListState();
}

class _WakeProblemListState extends State<WakeProblemList> {
  late bool _isOpen = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final hasPassing = widget.passCount > 0 && widget.passing.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppSheet(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.problems.length; i++) ...[
              if (i > 0) const _Rule(),
              widget.problems[i],
            ],
            if (hasPassing) ...[
              if (widget.problems.isNotEmpty) const _Rule(),
              _PassingRow(
                count: widget.passCount,
                isOpen: _isOpen,
                onTap: () => setState(() => _isOpen = !_isOpen),
              ),
              // The rows stay built and take no height while folded. They
              // are out of the screen reader's way until opened.
              ExcludeSemantics(
                excluding: !_isOpen,
                child: ClipRect(
                  child: AnimatedAlign(
                    alignment: Alignment.topCenter,
                    heightFactor: _isOpen ? 1 : 0,
                    duration: context.motion(AppDurations.base),
                    curve: AppCurves.easeOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final row in widget.passing) ...[
                          const _Rule(),
                          row,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            ...widget.tails,
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const AppSectionDivider(padding: EdgeInsets.zero);
}

class _PassingRow extends StatelessWidget {
  const _PassingRow({
    required this.count,
    required this.isOpen,
    required this.onTap,
  });

  final int count;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = LocaleKeys.wake_passing_row.plural(count);
    return Semantics(
      button: true,
      expanded: isOpen,
      label: text,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              AppGlyph(
                GlyphType.check,
                size: 18,
                color: colors.ink3,
                strokeWidth: 2.4,
              ),
              const SizedBox(width: Spacing.s3),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.small(
                    colors.ink2,
                    fontSize: 14.5,
                  ).copyWith(fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: context.motion(AppDurations.base),
                curve: AppCurves.easeOut,
                child: AppGlyph(
                  GlyphType.down,
                  size: 16,
                  color: colors.ink3,
                  strokeWidth: 2.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One problem: a red dot, the check's name, what is wrong in a line, and one
/// button for the fix.
class WakeProblemRow extends StatelessWidget {
  const WakeProblemRow({
    required this.check,
    required this.now,
    this.actionLabel,
    this.isBusy = false,
    this.onAction,
    this.clearLabel,
    this.isClearing = false,
    this.onClear,
    this.onTap,
    super.key,
  });

  final ReliabilityCheck check;
  final DateTime now;

  /// The fix's label, or null when the check has no fix.
  final String? actionLabel;
  final bool isBusy;
  final VoidCallback? onAction;

  /// The quieter second action, "Got it" on a missed alarm.
  final String? clearLabel;
  final bool isClearing;
  final VoidCallback? onClear;

  /// What a tap on the row itself opens, or null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final titleKey = reliabilityRowTitleKey(check);
    final title = titleKey == null ? check.id.value : titleKey.tr();
    final words = reliabilityLine(check, now: now);
    final line = words?.key.tr(namedArgs: words.args);
    final isLarge = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.body(
            colors.ink,
          ).copyWith(fontWeight: FontWeight.w700, height: 1.25),
        ),
        if (line != null)
          Text(
            line,
            style: AppTypography.small(
              colors.critText,
              fontSize: 13.5,
            ).copyWith(height: 1.35),
          ),
      ],
    );

    final action = actionLabel == null
        ? null
        : _FixButton(
            label: actionLabel!,
            checkTitle: title,
            isBusy: isBusy,
            onPressed: onAction,
          );
    final clear = clearLabel == null
        ? null
        : _FixButton(
            label: clearLabel!,
            checkTitle: title,
            isBusy: isClearing,
            onPressed: onClear,
            isQuiet: true,
          );

    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: colors.crit, shape: BoxShape.circle),
    );

    final Widget row = isLarge
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 6), child: dot),
                  const SizedBox(width: Spacing.s3),
                  Expanded(child: text),
                ],
              ),
              if (action != null || clear != null) ...[
                const SizedBox(height: Spacing.s2),
                Wrap(
                  spacing: Spacing.s2,
                  runSpacing: Spacing.s2,
                  children: [?action, ?clear],
                ),
              ],
            ],
          )
        : Row(
            children: [
              dot,
              const SizedBox(width: Spacing.s3),
              Expanded(child: text),
              if (action != null || clear != null) ...[
                const SizedBox(width: Spacing.s3),
                ?action,
                if (clear != null && action != null)
                  const SizedBox(width: Spacing.s1),
                ?clear,
              ],
            ],
          );

    final padded = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: row,
      ),
    );
    if (onTap == null) return padded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: padded,
    );
  }
}

/// A 44 point outlined button that says which check it acts on to a screen
/// reader, "Open settings, Notifications".
class _FixButton extends StatelessWidget {
  const _FixButton({
    required this.label,
    required this.checkTitle,
    required this.isBusy,
    required this.onPressed,
    this.isQuiet = false,
  });

  final String label;
  final String checkTitle;
  final bool isBusy;
  final VoidCallback? onPressed;

  /// No outline: the quieter second action.
  final bool isQuiet;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isEnabled = onPressed != null && !isBusy;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body(
        colors.ink,
        fontSize: 14,
      ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
    );
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: reliabilityActionAnnouncement(label, checkTitle),
      value: isBusy ? LocaleKeys.common_loading.tr() : null,
      onTap: isEnabled ? onPressed : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: Radii.fullAll,
              border: isQuiet ? null : Border.all(color: colors.ink, width: 2),
            ),
            child: isBusy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.ink),
                    ),
                  )
                : text,
          ),
        ),
      ),
    );
  }
}
