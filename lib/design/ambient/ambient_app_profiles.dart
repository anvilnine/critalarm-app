import 'package:critalarm/design/ambient/ambient_profile.dart';
import 'package:critalarm/design/ambient/ambient_shape.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Central catalog of canonical ambient profiles across the Crit Alarm
/// application, ensuring consistent shape layering, depth, and smooth lerping.
abstract final class AmbientAppProfiles {
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
          color: colors.cobalt,
          opacity: 0.22,
          anchor: isTokenStep
              ? const Alignment(0.42, -0.90)
              : const Alignment(0.80, -0.70),
          scale: isTokenStep ? 0.52 : 0.46,
          turns: isTokenStep ? 0.11 : 0.05,
          depth: 0.25,
        ),
        AmbientShape(
          color: colors.high,
          opacity: 0.18,
          anchor: isTokenStep
              ? const Alignment(-0.92, -0.12)
              : const Alignment(-0.75, 0.20),
          scale: isTokenStep ? 0.33 : 0.38,
          turns: isTokenStep ? -0.18 : -0.10,
          depth: 0.55,
        ),
        AmbientShape(
          color: colors.crit,
          opacity: 0.14,
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

  /// Profile for the primary Topics dashboard tab.
  static AmbientProfile topics(AppColors colors) {
    return _triShapeProfile(
      canvas: colors.canvas,
      surfaceOpacity: 0.74,
      colors: [colors.cobalt, colors.high, colors.crit],
      anchors: const [
        Alignment(-0.9, -0.8),
        Alignment(0.8, -0.1),
        Alignment(-0.2, 0.9),
      ],
    );
  }

  /// Profile for the History tab.
  static AmbientProfile history(AppColors colors) {
    return _triShapeProfile(
      canvas: colors.canvas,
      surfaceOpacity: 0.76,
      colors: [colors.cobalt, colors.high, colors.crit],
      anchors: const [
        Alignment(-0.8, 0.5),
        Alignment(0.5, -0.7),
        Alignment(0.9, 0.8),
      ],
    );
  }

  /// Profile for the Settings tab.
  static AmbientProfile settings(AppColors colors) {
    return _triShapeProfile(
      canvas: colors.canvas,
      surfaceOpacity: 0.78,
      colors: [colors.cobalt, colors.high, colors.crit],
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

  /// Returns the canonical profile for a given root tab index (0: Topics,
  /// 1: History, 2: Settings).
  static AmbientProfile forTabIndex(int index, AppColors colors) {
    switch (index) {
      case 1:
        return history(colors);
      case 2:
        return settings(colors);
      case 0:
      default:
        return topics(colors);
    }
  }

  static AmbientProfile _triShapeProfile({
    required Color canvas,
    required double surfaceOpacity,
    required List<Color> colors,
    required List<Alignment> anchors,
  }) {
    return AmbientProfile(
      canvas: canvas,
      surfaceOpacity: surfaceOpacity,
      shapes: List<AmbientShape>.unmodifiable([
        for (var index = 0; index < colors.length; index++)
          AmbientShape(
            color: colors[index],
            opacity: const [0.24, 0.18, 0.14][index],
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
