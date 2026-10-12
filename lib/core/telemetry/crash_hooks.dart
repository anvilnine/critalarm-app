import 'dart:async';

import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter/foundation.dart';

/// Sends the errors nothing caught to crash reporting, through [gate].
///
/// Two doors, because Flutter has two. `FlutterError.onError` gets what the
/// framework caught for the app (a build, a layout, a gesture callback) and
/// the app keeps running, so those are not fatal. `PlatformDispatcher.onError`
/// gets what nothing caught at all.
///
/// Whatever handler was there before still runs, so the console prints what
/// it always printed. The gate drops every report while the user has crash
/// reporting off.
void installCrashHooks(TelemetryGate gate) {
  final platform = PlatformDispatcher.instance;

  final earlierFlutter = FlutterError.onError;
  FlutterError.onError = (details) {
    earlierFlutter?.call(details);
    // Silent errors are the ones the framework itself says not to report,
    // an image that failed to load for one.
    if (details.silent) return;
    unawaited(
      gate.recordError(
        details.exception,
        details.stack,
        reason: details.library,
      ),
    );
  };

  final earlierPlatform = platform.onError;
  platform.onError = (error, stack) {
    unawaited(gate.recordError(error, stack, fatal: true));
    // False leaves the error unhandled, so the engine still prints it.
    return earlierPlatform?.call(error, stack) ?? false;
  };
}
