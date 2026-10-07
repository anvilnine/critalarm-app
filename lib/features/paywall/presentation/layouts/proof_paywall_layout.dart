import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_beats.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_scene.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_tag.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shows each benefit twice over: as it is on Free, then lifted.
///
/// It is the Hero composition with every turn split in two. For the first
/// beat the preview is at its refused or plain moment, the mascot doubts
/// it, and a small tag on the preview's corner says Free. Then the preview
/// goes through, the mascot hops, and the tag flips to the product's name
/// with Free struck out. A benefit with nothing to refuse plays its plain
/// default first and its extra second. One that Free does not have waits
/// grey behind a lock.
///
/// The tag keeps both names, so the frame a still screen rests on reads
/// the same way: this was Free, and now it is not. The stage, the lines,
/// the hand and the buy block are the kit's.
class ProofPaywallLayout extends StatefulWidget {
  const ProofPaywallLayout({super.key});

  @override
  State<ProofPaywallLayout> createState() => _ProofPaywallLayoutState();
}

class _ProofPaywallLayoutState extends State<ProofPaywallLayout> {
  HeroPlayer? _player;

  /// Where the preview's card stands, as the stage last arranged itself.
  /// Null while the stage has no card.
  final ValueNotifier<Rect?> _card = ValueNotifier<Rect?>(null);
  Rect? _askedCard;

  @override
  void dispose() {
    _player?.dispose();
    _card.dispose();
    super.dispose();
  }

  /// The approved arrangement. It also notes where the card is, because
  /// the tag sits on the card's corner.
  HeroArrangement _arrange(Size stage) {
    final arrangement = heroArrangementFor(stage);
    final card = arrangement.kind == HeroStageKind.pair
        ? arrangement.card
        : null;
    if (card != _askedCard) {
      _askedCard = card;
      // The stage is being built: the tag is told after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _card.value = card;
      });
    }
    return arrangement;
  }

  @override
  Widget build(BuildContext context) {
    final isStill = context.reduceMotion || PaywallStill.of(context);

    return PaywallFrame(
      // The mascot stands in the top left, so the cross takes the right.
      closeOnLeft: false,
      restAt: heroEntranceSeconds,
      builder: (context, scope) {
        final player = (_player ??= HeroPlayer(clock: scope.clock))
          ..clock = scope.clock
          ..loop = proofLoopFor([
            for (final benefit in scope.benefits) benefit.previewId,
          ]);
        final free = LocaleKeys.paywall_proof_tag_free.tr();
        final product = scope.isHosted
            ? LocaleKeys.paywall_proof_tag_hosted.tr()
            : LocaleKeys.paywall_proof_tag_pro.tr();

        return Stack(
          children: [
            Positioned.fill(
              child: HeroComposition(
                scope: scope,
                headline: scope.isHosted
                    ? LocaleKeys.paywall_proof_headline_hosted.tr()
                    : LocaleKeys.paywall_proof_headline_pro.tr(),
                loop: player.loop,
                player: player,
                arrange: _arrange,
                // The benefit's own preview, held on its Free frame first.
                sceneBuilder: (context, scene, size, playFrom) => ProofScene(
                  scene: scene,
                  count: scope.benefits.length,
                  size: size,
                  playFrom: playFrom,
                  clock: scope.clock,
                ),
              ),
            ),
            ValueListenableBuilder<Rect?>(
              valueListenable: _card,
              builder: (context, card, _) {
                if (card == null) return const SizedBox.shrink();
                return Positioned(
                  // Across the card's top edge, at its right corner.
                  top: card.top,
                  right: scope.size.width - card.right + _tagInset,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: FractionalTranslation(
                        translation: const Offset(0, -0.5),
                        child: PaywallClockBuilder(
                          clock: scope.clock,
                          builder: (context, t, _) {
                            final frame = player.frameAt(t);
                            return Transform.translate(
                              // It goes with the card under a finger.
                              offset: Offset(player.pullAt(t), 0),
                              child: ProofTag(
                                free: free,
                                product: product,
                                isCompact: scope.isCompact,
                                frame: proofTagFor(frame, isStill: isStill),
                                // After the card has landed.
                                entrance: phase(frame.entrance, 0.7, 1),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// How far in from the card's right edge the tag stands.
const double _tagInset = 14;
