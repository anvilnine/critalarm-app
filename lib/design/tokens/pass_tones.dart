import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The five passes of the Personalize stack.
///
/// The order is the order of the stack on screen, top to bottom.
enum PassId {
  /// The alarm look. Its colour is the look in use, so a screen computes its
  /// [PassTone] and hands it to the card.
  look,

  /// The ringing sound.
  sound,

  /// The wake-up challenge.
  challenge,

  /// Home screen widgets.
  widgets,

  /// The app icon.
  appIcon,
}

/// The colours of one pass: the ground of its card and page, the text on it,
/// and the two colours the value takes.
@immutable
class PassTone {
  const PassTone({
    required this.ground,
    required this.onGround,
    Color? valueOn,
    Color? valueMuted,
  }) : valueOn = valueOn ?? onGround,
       valueMuted = valueMuted ?? onGround;

  /// The card and page colour.
  final Color ground;

  /// Label, tag, back ring and every line of text on [ground].
  final Color onGround;

  /// The value while the setting is on (a challenge is chosen).
  final Color valueOn;

  /// The value while the setting is off, and the foot line.
  final Color valueMuted;

  /// The value's colour for the setting's state.
  Color valueFor({required bool isOn}) => isOn ? valueOn : valueMuted;

  /// The 1 point line along the top of a card: [onGround] at 18%. It tells
  /// two cards of close tone apart.
  Color get edge => onGround.withValues(alpha: 0.18);

  @override
  bool operator ==(Object other) =>
      other is PassTone &&
      other.ground == ground &&
      other.onGround == onGround &&
      other.valueOn == valueOn &&
      other.valueMuted == valueMuted;

  @override
  int get hashCode => Object.hash(ground, onGround, valueOn, valueMuted);

  /// A tone part way between [a] and [b].
  // ignore: prefer_constructors_over_static_methods
  static PassTone lerp(PassTone a, PassTone b, double t) => PassTone(
    ground: Color.lerp(a.ground, b.ground, t)!,
    onGround: Color.lerp(a.onGround, b.onGround, t)!,
    valueOn: Color.lerp(a.valueOn, b.valueOn, t),
    valueMuted: Color.lerp(a.valueMuted, b.valueMuted, t),
  );
}

/// The tone of [pass] in the theme [colors] belong to.
///
/// Sound, challenge, widgets and app icon have one colour each. The look
/// pass has the colour of the look in use, which lives in feature code, so
/// for [PassId.look] this returns the standard look's tone (its ringing
/// canvas and ink). A screen that knows the look builds its own [PassTone].
PassTone passToneFor(PassId pass, AppColors colors) => switch (pass) {
  PassId.look => PassTone(ground: colors.critCanvas, onGround: colors.ink),
  PassId.sound => PassTone(
    ground: colors.highlight,
    onGround: colors.onHighlight,
  ),
  PassId.challenge => PassTone(
    ground: colors.panel,
    onGround: colors.onPanel,
    valueOn: colors.yellow,
    valueMuted: colors.onPanelMuted,
  ),
  PassId.widgets => PassTone(ground: colors.cream, onGround: colors.ink),
  PassId.appIcon => PassTone(ground: colors.surface, onGround: colors.ink),
};
