import 'package:critalarm/design/ambient/ambient_profile.dart';
import 'package:critalarm/design/ambient/ambient_shape.dart';
import 'package:critalarm/design/ambient/hero_disc.dart';
import 'package:critalarm/design/ambient/hero_tone.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Central catalog of canonical ambient profiles across the Crit Alarm
/// application, ensuring consistent shape layering, depth, and smooth lerping.
abstract final class AmbientAppProfiles {
  /// The two tints calm screens use, so the canvas never gets cobalt or red.
  /// Red belongs to the critical profiles only.
  static const Color _calmOrange = Color(0xFFFFB21F);
  static const Color _calmPale = Color(0xFFFFE08A);

  /// Alpha for a calm shape. Dark canvases get half of it, because the same
  /// tints read much louder on near-black.
  static double _calmOpacity(AppColors colors, double lightOpacity) {
    final isDark = colors.canvas.computeLuminance() < 0.5;
    return isDark ? lightOpacity / 2 : lightOpacity;
  }

  /// Profile for the ringing Critical Alarm takeover screen.
  static AmbientProfile criticalAlarmRinging(AppColors colors) {
    return AmbientProfile(
      canvas: colors.critCanvas,
      surfaceOpacity: 0.88,
      shapes: List<AmbientShape>.unmodifiable([
        AmbientShape(
          color: colors.crit,
          opacity: 0.32,
          anchor: const Alignment(0, -0.65),
          scale: 0.54,
          turns: 0.08,
          depth: 0.25,
        ),
        AmbientShape(
          color: colors.high,
          opacity: 0.22,
          anchor: const Alignment(-0.85, 0.35),
          scale: 0.42,
          turns: -0.12,
          depth: 0.55,
        ),
        AmbientShape(
          color: colors.cobalt,
          opacity: 0.16,
          anchor: const Alignment(0.85, 0.70),
          scale: 0.34,
          turns: 0.20,
          depth: 0.85,
        ),
      ]),
    );
  }

  /// Profile for the acknowledged/cleared Critical Alarm celebration screen.
  static AmbientProfile criticalAlarmAcknowledged(AppColors colors) {
    return AmbientProfile(
      canvas: colors.ackCanvas,
      surfaceOpacity: 0.84,
      shapes: List<AmbientShape>.unmodifiable([
        AmbientShape(
          color: colors.ackStroke,
          opacity: 0.24,
          anchor: const Alignment(-0.70, -0.50),
          scale: 0.44,
          turns: 0.04,
          depth: 0.25,
        ),
        AmbientShape(
          color: colors.cobalt,
          opacity: 0.18,
          anchor: const Alignment(0.75, -0.20),
          scale: 0.36,
          turns: -0.08,
          depth: 0.55,
        ),
        AmbientShape(
          color: colors.high,
          opacity: 0.14,
          anchor: const Alignment(0.10, 0.80),
          scale: 0.30,
          turns: 0.14,
          depth: 0.85,
        ),
      ]),
    );
  }

  /// Profile for the Create Topic modal/screen.
  ///
  /// [step] is 1 for the topic name step and 2 for the token step. Step 2 keeps
  /// the same three shapes, colours and opacities, and only moves and resizes
  /// them, so handing this to the canvas drifts the background along with the
  /// card instead of swapping the screen out.
  static AmbientProfile createTopic(AppColors colors, {int step = 1}) {
    final isTokenStep = step >= 2;

    return AmbientProfile(
      canvas: colors.canvas,
      surfaceOpacity: 0.82,
      shapes: List<AmbientShape>.unmodifiable([
        AmbientShape(
          color: _calmOrange,
          opacity: _calmOpacity(colors, 0.6),
          anchor: isTokenStep
              ? const Alignment(0.42, -0.90)
              : const Alignment(0.80, -0.70),
          scale: isTokenStep ? 0.52 : 0.46,
          turns: isTokenStep ? 0.11 : 0.05,
          depth: 0.25,
        ),
        AmbientShape(
          color: _calmPale,
          opacity: _calmOpacity(colors, 0.5),
          anchor: isTokenStep
              ? const Alignment(-0.92, -0.12)
              : const Alignment(-0.75, 0.20),
          scale: isTokenStep ? 0.33 : 0.38,
          turns: isTokenStep ? -0.18 : -0.10,
          depth: 0.55,
        ),
        AmbientShape(
          color: _calmOrange,
          opacity: _calmOpacity(colors, 0.5),
          anchor: isTokenStep
              ? const Alignment(0.40, 0.68)
              : const Alignment(0.10, 0.85),
          scale: isTokenStep ? 0.34 : 0.28,
          turns: isTokenStep ? 0.24 : 0.16,
          depth: 0.85,
        ),
      ]),
    );
  }

