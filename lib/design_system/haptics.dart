import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One pulse of a pattern, named by weight.
///
/// These are the system's own pulses, sent through Flutter's
/// [HapticFeedback]. An iPhone has a separate feel for each. Android has one
/// short effect for each as well, but how far apart they feel is up to the
/// phone, and on some phones [light], [medium] and [heavy] are close.
enum HapticPulse { tick, light, medium, heavy }

/// A named haptic. Every pattern is a short list of pulses and the time each
/// one comes, in milliseconds from the start.
///
/// The gaps match the sounds they are played with: the second knock of
/// [doubleKnock] and the bounces of [tripleFade] land where the sound has
/// them.
enum HapticPattern {
  /// No haptic at all.
  none([]),

  /// The lightest click, for a change of selection.
  tick([(atMs: 0, pulse: HapticPulse.tick)]),

  /// One light tap.
  light([(atMs: 0, pulse: HapticPulse.light)]),

  /// One solid press.
  medium([(atMs: 0, pulse: HapticPulse.medium)]),

  /// One heavy thud.
  heavy([(atMs: 0, pulse: HapticPulse.heavy)]),

  /// Two even knocks. A refusal.
  doubleKnock([
    (atMs: 0, pulse: HapticPulse.medium),
    (atMs: 130, pulse: HapticPulse.medium),
  ]),

  /// Three pulses, each lighter and sooner. Something lands and settles.
  tripleFade([
    (atMs: 0, pulse: HapticPulse.heavy),
    (atMs: 170, pulse: HapticPulse.medium),
    (atMs: 280, pulse: HapticPulse.light),
  ]),

  /// A light tap and then a firmer one. Something was allowed or went well.
  risingPair([
    (atMs: 0, pulse: HapticPulse.light),
    (atMs: 85, pulse: HapticPulse.medium),
  ]),

  /// A light tap and then a fainter one. Something was let go, gently.
  fallingPair([
    (atMs: 0, pulse: HapticPulse.light),
    (atMs: 110, pulse: HapticPulse.tick),
  ]);

  const HapticPattern(this.steps);

  /// The pulses in order.
  final List<({int atMs, HapticPulse pulse})> steps;

  /// The most pulses a pattern may have.
  static const maxPulses = 3;

  /// The longest a pattern may run, from first pulse to last.
  static const maxSpan = Duration(milliseconds: 320);
}

/// Centralized haptic feedback — confirmations and important actions only,
/// never every tap. Call sites stay one-liners; web is a safe no-op.
///
/// The feel is physical and honest: the app confirms with a thud, it does not
/// buzz for attention.
/// - [capture] a deliberate action fires: a solid mechanical press (medium).
/// - [success] something is saved: the heaviest confirm.
/// - [destructive] a delete is confirmed: heavy, so it registers as final.
/// - [done] a run of work is finished: medium.
/// - [selection] segmented and mode toggles, tab changes, accept and dismiss.
/// - [failed] a refresh did not work: heavy, so it feels unlike [done].
/// - [tick] one small step of something that moves by itself: ultra-light.
/// - [lightTap] something small lands in place: light.
///
/// [play] takes a named [HapticPattern] for the moments that want more than
/// one of the above: a double knock, a landing that bounces. A pattern is at
/// most three short pulses inside a third of a second, so none of them can be
/// mistaken for an alarm's vibration.
///
/// A0 maps these onto Crit Alarm's own moments. The alarm screen and the two
/// acknowledge stages are the ones that matter here.
abstract final class AppHaptics {
  /// The user's Haptics switch in Settings → Appearance. AppearanceCubit
  /// keeps this in step with the saved choice; nothing else should set it.
  /// It only covers these taps and confirmations, never the alarm's own
  /// vibration.
  static bool userEnabled = true;

  /// Guard even though [HapticFeedback] already no-ops on web — keeps the
  /// platform channel untouched off-device.
  static bool get _enabled => !kIsWeb && userEnabled;

  /// A deliberate, solid press. For the actions the user means to take.
  static void capture() {
    if (_enabled) unawaited(HapticFeedback.mediumImpact());
  }

  /// Something was saved. The confirming thud.
  static void success() {
    if (_enabled) unawaited(HapticFeedback.heavyImpact());
  }

  /// A destructive action confirmed (delete) — heavy, reads as final.
  static void destructive() {
    if (_enabled) unawaited(HapticFeedback.heavyImpact());
  }

  /// A run of work finished. Medium, matching the deliberate press.
  static void done() {
    if (_enabled) unawaited(HapticFeedback.mediumImpact());
  }

  /// A refresh did not work. Heavy, so it feels unlike [done].
  static void failed() {
    if (_enabled) unawaited(HapticFeedback.heavyImpact());
  }

  /// A discrete choice: toggle, tab, accept/dismiss — the lightest tick.
  static void selection() {
    if (_enabled) unawaited(HapticFeedback.selectionClick());
  }

  /// One small step of something that moves by itself: a typed character, a
  /// bar gaining a step. Ultra-light, the faintest the phone can make.
  static void tick() {
    if (_enabled) unawaited(HapticFeedback.selectionClick());
  }

  /// Something small lands in place: a card arrives, a command is sent.
  /// Light.
  static void lightTap() {
    if (_enabled) unawaited(HapticFeedback.lightImpact());
  }

  static final _pending = <Timer>[];

  /// Plays a named pattern. A pattern still under way is dropped first, so
  /// two never pile up into a buzz.
  static void play(HapticPattern pattern) {
    cancelPattern();
    if (!_enabled) return;
    for (final step in pattern.steps) {
      if (step.atMs == 0) {
        _pulse(step.pulse);
        continue;
      }
      _pending.add(
        Timer(Duration(milliseconds: step.atMs), () {
          // The switch is read again: it may have been turned off meanwhile.
          if (_enabled) _pulse(step.pulse);
        }),
      );
    }
  }

  /// Drops the pulses of a pattern that have not come yet. Safe to call when
  /// there are none.
  static void cancelPattern() {
    for (final timer in _pending) {
      timer.cancel();
    }
    _pending.clear();
  }

  static void _pulse(HapticPulse pulse) {
    unawaited(switch (pulse) {
      HapticPulse.tick => HapticFeedback.selectionClick(),
      HapticPulse.light => HapticFeedback.lightImpact(),
      HapticPulse.medium => HapticFeedback.mediumImpact(),
      HapticPulse.heavy => HapticFeedback.heavyImpact(),
    });
  }
}
