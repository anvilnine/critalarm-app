import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// Distinct steps and visual states within the onboarding narrative.
enum OnboardingAmbientStep {
  /// Step 1A: Initial notification permission prompt.
  notifications,

  /// Step 1B: AlarmKit / Critical alerts permission prompt.
  alarms,

  /// Step 1C: Permission denied guidance and skip.
  denied,

  /// Step 2A: Connect to server (Cloud or self-hosted).
  connect,

  /// Step 2B: Connected to server, ready for test alarm.
  connected,

  /// Step 2C: Active countdown before test alarm rings.
  countdown,
}

/// Catalog of tailored ambient visual profiles for every onboarding state.
abstract final class OnboardingAmbientProfiles {
  /// Builds a map of all onboarding profiles adapted to the current [colors].
  static Map<OnboardingAmbientStep, AmbientProfile> forColors(
    AppColors colors,
  ) {
    return Map<OnboardingAmbientStep, AmbientProfile>.unmodifiable({
      OnboardingAmbientStep.notifications: _profile(
        canvas: colors.canvas,
        surfaceOpacity: 0.84,
        colors: [colors.cobalt, colors.high, colors.crit],
        opacities: const [0.24, 0.18, 0.14],
        anchors: const [
          Alignment(-0.82, -0.65),
          Alignment(0.78, 0.72),
          Alignment(0.85, -0.22),
        ],
        scales: const [0.44, 0.36, 0.28],
        turns: const [0.06, -0.08, 0.16],
        depths: const [0.35, 0.65, 0.85],
      ),
      OnboardingAmbientStep.alarms: _profile(
        canvas: colors.highCanvas,
        surfaceOpacity: 0.84,
        colors: [colors.cobalt, colors.high, colors.crit],
        opacities: const [0.22, 0.26, 0.16],
        anchors: const [
          Alignment(-0.35, -0.78),
          Alignment(0.72, 0.15),
          Alignment(-0.75, 0.62),
        ],
        scales: const [0.40, 0.42, 0.32],
        turns: const [0.10, 0.04, 0.22],
        depths: const [0.35, 0.65, 0.85],
      ),
      OnboardingAmbientStep.denied: _profile(
        canvas: colors.ackCanvas,
        surfaceOpacity: 0.88,
        colors: [colors.cobalt, colors.high, colors.canvasGhostStrong],
        opacities: const [0.14, 0.12, 0.10],
        anchors: const [
          Alignment(-0.60, -0.40),
          Alignment(0.55, 0.50),
          Alignment(0.40, -0.60),
        ],
        scales: const [0.36, 0.30, 0.24],
        turns: const [0.02, -0.04, 0.08],
        depths: const [0.35, 0.65, 0.85],
      ),
      OnboardingAmbientStep.connect: _profile(
        canvas: colors.canvas,
        surfaceOpacity: 0.80,
        colors: [colors.cobalt, colors.high, colors.crit],
        opacities: const [0.24, 0.18, 0.14],
        anchors: const [
          Alignment(0.75, -0.70),
          Alignment(-0.80, -0.05),
          Alignment(0.15, 0.82),
        ],
        scales: const [0.42, 0.34, 0.30],
        turns: const [0.08, -0.12, 0.20],
        depths: const [0.35, 0.65, 0.85],
      ),
      OnboardingAmbientStep.connected: _profile(
        canvas: colors.canvasAlt,
        surfaceOpacity: 0.78,
        colors: [colors.cobalt, colors.high, colors.crit],
        opacities: const [0.28, 0.24, 0.20],
        anchors: const [
          Alignment(-0.70, -0.55),
          Alignment(0.65, -0.45),
          Alignment(-0.10, 0.75),
        ],
        scales: const [0.48, 0.40, 0.36],
        turns: const [0.14, -0.06, 0.26],
        depths: const [0.35, 0.65, 0.85],
      ),
      OnboardingAmbientStep.countdown: _profile(
        canvas: colors.highCanvasAlt,
        surfaceOpacity: 0.82,
        colors: [colors.cobalt, colors.high, colors.crit],
        opacities: const [0.30, 0.28, 0.26],
        anchors: const [
          Alignment(-0.45, -0.35),
          Alignment(0.45, -0.30),
          Alignment(0, 0.55),
        ],
        scales: const [0.44, 0.42, 0.38],
        turns: const [0.20, -0.14, 0.32],
        depths: const [0.35, 0.65, 0.85],
      ),
    });
  }

  static AmbientProfile _profile({
    required Color canvas,
    required double surfaceOpacity,
    required List<Color> colors,
    required List<double> opacities,
    required List<Alignment> anchors,
    required List<double> scales,
    required List<double> turns,
    required List<double> depths,
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
            scale: scales[index],
            turns: turns[index],
            depth: depths[index],
          ),
      ]),
    );
  }
}
