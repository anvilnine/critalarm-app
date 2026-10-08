import 'package:flutter/widgets.dart';

/// What a screen draws behind a bar while a row of its list is under it.
enum BarBackingMode {
  /// The progressive blur and nothing over it.
  blur,

  /// The progressive blur with a fade of the canvas colour over it.
  blurAndGradient,

  /// A fade of the canvas colour and no blur.
  gradient,

  /// A solid band of the canvas colour. Kept to compare against.
  solid,

  /// Nothing. Rows show through the bar.
  none;

  bool get blurs => this == blur || this == blurAndGradient;
  bool get fadesCanvas => this == blurAndGradient || this == gradient;
}

/// How one bar is backed: the mode and its three numbers.
///
/// Every number is clamped to its range when the style is made.
@immutable
class BarBackingStyle {
  BarBackingStyle({
    required this.mode,
    required double blurSigma,
    required double fadeLength,
    required double gradientPeak,
    double plateau = 0,
  }) : blurSigma = blurSigma.clamp(0, maxBlurSigma).toDouble(),
       fadeLength = fadeLength.clamp(0, maxFadeLength).toDouble(),
       gradientPeak = gradientPeak.clamp(0, 1).toDouble(),
       plateau = plateau.clamp(0, 1).toDouble();

  const BarBackingStyle._({
    required this.mode,
    required this.blurSigma,
    required this.fadeLength,
    required this.gradientPeak,
    required this.plateau,
  });

  /// The strongest blur a style may ask for.
  static const double maxBlurSigma = 40;

  /// The longest fade a style may ask for, in logical pixels.
  static const double maxFadeLength = 96;

  final BarBackingMode mode;

  /// The blur at the edge of the screen, as a sigma. The blur is nothing
  /// where a row comes out from under the effect and rises smoothly to this
  /// only at the screen edge. It is the strength of the one blur the edge
  /// draws: a larger number never adds a blur layer.
  final double blurSigma;

  /// How far past the bar the effect starts. The effect runs over the bar's
  /// own height plus this, and the ramp spans all of it.
  final double fadeLength;

  /// How opaque the canvas colour is at the edge of the screen, 0 to 1. Like
  /// the blur it is nothing at the inner edge and rises smoothly across the
  /// whole zone.
  final double gradientPeak;

  /// How much of the zone, measured from the screen edge, holds the full
  /// strength, 0 to 1. 0 is fully progressive: no part of the zone is flat.
  final double plateau;

  BarBackingStyle copyWith({
    BarBackingMode? mode,
    double? blurSigma,
    double? fadeLength,
    double? gradientPeak,
    double? plateau,
  }) => BarBackingStyle(
    mode: mode ?? this.mode,
    blurSigma: blurSigma ?? this.blurSigma,
    fadeLength: fadeLength ?? this.fadeLength,
    gradientPeak: gradientPeak ?? this.gradientPeak,
    plateau: plateau ?? this.plateau,
  );

  @override
  bool operator ==(Object other) =>
      other is BarBackingStyle &&
      mode == other.mode &&
      blurSigma == other.blurSigma &&
      fadeLength == other.fadeLength &&
      gradientPeak == other.gradientPeak &&
      plateau == other.plateau;

  @override
  int get hashCode =>
      Object.hash(mode, blurSigma, fadeLength, gradientPeak, plateau);

  @override
  String toString() =>
      'BarBackingStyle(${mode.name}, blur $blurSigma, fade $fadeLength, '
      'peak $gradientPeak, plateau $plateau)';
}

/// How the top bar and the pinned bottom bar are backed.
@immutable
class BarBackingConfig {
  const BarBackingConfig({required this.top, required this.bottom});

  /// What every screen draws with: the progressive blur with a fade of the
  /// canvas colour over it. The top fade is nearly solid at the screen edge,
  /// so a row never shows through the title. The bottom one is light, so a
  /// card pinned there still floats over the list.
  static const BarBackingConfig defaults = BarBackingConfig(
    top: BarBackingStyle._(
      mode: BarBackingMode.blurAndGradient,
      blurSigma: 40,
      fadeLength: 45,
      gradientPeak: 0.9,
      plateau: 0.1,
    ),
    bottom: BarBackingStyle._(
      mode: BarBackingMode.blurAndGradient,
      blurSigma: 34.5,
      fadeLength: 38,
      gradientPeak: 0.15,
      plateau: 0.1,
    ),
  );

  final BarBackingStyle top;
  final BarBackingStyle bottom;

  BarBackingConfig copyWith({BarBackingStyle? top, BarBackingStyle? bottom}) =>
      BarBackingConfig(top: top ?? this.top, bottom: bottom ?? this.bottom);

  @override
  bool operator ==(Object other) =>
      other is BarBackingConfig && top == other.top && bottom == other.bottom;

  @override
  int get hashCode => Object.hash(top, bottom);

  @override
  String toString() => 'BarBackingConfig(top: $top, bottom: $bottom)';
}

/// How strong the effect is at one point of its zone, 0 to 1.
///
/// [position] runs from 0 at the inner edge, where a row comes out from
/// under the effect, to 1 at the edge of the screen. The curve is smoothstep
/// across the whole zone: nothing at the inner edge, full only at the screen
/// edge, flat at both ends so there is no line where it starts. It is the
/// curve the edge blur has always had. [plateau] is the part of the zone at
/// the screen edge that holds full strength, and 0 leaves no flat part.
double barBackingRamp(double position, {double plateau = 0}) {
  final hold = plateau.clamp(0.0, 1.0);
  if (hold >= 1) return 1;
  final t = (position / (1 - hold)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