  /// The three blobs the Topics tab used before it had a hero. The Topic
  /// screen is drawn from them, so a push from the list still moves the
  /// canvas.
  static AmbientProfile topics(AppColors colors) {
    return _triShapeProfile(
      canvas: colors.canvas,
      surfaceOpacity: 0.74,
      colors: const [_calmOrange, _calmPale, _calmOrange],
      opacities: [
        _calmOpacity(colors, 0.6),
        _calmOpacity(colors, 0.5),
        _calmOpacity(colors, 0.5),
      ],
      anchors: const [
        Alignment(-0.9, -0.8),
        Alignment(0.8, -0.1),
        Alignment(-0.2, 0.9),
      ],
    );
  }

  /// Profile for the Topics tab, where the hero's face and card sit on a big
  /// pale disc with a faint ring around it.
  ///
  /// The shapes keep the three slots every profile has: the disc in the first
  /// (a circle), a pill nobody sees in the second (so the tab profiles can
  /// grow one when the canvas morphs), and the ring in the third. Handing a
  /// different profile to the canvas retints, moves and resizes them with the
  /// same lerp the tab changes use.
  ///
  /// - [severity]: the canvas the card state asks for. [SeverityMode.none] is
  ///   the yellow ground; high, crit and ack are the warning, ringing and
  ///   acknowledged canvases. Under one of those the disc is the canvas's
  ///   lighter step already, so pass [AppHeroTone.calm] with it.
  /// - [tone]: how the disc is tinted on the yellow ground.
  /// - [spot]: where the disc sits, from `heroDiscSpot`. The default is a
  ///   390 by 844 phone.
  static AmbientProfile topicsHero(
    AppColors colors, {
    SeverityMode severity = SeverityMode.none,
    AppHeroTone tone = AppHeroTone.calm,
    HeroDiscSpot spot = HeroDiscSpot.phone,
  }) {
    final ground = colors.withSeverity(severity);
    final (discColor, discOpacity) = tone.discTint(ground);
    return AmbientProfile(
      canvas: ground.canvas,
      surfaceOpacity: 0.74,
      shapes: List<AmbientShape>.unmodifiable([
        AmbientShape(
          color: discColor,
          opacity: discOpacity,
          anchor: spot.anchor,
          scale: spot.discScale,
          turns: 0,
          depth: 0.25,
        ),
        // Not drawn. It sits where the tab profiles' second shape does, so
        // that shape fades in from nothing in place.
        const AmbientShape(
          color: _calmPale,
          opacity: 0,
          anchor: Alignment(0.8, -0.1),
          scale: 0.35,
          turns: -0.1,
          depth: 0.55,
        ),
        AmbientShape(
          // Orange on the yellow ground, like the blob it turns into when
          // the canvas moves to another tab, so the shape never passes
          // through a muddy mid tone. Ink under a severity canvas, which has
          // no orange of its own.
          color: severity == SeverityMode.none ? _calmOrange : ground.onCanvas,
          opacity: severity == SeverityMode.none
              ? _calmOpacity(colors, 0.22)
              : 0.06,
          anchor: spot.anchor,
          scale: spot.ringScale,
          turns: 0,
          depth: 0.85,
          ring: 1,
        ),
      ]),
    );
  }

  /// Profile for the History tab.
  static AmbientProfile history(AppColors colors) {
    return _triShapeProfile(
      canvas: colors.canvas,
      surfaceOpacity: 0.76,
      colors: const [_calmOrange, _calmPale, _calmOrange],
      opacities: [
        _calmOpacity(colors, 0.6),
        _calmOpacity(colors, 0.5),
        _calmOpacity(colors, 0.5),
      ],
      anchors: const [
        Alignment(-0.8, 0.5),
        Alignment(0.5, -0.7),
        Alignment(0.9, 0.8),
      ],
    );
  }

