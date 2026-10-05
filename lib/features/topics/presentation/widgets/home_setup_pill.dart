import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/widgets/first_message_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The setup checklist as a floating card above the tab bar, where the
/// pinned notices sit, and drawn like one.
///
/// Closed, it is one line: a small face, "Finish setting up", the count and
/// an arrow. A tap opens it in place to the three rows, and a tap on the
/// header closes it again. The quiet way out for good is the last line of
/// the open card. When the last row lands it becomes one finished line.
///
/// Home content. It draws what [state] says and reports taps. Open or
/// closed is the only thing it holds, and it opens no screen by itself.
class HomeSetupPill extends StatefulWidget {
  const HomeSetupPill({
    required this.state,
    required this.onRowTap,
    required this.onDismiss,
    this.startsOpen = false,
    super.key,
  });

  /// On [HomeSetupPhase.checklist] or [HomeSetupPhase.celebration].
  final HomeSetupState state;

  /// A tap on an open row, with the screen it opens.
  final void Function(String route) onRowTap;

  /// The user closed the checklist for good.
  final VoidCallback onDismiss;

  /// Draws it open from the first frame, for a developer's look at it.
  final bool startsOpen;

  @override
  State<HomeSetupPill> createState() => _HomeSetupPillState();
}

class _HomeSetupPillState extends State<HomeSetupPill> {
  late bool _isOpen = widget.startsOpen;

  void _toggle() {
    AppHaptics.selection();
    setState(() => _isOpen = !_isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFinished = widget.state.phase == HomeSetupPhase.celebration;
    final isOpen = _isOpen && !isFinished;
    final duration = context.motion(AppDurations.base);

    // A floating card must never grow into the whole screen. Its words
    // follow the text size up to a point, the way the tab bar under it
    // does, and the open rows scroll inside what is left.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: _card(context, colors, isDark, isFinished, isOpen, duration),
    );
  }

  static const double _maxTextScale = 1.6;

