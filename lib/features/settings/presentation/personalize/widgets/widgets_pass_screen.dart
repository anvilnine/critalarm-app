import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/widgets_page_rules.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_live.dart';
import 'package:critalarm/features/settings/presentation/personalize/widgets/home_screen_widgets.dart';
import 'package:critalarm/features/settings/presentation/personalize/widgets/widgets_dot_field.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_widgets_sheet.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The room left under the scrolling body by the page's own closing space
/// above the bottom bar (`AppPassPage` adds it after the slivers).
const double _kClosingSpace = 24;

/// The Widgets page: the three home screen widgets drawn as a home screen
/// shows them, one line under them, and the bottom bar.
///
/// Nothing on the way here sells. "How to add one" is open to everyone and
/// opens the steps for this phone. "See Pro" is drawn only while the widgets
/// are locked and the plan is read, and it is the only thing here that opens
/// the paywall. What each tap does comes from `lockTapFor`.
///
/// The router sends a platform with no home screen widgets back to
/// Personalize, so this page only draws where there is something to add.
class WidgetsPassScreen extends StatelessWidget {
  const WidgetsPassScreen({super.key});

  @override
  Widget build(BuildContext context) => PassLiveBuilder(
    builder: (context, live) {
      final access = getIt<FeatureAccess>();
      final decision = access.decide(AppFeature.widgets);
      final tone = live.toneOf(PassId.widgets);
      final buttons = widgetsPageButtonsFor(
        decision: decision,
        isPlanRead: access.isPlanRead,
      );
      return AppPassPage(
        tone: tone,
        label: live.labelOf(PassId.widgets),
        value: live.valueOf(PassId.widgets),
        tag: live.tagOf(PassId.widgets),
        isOn: live.isOn(PassId.widgets),
        foot: decision is FeatureConfirming
            ? LocaleKeys.personalize_try_confirming.tr()
            : null,
        slivers: [_HomeScreenSliver(tone: tone)],
        bottomBar: _Buttons(
          tone: tone,
          buttons: buttons,
          seePlanLabel: decision is FeatureLocked
              ? LocaleKeys.personalize_passes_widgets_see_plan.tr(
                  namedArgs: {'plan': planWordFor(decision.offer)},
                )
              : null,
          onSeePlan: () => unawaited(_seePlan(context)),
          onHowToAdd: () => unawaited(_howToAdd(context)),
        ),
      );
    },
  );
}

/// The steps for this phone. Open to everyone, whatever the plan.
Future<void> _howToAdd(BuildContext context) async {
  final access = getIt<FeatureAccess>();
  final decision = access.decide(AppFeature.widgets);
  final answer = lockTapFor(
    decision: decision,
    isPlanRead: access.isPlanRead,
    hasTry: false,
    tap: LockTapKind.open,
  );
  if (answer is! OpenPage) return;
  await showHomeWidgetsSheet(
    context: context,
    platform: getIt<PlatformCapabilities>().platform,
    plan: widgetsSheetPlanFor(
      decision: decision,
      isPlanRead: access.isPlanRead,
      isOwnServer: access.isOwnServer,
    ),
    // The sheet's own See Pro is a button that says so, like this page's.
    onSeePro: () {
      if (context.mounted) unawaited(_seePlan(context));
    },
  );
}

/// The paywall, from a button that says See Pro. It waits for the plan to be
/// read, so a tap right after a cold start never sells to someone who
/// already holds it.
Future<void> _seePlan(BuildContext context) async {
  final access = getIt<FeatureAccess>();
  await access.ready;
  if (!context.mounted) return;
  final answer = lockTapFor(
    decision: access.decide(AppFeature.widgets),
    isPlanRead: access.isPlanRead,
    hasTry: false,
    tap: LockTapKind.seePlan,
  );
  if (answer case OpenPaywall(:final offer)) {
    await openPaywallFor(
      context,
      FeatureDecision.locked(offer),
      LockSource.personalizeWidgets,
    );
  }
}

