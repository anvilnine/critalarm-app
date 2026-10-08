import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/challenges/domain/hold_to_skip.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The way out of a challenge. It is on screen for as long as the
/// challenge is, whatever the challenge itself is doing.
///
/// With [ChallengeWayOut.hold] the button is held for [holdToSkip]: it
/// fills as the hold goes on and counts the seconds down, and letting go
/// starts over. With [ChallengeWayOut.tap] it is a plain button. A screen
/// reader, a switch or a keyboard always gets the plain action, whichever
/// way it is drawn.
class HoldToSkipButton extends StatefulWidget {
  const HoldToSkipButton({
    required this.wayOut,
    required this.onSkip,
    this.heldFor,
    super.key,
  });

  final ChallengeWayOut wayOut;
  final VoidCallback onSkip;

  /// Draws the button this far into a hold and holds it there. Only a
  /// capture sets it.
  final Duration? heldFor;

  /// The height of the button at the default text size.
  static const double height = 52;

  @override
  State<HoldToSkipButton> createState() => _HoldToSkipButtonState();
}

class _HoldToSkipButtonState extends State<HoldToSkipButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: holdToSkip,
  )..addStatusListener(_onStatus);

  bool _didSkip = false;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    final heldFor = widget.heldFor;
    if (heldFor != null) _hold.value = holdProgress(heldFor);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _skip();
  }

  void _skip() {
    if (_didSkip) return;
    _didSkip = true;
    AppHaptics.capture();
    widget.onSkip();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null || _didSkip) return;
    _pointer = event.pointer;
    AppHaptics.selection();
    unawaited(_hold.forward(from: 0));
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    // Letting go early starts over. No penalty: the next hold is ten
    // seconds again and nothing else changes.
    if (!_didSkip) _hold.value = 0;
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Duration get _held => holdToSkip * _hold.value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (widget.wayOut == ChallengeWayOut.tap) {
      return AppButton(
        label: LocaleKeys.challenges_skip_tap.tr(),
        variant: AppButtonVariant.ghost,
        isFullWidth: true,
        onPressed: _skip,
      );
    }
    final seconds = holdToSkip.inSeconds;
    return Semantics(
      button: true,
      label: LocaleKeys.challenges_skip_tap.tr(),
      excludeSemantics: true,
      // Assistive technology cannot hold for ten seconds, so its action
      // is the plain one.
      onTap: _skip,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final held = _held;
            final isHolding = held > Duration.zero;
            return ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: HoldToSkipButton.height,
              ),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: Radii.fullAll,
                  border: Border.all(color: colors.onCanvas, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: Radii.fullAll,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The fill, from the leading edge.
                      Positioned.fill(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FractionallySizedBox(
                            widthFactor: holdProgress(held),
                            heightFactor: 1,
                            child: ColoredBox(color: colors.canvasGhostStrong),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.s4,
                          vertical: Spacing.s3,
                        ),
                        child: Text(
                          isHolding
                              ? LocaleKeys.challenges_skip_holding.tr(
                                  namedArgs: {
                                    'seconds': '${holdSecondsLeft(held)}',
                                  },
                                )
                              : LocaleKeys.challenges_skip_hold.tr(
                                  namedArgs: {'seconds': '$seconds'},
                                ),
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            colors.onCanvas,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
