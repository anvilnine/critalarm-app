import 'dart:convert';

import 'package:flutter/widgets.dart';

/// What a screen draws behind a bar while a row of its list is under it.
enum BarBackingMode {
  /// The progressive blur and nothing over it.
  blur('blur'),

  /// The progressive blur with a fade of the canvas colour over it.
  blurAndGradient('blur_and_gradient'),

  /// A fade of the canvas colour and no blur.
  gradient('gradient'),

  /// A solid band of the canvas colour. Kept to compare against.
  solid('solid'),

  /// Nothing. Rows show through the bar.
  none('none');

  const BarBackingMode(this.key);

  /// Stored in preferences by the developer override.
  final String key;

  static BarBackingMode? fromKey(Object? key) {
    for (final mode in values) {
      if (mode.key == key) return mode;
    }
    return null;
  }

  bool get blurs => this == blur || this == blurAndGradient;
  bool get fadesCanvas => this == blurAndGradient || this == gradient;
}

/// How one bar is backed: the mode and its three numbers.
///
/// Every number is clamped to its range when the style is made, so a value
/// read back from preferences or typed by a slider can never be out of it.
@immutable
class BarBackingStyle {
  BarBackingStyle({
    required this.mode,
    required double blurSigma,
    required double fadeLength,
    required double gradientPeak,
  }) : blurSigma = blurSigma.clamp(0, maxBlurSigma).toDouble(),
       fadeLength = fadeLength.clamp(0, maxFadeLength).toDouble(),
       gradientPeak = gradientPeak.clamp(0, 1).toDouble();

  const BarBackingStyle._({
    required this.mode,
    required this.blurSigma,
    required this.fadeLength,
    required this.gradientPeak,
  });

  /// Reads a stored style. Anything missing or of the wrong kind takes its
  /// value from [fallback].
  factory BarBackingStyle.fromJson(Object? json, BarBackingStyle fallback) {
    if (json is! Map) return fallback;
    double number(String key, double otherwise) {
      final value = json[key];
      return value is num && value.isFinite ? value.toDouble() : otherwise;
    }

    return BarBackingStyle(
      mode: BarBackingMode.fromKey(json['mode']) ?? fallback.mode,
      blurSigma: number('blur', fallback.blurSigma),
      fadeLength: number('fade', fallback.fadeLength),
      gradientPeak: number('peak', fallback.gradientPeak),
    );
  }

  /// The strongest blur a slider reaches.
  static const double maxBlurSigma = 40;

  /// The longest fade a slider reaches, in logical pixels.
  static const double maxFadeLength = 96;

  final BarBackingMode mode;

  /// The blur right at the bar, as a sigma. It is the strength of the one
  /// blur the edge draws: a larger number never adds a blur layer.
  final double blurSigma;

  /// How far past the bar the effect runs before it is gone.
  final double fadeLength;

  /// How opaque the canvas colour is at the bar, 0 to 1. It always falls to
  /// nothing over [fadeLength] on a smooth curve.
  final double gradientPeak;

  BarBackingStyle copyWith({
    BarBackingMode? mode,
    double? blurSigma,
    double? fadeLength,
    double? gradientPeak,
  }) => BarBackingStyle(
    mode: mode ?? this.mode,
    blurSigma: blurSigma ?? this.blurSigma,
    fadeLength: fadeLength ?? this.fadeLength,
    gradientPeak: gradientPeak ?? this.gradientPeak,
  );

  Map<String, Object> toJson() => {
    'mode': mode.key,
    'blur': blurSigma,
    'fade': fadeLength,
    'peak': gradientPeak,
  };

  @override
  bool operator ==(Object other) =>
      other is BarBackingStyle &&
      mode == other.mode &&
      blurSigma == other.blurSigma &&
      fadeLength == other.fadeLength &&
      gradientPeak == other.gradientPeak;

  @override
  int get hashCode => Object.hash(mode, blurSigma, fadeLength, gradientPeak);

