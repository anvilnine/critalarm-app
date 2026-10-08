import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/animation.dart';

// The curtain call, as numbers. A closed curtain. The mascot peeks out
// between the two halves, looks left, looks right, sees you, and throws
// them open on the layout.

/// The joke's timeline. Every value is a pure function of the seconds
/// since the screen appeared.
abstract final class CurtainTimeline {
  /// The halves part a little and the mascot looks out from behind them.
  static const double peek = 0.3;

  /// It looks to the left, then to the right.
  static const double lookLeft = 0.5;
  static const double lookRight = 0.78;

  /// It sees you, and pokes its head out in front of the curtain.
  static const double spot = 1.04;

  /// The halves are thrown open. A tap during the joke jumps here.
  static const double reveal = 1.34;

  /// The layout's own entrance starts. The mascot is gone by now.
  static const double handover = 1.68;

  /// Nothing of the joke is drawn from here on.
  static const double end = 1.76;

  /// How wide the gap is while the mascot peeks, as a part of the screen's
  /// width.
  static const double peekGap = 0.22;

  /// How wide the gap between the halves is at [t], as a part of the
  /// screen's width. From one on, both halves are off the screen.
  static double gap(double t) {
    final parted = AppCurves.easeOut.transform(phase(t, peek, peek + 0.2));
    final thrown = Curves.easeInOutCubic.transform(phase(t, reveal, end));
    return peekGap * parted + (1.04 - peekGap) * thrown;
  }

  /// How far the halves sway at [t], -1 to 1: one rustle before the peek,
  /// and still after it.
  static double rustle(double t) => t >= peek
      ? 0
      : math.sin(2 * math.pi * 3 * t) * math.sin(math.pi * t / peek);

  /// Whether the mascot is still behind the curtain at [t], seen only
  /// through the gap. From [spot] on its head is out in front.
  static bool isBehind(double t) => t < spot;

  /// How much of the dark behind the curtain shows in the gap at [t], 1
  /// to 0. It holds until the halves are thrown open, so the layout is
  /// not seen through the gap before then.
  static double backstage(double t) => 1 - phase(t, reveal, reveal + 0.1);

  /// How far through poking its head out the mascot is at [t], 0 to 1.
  static double pokeOut(double t) => phase(t, spot, spot + 0.18);

  /// The face at [t]: looking left, looking right, the start of seeing
  /// you, then glad.
  static IntroFaceBlend face(double t) {
    if (t < lookRight) {
      return (
        from: FaceState.watching,
        to: FaceState.lookLeft,
        blend: phase(t, lookLeft, lookLeft + 0.1),
      );
    }
    if (t < spot) {
      return (
        from: FaceState.lookLeft,
        to: FaceState.lookRight,
        blend: phase(t, lookRight, lookRight + 0.12),
      );
    }
    if (t < reveal) {
      return (
        from: FaceState.lookRight,
        to: FaceState.realization,
        blend: phase(t, spot, spot + 0.1),
      );
    }
    return (
      from: FaceState.realization,
      to: FaceState.happy,
      blend: phase(t, reveal, reveal + 0.16),
    );
  }

  /// How far in the line is at [t], 0 to 1.
  static double line(double t) => phase(t, spot + 0.04, spot + 0.2);

  /// How much of the line is left at [t], 1 to 0. It goes as the halves
  /// it is written on are thrown open.
  static double words(double t) => 1 - phase(t, reveal, reveal + 0.12);

  /// How far out the mascot is at [t], 0 to 1. One by the hand over.
  static double leave(double t) => phase(t, handover - 0.24, handover);

  /// True once nothing of the joke is drawn.
  static bool isOver(double t) => t >= end;
}
