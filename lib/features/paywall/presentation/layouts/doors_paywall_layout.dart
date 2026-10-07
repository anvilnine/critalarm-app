import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_scene.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Two doors on a dark wall. The narrow one at the left edge says Free and
/// stays shut. The mascot opens the other, and the product is behind it:
/// the app's own yellow, with one benefit playing in the doorway.
///
/// Both doors stand shut on the first frame. The right one gives a little,
/// then swings open on its hinge and ends square against the wall, while
/// the mascot pops up in the doorway. From there it is the Hero
/// composition in a doorway: the previews take turns inside it, and the
/// stage, the lines and the pips answer the hand as they do there.
///
/// Every part but the doors is the kit's (`kit/paywall_hero.dart`). On a
/// stage too small for a doorway the doors are left out and the approved
/// stage is drawn on the same wall.
class DoorsPaywallLayout extends StatefulWidget {
  const DoorsPaywallLayout({super.key});

  @override
  State<DoorsPaywallLayout> createState() => _DoorsPaywallLayoutState();
}

class _DoorsPaywallLayoutState extends State<DoorsPaywallLayout> {
  /// The stage's box, as the stage last arranged itself. The doors are
  /// drawn under and over the stage in the same box.
  final ValueNotifier<Size?> _stage = ValueNotifier<Size?>(null);
  Size? _asked;

  @override
  void dispose() {
    _stage.dispose();
    super.dispose();
  }

  /// The mascot on the doorway's edge and the preview inside it. It also
  /// notes the stage's size for the doors.
  HeroArrangement _arrange(Size stage) {
    if (stage != _asked) {
      _asked = stage;
      // The stage is being built: the doors are told after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stage.value = stage;
      });
    }
    return doorsGeometryFor(stage)?.arrangement ?? heroArrangementFor(stage);
  }

  /// Draws [build] in the stage's box, when the stage has room for doors.
  Widget _onStage(Widget Function(Size stage, DoorsGeometry doors) build) {
    return ValueListenableBuilder<Size?>(
      valueListenable: _stage,
      builder: (context, stage, _) {
        final doors = stage == null ? null : doorsGeometryFor(stage);
        if (stage == null || doors == null) return const SizedBox.shrink();
        return Positioned(left: 0, top: 0, child: build(stage, doors));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      tone: PaywallTone.panel,
      // The shut door stands at the left edge, so the cross takes the right.
      closeOnLeft: false,
      restAt: DoorsTimeline.restAt,
      builder: (context, scope) {
        final headline = switch (doorsHeadlineFor(
          isHosted: scope.isHosted,
          source: scope.source,
        )) {
          DoorsHeadline.hosted => LocaleKeys.paywall_doors_headline_hosted,
          DoorsHeadline.pro => LocaleKeys.paywall_doors_headline_pro,
          DoorsHeadline.keepOpen => LocaleKeys.paywall_doors_headline_ending,
          DoorsHeadline.openAgain => LocaleKeys.paywall_doors_headline_ended,
        };

        return Stack(
          children: [
            _onStage(
              (stage, doors) => PaywallClockBuilder(
                clock: scope.clock,
                builder: (context, t, _) => DoorsWall(
                  size: stage,
                  geometry: doors,
                  label: LocaleKeys.paywall_doors_free.tr(),
                  seconds: scope.clock.isStill ? 0 : t,
                  entrance: heroEntranceAt(t, after: DoorsTimeline.prelude),
                ),
              ),
            ),
            Positioned.fill(
              child: HeroComposition(
                scope: scope,
                tone: PaywallTone.panel,
                headline: headline.tr(),
                // The stage and the words come in as the door opens.
                loop: HeroLoop([
                  for (final benefit in scope.benefits) benefit.previewId,
                ], prelude: DoorsTimeline.prelude),
                arrange: _arrange,
                // The shapes drift in the doorway, not on the wall.
                showsShapes: false,
              ),
            ),
            _onStage(
              (stage, doors) => IgnorePointer(
                child: PaywallClockBuilder(
                  clock: scope.clock,
                  builder: (context, t, _) => DoorsLeaf(
                    size: stage,
                    doorway: doors.doorway,
                    open: DoorsTimeline.open(t),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
