import 'package:flutter/foundation.dart';

/// The two ring switches in Settings, for every topic on this phone. Both
/// start on, and both are free on every plan: they are part of the alarm.
///
/// The volume is not here. Every ring starts at full volume and there is no
/// switch for that.
@immutable
class RingSettings {
  const RingSettings({this.brightScreen = true, this.vibrate = true});

  /// The alarm screen goes to full brightness and keeps the screen on.
  final bool brightScreen;

  /// The phone vibrates on the beat of the alarm sound.
  final bool vibrate;

  RingSettings copyWith({bool? brightScreen, bool? vibrate}) => RingSettings(
    brightScreen: brightScreen ?? this.brightScreen,
    vibrate: vibrate ?? this.vibrate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RingSettings &&
          brightScreen == other.brightScreen &&
          vibrate == other.vibrate;

  @override
  int get hashCode => Object.hash(brightScreen, vibrate);
}
