import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
///
/// A0 maps these onto Crit Alarm's own moments. The alarm screen and the two
/// acknowledge stages are the ones that matter here.
abstract final class AppHaptics {
  /// Guard even though [HapticFeedback] already no-ops on web — keeps the
  /// platform channel untouched off-device.
  static bool get _enabled => !kIsWeb;

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

  /// A discrete choice: toggle, tab, accept/dismiss — the lightest tick.
  static void selection() {
    if (_enabled) unawaited(HapticFeedback.selectionClick());
  }
}
