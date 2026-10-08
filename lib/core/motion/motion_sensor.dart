import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart';

/// One reading of the accelerometer.
///
/// [x], [y] and [z] are in g, gravity included: a phone at rest reads a
/// length of about 1, whichever way it lies. Both platforms use the iPhone's
/// signs (flat on a desk, screen up, reads z = -1). [at] is the sensor's own
/// clock, which starts at an arbitrary point: only the difference between
/// two readings means anything.
@immutable
final class MotionReading {
  const MotionReading({
    required this.x,
    required this.y,
    required this.z,
    required this.at,
  });

  final double x;
  final double y;
  final double z;
  final Duration at;

  /// A reading from what the native side sends: a list of x, y, z and the
  /// time in seconds. Null for anything else.
  static MotionReading? fromEvent(Object? event) {
    if (event is! List || event.length < 4) return null;
    final values = <double>[];
    for (final value in event.take(4)) {
      if (value is! num || !value.isFinite) return null;
      values.add(value.toDouble());
    }
    return MotionReading(
      x: values[0],
      y: values[1],
      z: values[2],
      at: Duration(
        microseconds: (values[3] * Duration.microsecondsPerSecond).round(),
      ),
    );
  }

  @override
  String toString() => 'MotionReading($x, $y, $z at $at)';
}

/// The stream of [MotionSensor.readings] could not start: the phone has no
/// accelerometer, or this platform has no native side for it.
final class MotionSensorUnavailable implements Exception {
  const MotionSensorUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'MotionSensorUnavailable($reason)';
}

/// The phone's accelerometer, and nothing else of its motion hardware.
///
/// It needs no permission and no usage string on either platform. It is
/// here, behind an interface, so that what is done with the readings is a
/// pure function of a stream and is tested with a made-up one.
// One method today. An interface so a test hands in its own stream.
// ignore: one_member_abstracts
abstract interface class MotionSensor {
  /// Readings for as long as the stream is listened to.
  ///
  /// Listening turns the sensor on and cancelling turns it off: there is no
  /// other switch, so a sensor left on is a subscription left open. A phone
  /// with no accelerometer gives one [MotionSensorUnavailable] error and no
  /// readings.
  Stream<MotionReading> readings();
}

/// The native accelerometer, over a channel of our own.
///
/// `MotionSensor.swift` and `MotionSensorChannel.kt` hold the other half.
/// The method channel has `start` and `stop`, and the event channel carries
/// the readings. The native side runs the sensor only while the app is in
/// front: it stops by itself when the app leaves, whatever Dart does, and it
/// does not start again until Dart asks.
///
/// With no handler on the channel (web, a test, a desktop build) the start
/// fails and the stream gives [MotionSensorUnavailable].
final class MotionSensorHost implements MotionSensor {
  MotionSensorHost({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(methodsName),
      _events = events ?? const EventChannel(readingsName);

  static const methodsName = 'app.critalarm/motion';
  static const readingsName = 'app.critalarm/motion/readings';

  /// The error code of a `start` on a phone with no accelerometer.
  static const noAccelerometer = 'no_accelerometer';

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Stream<MotionReading> readings() {
    late final StreamController<MotionReading> controller;
    // Cancelled in the controller's onCancel.
    // ignore: cancel_subscriptions
    StreamSubscription<Object?>? events;
    var isCancelled = false;

    Future<void> start() async {
      try {
        await _methods.invokeMethod<Object?>('start');
      } on MissingPluginException {
        if (!isCancelled) {
          controller.addError(const MotionSensorUnavailable('no_native_side'));
        }
        return;
      } on PlatformException catch (error) {
        if (!isCancelled) {
          controller.addError(MotionSensorUnavailable(error.code));
        }
        return;
      }
      // Cancelled while the start was on its way. The stop was sent after
      // it, on the same channel, so the native side is already off.
      if (isCancelled) return;
      events = _events.receiveBroadcastStream().listen(
        (event) {
          final reading = MotionReading.fromEvent(event);
          if (reading != null && !isCancelled) controller.add(reading);
        },
        onError: (Object error) {
          if (!isCancelled) controller.addError(error);
        },
        onDone: () {
          if (!isCancelled) unawaited(controller.close());
        },
      );
    }

    controller = StreamController<MotionReading>(
      onListen: () => unawaited(start()),
      onCancel: () async {
        isCancelled = true;
        final listening = events;
        events = null;
        // The stop goes first, so nothing in front of it can hold it up.
        final stopped = _stop();
        try {
          await listening?.cancel();
        } on MissingPluginException {
          // No native side to tell.
        } on PlatformException {
          // The native side had already let go of the stream.
        }
        await stopped;
      },
    );
    return controller.stream;
  }

  Future<void> _stop() async {
    try {
      await _methods.invokeMethod<Object?>('stop');
    } on MissingPluginException {
      // No native side, so nothing is running.
    } on PlatformException {
      // The native side stops by itself when the app leaves the front.
    }
  }
}