  /// Profile for the History tab with its small face on show: a pale disc
  /// behind the face and the top of the stat card.
  ///
  /// It keeps the three slots every profile has. The disc takes the first
  /// (a circle) and is tinted like the Topics hero's calm disc. The pill in
  /// the second is not drawn, so it fades in and out in place when the canvas
  /// morphs to a tab profile. The third is the orange blob of [history].
  ///
  /// [spot] is where the disc sits, from the screen's own layout. Its
  /// [HeroDiscSpot.ringScale] is not used.
  static AmbientProfile historyHero(
    AppColors colors, {
    HeroDiscSpot spot = HeroDiscSpot.historyPhone,
  }) {
    final (discColor, discOpacity) = AppHeroTone.calm.discTint(colors);
    return AmbientProfile(
      canvas: colors.canvas,
      surfaceOpacity: 0.76,
      shapes: List<AmbientShape>.unmodifiable([
        AmbientShape(
          color: discColor,
          opacity: discOpacity,
          anchor: spot.anchor,
          scale: spot.discScale,
          turns: 0,
          depth: 0.25,
        ),
        // Not drawn. It sits where the History tab profile's pill does.
        const AmbientShape(
          color: _calmPale,
          opacity: 0,
          anchor: Alignment(0.5, -0.7),
          scale: 0.35,
          turns: -0.1,
          depth: 0.55,
        ),
        AmbientShape(
          color: _calmOrange,
          opacity: _calmOpacity(colors, 0.5),
          anchor: const Alignment(0.9, 0.8),
          scale: 0.29,
          turns: 0.18,
          depth: 0.85,
        ),
      ]),
    );
  }

  /// Profile for the Settings tab.
  static AmbientProfile settings(AppColors colors) {
    return _triShapeProfile(
      canvas: colors.canvas,
      surfaceOpacity: 0.78,
      colors: const [_calmOrange, _calmPale, _calmOrange],
      opacities: [
        _calmOpacity(colors, 0.6),
        _calmOpacity(colors, 0.5),
        _calmOpacity(colors, 0.5),
      ],
      anchors: const [
        Alignment(0.8, -0.8),
        Alignment(-0.9, 0.1),
        Alignment(0, 0.9),
      ],
    );
  }

  /// Topic detail screen profile.
  static AmbientProfile topicDetail(AppColors colors) {
    return _detailOf(topics(colors), canvas: colors.canvas);
  }

  /// History detail screen profile.
  static AmbientProfile historyDetail(AppColors colors) {
    return _detailOf(history(colors), canvas: colors.canvas);
  }

  /// Settings detail screen profile.
  static AmbientProfile settingsDetail(AppColors colors) {
    return _detailOf(settings(colors), canvas: colors.canvas);
  }

  /// The sound list. One step deeper than [settingsDetail], since Alarms
  /// opens it.
  static AmbientProfile soundList(AppColors colors) {
    return _detailOf(settingsDetail(colors), canvas: colors.canvas);
  }

  /// The cropper and the recorder, one step deeper than [soundList], which
  /// opens them.
  static AmbientProfile soundEditor(AppColors colors) {
    return _detailOf(soundList(colors), canvas: colors.canvas);
  }

  /// Returns the canonical profile for a given root tab index (0: Topics,
  /// 1: History, 2: Settings). Topics gets its calm hero profile.
  static AmbientProfile forTabIndex(int index, AppColors colors) {
    switch (index) {
      case 1:
        return history(colors);
      case 2:
        return settings(colors);
      case 0:
      default:
        return topicsHero(colors);
    }
  }

  static AmbientProfile _triShapeProfile({
    required Color canvas,
    required double surfaceOpacity,
    required List<Color> colors,
    required List<double> opacities,
    required List<Alignment> anchors,
  }) {
    return AmbientProfile(
      canvas: canvas,
      surfaceOpacity: surfaceOpacity,
      shapes: List<AmbientShape>.unmodifiable([
        for (var index = 0; index < colors.length; index++)
          AmbientShape(
            color: colors[index],
            opacity: opacities[index],
            anchor: anchors[index],
            scale: const [0.44, 0.35, 0.29][index],
            turns: const [0.06, -0.1, 0.18][index],
            depth: const [0.25, 0.55, 0.85][index],
          ),
      ]),
    );
  }

  static AmbientProfile _detailOf(
    AmbientProfile root, {
    required Color canvas,
  }) {
    const offsets = [
      Alignment(0.12, 0.08),
      Alignment(-0.1, 0.12),
      Alignment(0.08, -0.1),
    ];

    return AmbientProfile(
      canvas: canvas,
      surfaceOpacity: (root.surfaceOpacity + 0.02).clamp(0.60, 0.90),
      shapes: List<AmbientShape>.unmodifiable([
        for (var index = 0; index < root.shapes.length; index++)
          AmbientShape(
            color: root.shapes[index].color,
            opacity: root.shapes[index].opacity,
            anchor: Alignment(
              (root.shapes[index].anchor.x + offsets[index].x).clamp(-1.0, 1.0),
              (root.shapes[index].anchor.y + offsets[index].y).clamp(-1.0, 1.0),
            ),
            scale: (root.shapes[index].scale + 0.04).clamp(0.1, 1.0),
            turns: root.shapes[index].turns + 0.04,
            depth: root.shapes[index].depth,
          ),
      ]),
    );
  }
}
