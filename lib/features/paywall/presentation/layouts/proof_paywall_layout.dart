import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design_system/haptics.dart';
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
/// The two beats are felt in the card itself. At the refusal the card
/// shakes its head, and at the lift it jumps with the mascot. The mascot
/// is dropped in, leans toward the preview while it doubts it, and the
/// card turns over from one benefit to the next.
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

  PaywallClock? _watched;
  bool _isMuted = false;

  /// The turn the clock was last seen in, and how far into it.
  double? _seenTurn;
  double _seenSeconds = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMuted = PaywallMuted.of(context);
  }

  @override
  void dispose() {
    _watched?.removeListener(_onClock);
    _player?.dispose();
    _card.dispose();
    super.dispose();
  }

  void _watch(PaywallClock clock) {
    if (identical(clock, _watched)) return;
    _watched?.removeListener(_onClock);
    _watched = clock..addListener(_onClock);
  }

  /// The turn on the stage at [frame], or null when no benefit plays.
  ProofTurn? _turnOf(HeroFrame frame) {
    final scene = frame.scene;
    final preview = scene?.preview;
    final loop = _player?.loop;
    if (preview == null || loop == null || frame.entrance < 1) return null;
    return proofTurnFor(preview, count: loop.scenes.length);
  }

  /// How far the card is off its place now: the shake and the jump.
  Offset _nudgeAt(HeroFrame frame) {
    final turn = _turnOf(frame);
    if (turn == null || (_player?.isStill ?? true)) return Offset.zero;
    return proofNudgeAt(turn, frame.sceneSeconds);
  }

  // The two moments of a turn, felt and heard as the clock passes them.
  void _onClock() {
    final clock = _watched;
    final player = _player;
    if (clock == null || player == null || clock.isStill) return;
    final t = clock.value;
    final frame = player.frameAt(t);
    final turn = _turnOf(frame);
    final from = frame.turn == _seenTurn ? _seenSeconds : 0.0;
    _seenTurn = frame.turn;
    _seenSeconds = frame.sceneSeconds;
    if (turn == null || _isMuted) return;
    final cues = proofCuesAt(
      t,
      entranceEnd: player.loop.entranceEnd,
      period: player.loop.period,
      touched: player.hand != null,
    );
    if (!cues) return;
    final moments = proofMomentsBetween(turn, from, frame.sceneSeconds);
    // The refusal: the card shakes its head.
    if (moments.contains(ProofMoment.refusal)) AppHaptics.selection();
    // The lift: the card jumps and the tag turns over.
    if (moments.contains(ProofMoment.lift)) {
      AppHaptics.capture();
      getIt<PaywallCues>().tick();
    }
  }

  /// The approved arrangement, with the card moved by the shake and the
  /// jump of the turn playing. It also notes where the card rests,
  /// because the tag sits on the card's corner.
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
    final player = _player;
    if (card == null || player == null) return arrangement;
    final nudge = _nudgeAt(player.frame);
    if (nudge == Offset.zero) return arrangement;
    return _NudgedArrangement(arrangement, nudge);
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
          ], followsIntro: scope.followsIntro);
        _watch(scope.clock);
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
                motion: proofMotion,
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
                            final turn = _turnOf(frame);
                            return Transform.translate(
                              // It goes with the card: under a finger,
                              // in the shake and in the jump.
                              offset:
                                  Offset(player.pullAt(t), 0) + _nudgeAt(frame),
                              child: ProofTag(
                                free: free,
                                product: product,
                                isCompact: scope.isCompact,
                                frame: proofTagFor(frame, isStill: isStill),
                                // After the card has landed.
                                entrance: phase(frame.entrance, 0.7, 1),
                                swell: turn == null || isStill
                                    ? 1
                                    : proofTagSwellAt(
                                        turn,
                                        frame.sceneSeconds,
                                      ),
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

/// An arrangement whose card is off its place for a moment. The air and
/// the mascot stay where the resting arrangement has them.
class _NudgedArrangement extends HeroArrangement {
  _NudgedArrangement(this._rest, Offset nudge)
    : super(
        kind: _rest.kind,
        mascot: _rest.mascot,
        card: _rest.card.shift(nudge),
      );

  final HeroArrangement _rest;

  @override
  Rect get group => _rest.group;
}