  Widget _card(
    BuildContext context,
    AppColors colors,
    bool isDark,
    bool isFinished,
    bool isOpen,
    Duration duration,
  ) {
    final maxRowsHeight = MediaQuery.sizeOf(context).height * 0.5;
    return _OnSurface(
      // The same surface, stroke and shadow as the pinned notice bar. Only
      // the corners change: a pill closed, a card open.
      child: AnimatedContainer(
        duration: duration,
        curve: AppCurves.easeOut,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: isOpen ? Radii.lgAll : Radii.fullAll,
          border: Border.all(
            color: isFinished ? colors.cobalt : colors.hairline,
          ),
          boxShadow: AppShadows.shadowLg(isDark: isDark),
        ),
        // The one motion job: the card grows and shrinks. It cuts with
        // animations switched off.
        child: AnimatedSize(
          duration: duration,
          curve: AppCurves.easeOut,
          alignment: Alignment.bottomCenter,
          child: Material(
            type: MaterialType.transparency,
            child: isFinished
                ? const _FinishedLine()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        checklist: widget.state.checklist,
                        isOpen: isOpen,
                        onTap: _toggle,
                      ),
                      if (isOpen)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxRowsHeight,
                          ),
                          child: SingleChildScrollView(
                            child: _Rows(
                              state: widget.state,
                              onRowTap: widget.onRowTap,
                              onDismiss: widget.onDismiss,
                            ),
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

/// The faces the pill wears: one while something is still to come, one for
/// the moment it is all done.
abstract final class _PillFaces {
  /// Eyes up, one brow lifted, a soft smile.
  static const FaceState open = FaceState.curious;

  /// The last row landed.
  static const FaceState finished = FaceState.happy;
}

TextStyle _titleStyle(AppColors colors) => TextStyle(
  fontFamily: AppTypography.fontBody,
  fontFamilyFallback: AppTypography.fontBodyFallbacks,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  height: 1.2,
  color: colors.ink,
);

/// The one line that is always there: face, title, count, and the arrow
/// that says which way a tap moves the card.
class _Header extends StatelessWidget {
  const _Header({
    required this.checklist,
    required this.isOpen,
    required this.onTap,
  });

  final SetupChecklist checklist;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final progress = {
      'done': '${checklist.tickedCount}',
      'count': '${SetupChecklistRow.values.length}',
    };
    final title = LocaleKeys.home_setup_title.tr();
    final progressLabel = LocaleKeys.home_setup_progress_aria_label.tr(
      namedArgs: progress,
    );

    return Semantics(
      button: true,
      expanded: isOpen,
      label: '$title. $progressLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.s3,
            Spacing.s2,
            Spacing.s1,
            Spacing.s2,
          ),
          child: Row(
            children: [
              const FaceWidget(state: _PillFaces.open, size: 20),
              const SizedBox(width: Spacing.s2),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _titleStyle(colors),
                ),
              ),
              const SizedBox(width: Spacing.s2),
              Text(
                LocaleKeys.home_setup_progress.tr(namedArgs: progress),
                style: AppTypography.mono(colors.ink3, fontSize: 12),
              ),
              // As big as the notice bar's cross, so the two bars are the
              // same height.
              SizedBox.square(
                dimension: 36,
                child: Center(
                  child: AppGlyph(
                    isOpen ? GlyphType.down : GlyphType.up,
                    size: 12,
                    color: colors.ink3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three rows and, under them, the quiet way out.
class _Rows extends StatelessWidget {
  const _Rows({
    required this.state,
    required this.onRowTap,
    required this.onDismiss,
  });

  final HomeSetupState state;
  final void Function(String route) onRowTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final checklist = state.checklist;
    final criticalRoute = state.routeFor(SetupChecklistRow.criticalTopic);
    final messageRoute = state.routeFor(SetupChecklistRow.firstMessage);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.s4, 0, Spacing.s3, Spacing.s1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: colors.hairline),
          const SizedBox(height: Spacing.s1),
          _ChecklistRow(
            title: LocaleKeys.home_setup_server_title.tr(),
            isDone: checklist.hasServer,
          ),
          _ChecklistRow(
            title: LocaleKeys.home_setup_critical_title.tr(),
            // The label alone is wrong once a topic exists: nothing is
            // left to create, only a switch to turn on.
            line: checklist.hasTopics
                ? LocaleKeys.home_setup_critical_line_off.tr()
                : null,
            isDone: checklist.hasCriticalTopic,
            onTap: criticalRoute == null ? null : () => onRowTap(criticalRoute),
          ),
          _Tappable(
            onTap: messageRoute == null ? null : () => onRowTap(messageRoute),
            // The waiting row from the last setup step: a label and its
            // tick. The pill has its one face in the header.
            child: FirstMessageRow(
              isReceived: checklist.hasFirstMessage,
              isCompact: true,
              showsFace: false,
              isBare: true,
            ),
          ),
          // The quiet way out, for a list that will never finish on this
          // phone. Never the loud thing.
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.selection();
                  onDismiss();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(
                      LocaleKeys.home_setup_dismiss_button.tr(),
                      style: AppTypography.small(colors.ink3, fontSize: 13),
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
}

/// One row of the checklist, laid out like the first-message row so the
/// three read as one list: a label, then the ring that fills when the row
/// is true. A finished row goes quiet, so the eye lands on what is left.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.title,
    required this.isDone,
    this.line,
    this.onTap,
  });

  final String title;

  /// What is left to do, for the one case the label does not say it. Drawn
  /// only while the row is open.
  final String? line;
  final bool isDone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final line = isDone ? null : this.line;
    final status = isDone
        ? LocaleKeys.home_setup_row_done.tr()
        : LocaleKeys.home_setup_row_open.tr();

    return _Tappable(
      onTap: onTap,
      child: Semantics(
        container: true,
        label: [title, status, ?line].join('. '),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.s2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.small(
                          isDone ? colors.onCanvasMuted : colors.onCanvas,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (line != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: AppTypography.small(
                            colors.onCanvasMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.s3),
                AppAnimatedTick(done: isDone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Makes a row a button when it has somewhere to go.
///
/// The same widgets are built either way. A row loses its tap the moment
/// it is ticked, and a wrapper that came and went would rebuild the tick
/// under it already finished, with nothing played.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                AppHaptics.selection();
                onTap();
              },
        child: child,
      ),
    );
  }
}

/// What the pill turns into when the last row lands: one line, which then
/// goes for good.
class _FinishedLine extends StatelessWidget {
  const _FinishedLine();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.s3,
          Spacing.s2,
          Spacing.s3,
          Spacing.s2,
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: FaceWidget(state: _PillFaces.finished, size: 20),
            ),
            const SizedBox(width: Spacing.s2),
            Expanded(
              child: Text(
                LocaleKeys.home_setup_done_title.tr(),
                style: _titleStyle(colors),
              ),
            ),
            // As tall as the open header, so nothing jumps when it turns.
            const SizedBox(
              height: 36,
              child: Center(child: AppAnimatedTick(done: true, size: 20)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pill is a white surface, never the canvas, so text that follows the
/// canvas (the first-message row's) takes the surface's ink instead.
/// Without this an acknowledged Home would draw it in the canvas text
/// colour on white.
class _OnSurface extends StatelessWidget {
  const _OnSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where((ext) => ext is! AppColors),
          colors.copyWith(onCanvas: colors.ink, onCanvasMuted: colors.ink2),
        ],
      ),
      child: child,
    );
  }
}
