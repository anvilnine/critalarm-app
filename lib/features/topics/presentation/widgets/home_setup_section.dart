import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The setup content at the top of Home's list sheet: the widgets card, or
/// nothing. The checklist and its finished line float above the tab bar
/// instead (`HomeSetupPill`).
///
/// Home content. It draws what [state] says and reports taps. It holds no
/// state of its own and opens nothing by itself.
class HomeSetupSection extends StatelessWidget {
  const HomeSetupSection({
    required this.state,
    required this.hasRowsBelow,
    required this.onShowWidgetsHowTo,
    required this.onSeeHosted,
    required this.onDismissWidgetsCard,
    super.key,
  });

  final HomeSetupState state;

  /// Topic rows follow, so the block ends with the gap that sets it apart
  /// from them.
  final bool hasRowsBelow;

  final VoidCallback onShowWidgetsHowTo;
  final VoidCallback onSeeHosted;
  final VoidCallback onDismissWidgetsCard;

  @override
  Widget build(BuildContext context) {
    final child = switch (state.phase) {
      // The checklist and its finished line are not drawn in the list.
      HomeSetupPhase.none ||
      HomeSetupPhase.checklist ||
      HomeSetupPhase.celebration => const SizedBox(
        key: ValueKey('setup_none'),
        width: double.infinity,
      ),
      HomeSetupPhase.widgetsCard => _WidgetsCard(
        key: const ValueKey('setup_widgets'),
        plan: state.widgetsPlan,
        onShowHowTo: onShowWidgetsHowTo,
        onSeeHosted: onSeeHosted,
        onDismiss: onDismissWidgetsCard,
      ),
    };

    final isShown = state.phase == HomeSetupPhase.widgetsCard;
    return _OnSurface(
      // The block grows and shrinks with the list around it. Under reduce
      // motion it cuts.
      child: AnimatedSize(
        duration: context.motion(AppDurations.base),
        curve: AppCurves.easeOut,
        alignment: Alignment.topCenter,
        // A cross-fade moves nothing, so it also runs under reduce motion:
        // the finished line fades away instead of blinking out.
        child: AnimatedSwitcher(
          duration: AppDurations.base,
          switchInCurve: AppCurves.easeOut,
          switchOutCurve: AppCurves.easeOut,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: Padding(
            key: child.key,
            padding: EdgeInsets.only(
              bottom: isShown && hasRowsBelow ? Spacing.s4 : 0,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The section sits on the white list sheet, never on the canvas, so text
/// that follows the canvas (the first-message row's) takes the sheet's ink
/// instead. Without this an acknowledged Home would draw it in the canvas
/// text colour on white.
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

/// The face the widgets card wears: showing something off. The checklist
/// pill has its own two, so the three never read as the same card.
abstract final class _SetupFaces {
  static const FaceState widgets = FaceState.proud;
}

/// The surface the widgets card sits on: a cream block with no stroke.
/// The topic rows around it have no stroke either, so a tint sets the
/// block apart without making it the heaviest thing in the list. The day-0
/// card sits on it too.
class SetupBlock extends StatelessWidget {
  const SetupBlock({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.cream,
        borderRadius: Radii.lgAll,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: child,
      ),
    );
  }
}

/// The widgets card, shown once after the checklist is finished: a title,
/// at most one short line, and the action.
///
/// The main button is the next thing this user can do. With widgets
/// unlocked that is adding one. Without Hosted the steps lead nowhere yet,
/// so the plans come first and the steps are the quiet button beside them.
class _WidgetsCard extends StatelessWidget {
  const _WidgetsCard({
    required this.plan,
    required this.onShowHowTo,
    required this.onSeeHosted,
    required this.onDismiss,
    super.key,
  });

  final HomeWidgetsPlan plan;
  final VoidCallback onShowHowTo;
  final VoidCallback onSeeHosted;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final needsHosted = plan == HomeWidgetsPlan.needsHosted;

    final plans = AppButton(
      label: LocaleKeys.home_widgets_plans_button.tr(),
      size: AppButtonSize.sm,
      isFullWidth: true,
      onPressed: onSeeHosted,
    );
    final how = AppButton(
      label: LocaleKeys.home_widgets_how_button.tr(),
      variant: needsHosted ? AppButtonVariant.ghost : AppButtonVariant.primary,
      size: AppButtonSize.sm,
      isFullWidth: true,
      onPressed: onShowHowTo,
    );

    return SetupBlock(
      padding: const EdgeInsets.fromLTRB(14, 2, 2, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: FaceWidget(state: _SetupFaces.widgets, size: 32),
              ),
              const SizedBox(width: Spacing.s3),
              // The plan badge, with its lock while widgets are locked. A
              // server of the user's own has no plans, so no badge there.
              const AccessLock.inline(
                feature: AppFeature.widgets,
                source: LockSource.homeWidgets,
                child: FeatureLockBadge(staysWhenOpen: true),
              ),
              const Spacer(),
              // The way out is always there and never the loud thing.
              AppDismissCross(
                onPressed: onDismiss,
                label: LocaleKeys.home_widgets_dismiss_button.tr(),
              ),
            ],
          ),
          const SizedBox(height: Spacing.s1),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    LocaleKeys.onboarding_welcome_widgets_title.tr(),
                    style: AppTypography.body(
                      colors.onCanvas,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (needsHosted) ...[
                  const SizedBox(height: 2),
                  Text(
                    LocaleKeys.home_widgets_needs_hosted.tr(),
                    style: AppTypography.small(colors.onCanvasMuted),
                  ),
                ],
                const SizedBox(height: Spacing.s3),
                if (!needsHosted)
                  how
                // Side by side while the labels fit. At large text they
                // stack, each on its own line.
                else if (MediaQuery.textScalerOf(context).scale(1) > 1.3) ...[
                  plans,
                  const SizedBox(height: Spacing.s2),
                  how,
                ] else
                  Row(
                    children: [
                      Expanded(child: plans),
                      const SizedBox(width: Spacing.s2),
                      Expanded(child: how),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One short throw of confetti over Home when the checklist finishes, the
/// same two side bursts the acknowledged screen uses. Under reduce motion
/// nothing is thrown. Brand colours only, no crit red.
class HomeSetupConfetti extends StatefulWidget {
  const HomeSetupConfetti({super.key});

  @override
  State<HomeSetupConfetti> createState() => _HomeSetupConfettiState();
}

class _HomeSetupConfettiState extends State<HomeSetupConfetti> {
  final _left = ConfettiController(duration: const Duration(seconds: 1));
  final _right = ConfettiController(duration: const Duration(seconds: 1));
  bool _started = false;

  // Started here rather than in initState because it reads MediaQuery.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) return;
    AppHaptics.success();
    _left.play();
    _right.play();
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final palette = [c.yellow, c.cobalt, c.surface, c.highlight];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(-1, 0.35),
              child: ConfettiWidget(
                confettiController: _left,
                blastDirection: -math.pi / 3,
                emissionFrequency: 0.08,
                numberOfParticles: 12,
                maxBlastForce: 45,
                minBlastForce: 20,
                gravity: 0.25,
                colors: palette,
              ),
            ),
            Align(
              alignment: const Alignment(1, 0.35),
              child: ConfettiWidget(
                confettiController: _right,
                blastDirection: -2 * math.pi / 3,
                emissionFrequency: 0.08,
                numberOfParticles: 12,
                maxBlastForce: 45,
                minBlastForce: 20,
                gravity: 0.25,
                colors: palette,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
