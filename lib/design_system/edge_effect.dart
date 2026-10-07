import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// What the scaffold draws where the list scrolls under the top bar and the
/// tab bar. Ordered from the most expensive to the cheapest.
enum EdgeEffect {
  /// One pass of the edge blur shader. Needs Impeller.
  shaderBlur,

  /// The older blur cut into 24 slices, one blur pass each. Nothing picks it
  /// on its own.
  sliceBlur,

  /// No blur. The canvas colour fades over the edge.
  fade,

  /// Nothing at all. Rows meet the bars with a hard edge.
  none;

  bool get blurs => this == shaderBlur || this == sliceBlur;
  bool get fades => this != none;
}

/// The edge effect a device gets.
///
/// Anything that can run the shader gets the shader blur, iOS and Android
/// alike. A phone Android itself calls low on memory gets nothing. Anything
/// without Impeller (web, older Android) gets the fade.
EdgeEffect autoEdgeEffect({
  required TargetPlatform platform,
  required bool shaderSupported,
  required bool isLowRamDevice,
}) {
  if (platform == TargetPlatform.android && isLowRamDevice) {
    return EdgeEffect.none;
  }
  return shaderSupported ? EdgeEffect.shaderBlur : EdgeEffect.fade;
}

/// The effect every screen draws. Set once at startup.
final ValueNotifier<EdgeEffect> appEdgeEffect = ValueNotifier(EdgeEffect.fade);

/// The compiled edge blur shader, or null until [loadEdgeBlurShader] has
/// loaded it.
ui.FragmentProgram? edgeBlurProgram;

/// Loads `shaders/edge_blur.frag` once at startup. False when the engine
/// cannot run a shader as a filter (no Impeller) or the load fails, and then
/// nothing may pick [EdgeEffect.shaderBlur] on its own.
Future<bool> loadEdgeBlurShader() async {
  if (!ui.ImageFilter.isShaderFilterSupported) return false;
  try {
    edgeBlurProgram = await ui.FragmentProgram.fromAsset(
      'shaders/edge_blur.frag',
    );
    return true;
  } on Object {
    return false;
  }
}