/// The body: a home screen of faint dots that fills the page down to the
/// bottom bar, with the widgets near the top and one line under them.
class _HomeScreenSliver extends StatelessWidget {
  const _HomeScreenSliver({required this.tone});

  final PassTone tone;

  @override
  Widget build(BuildContext context) {
    final isNarrowerThanDisplay =
        MediaQuery.sizeOf(context).width > AppSize.contentMaxWidth;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // The page adds a closing space after this sliver. Taking it off
        // here lets the dots reach the bar without making the page scroll.
        final minHeight = math.max<double>(
          0,
          constraints.remainingPaintExtent - _kClosingSpace,
        );
        return SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Stack(
              children: [
                Positioned.fill(
                  child: WidgetsDotField(
                    color: tone.onGround,
                    fadesSides: isNarrowerThanDisplay,
                  ),
                ),
                _HomeScreenContent(tone: tone),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeScreenContent extends StatelessWidget {
  const _HomeScreenContent({required this.tone});

  final PassTone tone;

  /// The room kept either side of the widgets on a narrow phone.
  static const double _side = 16;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final room = constraints.maxWidth - 2 * _side;
      // A narrow phone draws the whole block smaller, as one picture. It
      // never reflows, so the three keep their places.
      final scale = math.min(1, room / kWidgetsBlockWidth);
      final blockWidth = kWidgetsBlockWidth * scale;
      final left = (constraints.maxWidth - blockWidth) / 2;
      return Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: blockWidth,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: HomeScreenWidgets(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.only(left: left, right: left),
              child: Text(
                LocaleKeys.personalize_passes_widgets_line.tr(),
                style: AppTypography.body(
                  tone.onGround,
                ).copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The bottom bar: "See Pro" and "How to add one" side by side on a phone at
/// the normal text size, stacked at a larger size or a narrow width. Alone,
/// "How to add one" is the primary.
class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.tone,
    required this.buttons,
    required this.seePlanLabel,
    required this.onSeePlan,
    required this.onHowToAdd,
  });

  final PassTone tone;
  final WidgetsPageButtons buttons;

  /// "See Pro", worded for the plan the decision offers. Null when the
  /// decision offers nothing.
  final String? seePlanLabel;
  final VoidCallback onSeePlan;
  final VoidCallback onHowToAdd;

  /// The least width at which two buttons share a row.
  static const double _rowMinWidth = 340;

  @override
  Widget build(BuildContext context) {
    final howTo = LocaleKeys.personalize_passes_widgets_how_to.tr();
    final seePlan = buttons.showsSeePlan ? seePlanLabel : null;
    const bar = EdgeInsets.fromLTRB(
      kPassSidePadding - 4,
      12,
      kPassSidePadding - 4,
      12,
    );

    if (seePlan == null) {
      return Padding(
        padding: bar,
        child: AppButton(
          key: const ValueKey('widgets-how-to'),
          label: howTo,
          isFullWidth: true,
          onPressed: onHowToAdd,
        ),
      );
    }

    final primary = AppButton(
      key: const ValueKey('widgets-see-plan'),
      label: seePlan,
      isFullWidth: true,
      onPressed: onSeePlan,
    );
    final secondary = AppButton(
      key: const ValueKey('widgets-how-to'),
      label: howTo,
      variant: AppButtonVariant.ghost,
      foregroundColor: tone.onGround,
      isFullWidth: true,
      onPressed: onHowToAdd,
    );

    return Padding(
      padding: bar,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
          final sideBySide =
              constraints.maxWidth >= _rowMinWidth &&
              scale < kChromeMaxTextScale;
          if (sideBySide) {
            return Row(
              children: [
                Expanded(child: primary),
                const SizedBox(width: 8),
                Expanded(child: secondary),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 8), secondary],
          );
        },
      ),
    );
  }
}
