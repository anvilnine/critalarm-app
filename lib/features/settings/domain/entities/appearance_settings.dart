import 'package:flutter/foundation.dart';

/// How the app moves and feels, on top of what the OS already asks for.
///
/// [reduceMotion] only ever adds to the system setting: on, the app cuts its
/// animations even when the OS does not ask it to. Off, it follows the OS.
/// [hapticsEnabled] covers the app's own taps and confirmations, never the
/// alarm itself.
@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.reduceMotion = false,
    this.hapticsEnabled = true,
  });

  final bool reduceMotion;
  final bool hapticsEnabled;

  AppearanceSettings copyWith({bool? reduceMotion, bool? hapticsEnabled}) {
    return AppearanceSettings(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppearanceSettings &&
          runtimeType == other.runtimeType &&
          reduceMotion == other.reduceMotion &&
          hapticsEnabled == other.hapticsEnabled;

  @override
  int get hashCode => Object.hash(reduceMotion, hapticsEnabled);
}