  @override
  String toString() =>
      'BarBackingStyle(${mode.key}, blur $blurSigma, fade $fadeLength, '
      'peak $gradientPeak)';
}

/// How the top bar and the pinned bottom bar are backed.
@immutable
class BarBackingConfig {
  const BarBackingConfig({required this.top, required this.bottom});

  /// Reads [encode]'s text back. Null, text that is not what [encode] made,
  /// or a missing half, gives the [defaults] for what is missing.
  factory BarBackingConfig.decode(String? text) {
    if (text == null || text.isEmpty) return defaults;
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return defaults;
    }
    if (json is! Map) return defaults;
    return BarBackingConfig(
      top: BarBackingStyle.fromJson(json['top'], defaults.top),
      bottom: BarBackingStyle.fromJson(json['bottom'], defaults.bottom),
    );
  }

  /// What every build ships with. A blur well stronger than the quiet edge
  /// blur (which is 4), under a fade of the canvas colour that stays well
  /// short of solid: a row under a bar is a soft smear right at the bar and
  /// sharp again a short way past it.
  static const BarBackingConfig defaults = BarBackingConfig(
    top: BarBackingStyle._(
      mode: BarBackingMode.blurAndGradient,
      blurSigma: 14,
      fadeLength: 28,
      gradientPeak: 0.6,
    ),
    bottom: BarBackingStyle._(
      mode: BarBackingMode.blurAndGradient,
      blurSigma: 16,
      fadeLength: 28,
      gradientPeak: 0.7,
    ),
  );

  final BarBackingStyle top;
  final BarBackingStyle bottom;

  BarBackingConfig copyWith({BarBackingStyle? top, BarBackingStyle? bottom}) =>
      BarBackingConfig(top: top ?? this.top, bottom: bottom ?? this.bottom);

  /// The text the developer override keeps in preferences.
  String encode() =>
      jsonEncode({'top': top.toJson(), 'bottom': bottom.toJson()});

  @override
  bool operator ==(Object other) =>
      other is BarBackingConfig && top == other.top && bottom == other.bottom;

  @override
  int get hashCode => Object.hash(top, bottom);

  @override
  String toString() => 'BarBackingConfig(top: $top, bottom: $bottom)';
}

/// The least opaque the canvas fade is where a mode that blurs cannot blur:
/// a phone that draws no edge blur, or any phone held sideways. Without the
/// blur under it a light fade leaves the row behind a button readable.
const double barBackingPeakWithoutBlur = 0.9;

/// The canvas fade's opacity at the bar for [style], given whether the blur
/// under it is really drawn.
double barBackingGradientPeak(BarBackingStyle style, {required bool blurs}) {
  switch (style.mode) {
    case BarBackingMode.gradient:
      return style.gradientPeak;
    case BarBackingMode.blurAndGradient:
      return blurs || style.gradientPeak > barBackingPeakWithoutBlur
          ? style.gradientPeak
          : barBackingPeakWithoutBlur;
    case BarBackingMode.blur:
      return blurs ? 0 : barBackingPeakWithoutBlur;
    case BarBackingMode.solid:
    case BarBackingMode.none:
      return 0;
  }
}

/// The config every screen draws with. It holds [BarBackingConfig.defaults]
/// for the whole run of a store build. A build with Developer options moves
/// it when the developer override changes.
final ValueNotifier<BarBackingConfig> appBarBacking = ValueNotifier(
  BarBackingConfig.defaults,
);

/// Hands the [BarBackingConfig] down the tree. The app puts one at its root,
/// fed by [appBarBacking], so a change reaches every screen at once.
class BarBackingConfigScope extends InheritedWidget {
  const BarBackingConfigScope({
    required this.config,
    required super.child,
    super.key,
  });

  final BarBackingConfig config;

  /// The config for [context], or the defaults with no scope above it.
  static BarBackingConfig of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BarBackingConfigScope>()
          ?.config ??
      BarBackingConfig.defaults;

  @override
  bool updateShouldNotify(BarBackingConfigScope oldWidget) =>
      config != oldWidget.config;
}
