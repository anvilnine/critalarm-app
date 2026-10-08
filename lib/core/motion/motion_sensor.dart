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
    // Read in place: this runs fifty times a second.
    final x = event[0];
    final y = event[1];
    final z = event[2];
    final seconds = event[3];
    if (x is! num || y is! num || z is! num || seconds is! num) return null;
    if (!x.isFinite || !y.isFinite || !z.isFinite || !seconds.isFinite) {
      return null;
    }
    return MotionReading(
      x: x.toDouble(),
      y: y.toDouble(),
      z: z.toDouble(),
      at: Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round(),
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

/// The sensor was asked for while the app was not the one in front, and
/// did not start. Nothing is wrong with it: ask again when the app is back.
final class MotionSensorNotInFront implements Exception {
  const MotionSensorNotInFront();

  @override
  String toString() => 'MotionSensorNotInFront';
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
  /// readings. A start refused because the app is not in front gives one
  /// [MotionSensorNotInFront] error and no readings.
  ///
  /// [onStarted] is called once, when the sensor has said it is running.
  Stream<MotionReading> readings({void Function()? onStarted});
}

/// The native accelerometer, over a channel of our own.
///
/// `MotionSensor.swift` and `MotionSensorChannel.kt` hold the other half.
/// The method channel has `start` and `stop`, and the event channel carries
/// the readings.
///
/// Every stream has a number of its own, and its `start`, its `stop` and
/// its event channel `listen` and `cancel` all carry it. The native side
/// lets the newest start own the sensor and ignores a stop or a cancel
/// with any other number. So when one listener goes as the next arrives
/// (start new, stop old, cancel old, listen new), the old one's stop
/// cannot turn off what the new one started.
///
/// The native side runs the sensor only while the app is in
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
  int _runs = 0;

  @override
  Stream<MotionReading> readings({void Function()? onStarted}) {
    final run = ++_runs;
    late final StreamController<MotionReading> controller;
    // Cancelled in the controller's onCancel.
    // ignore: cancel_subscriptions
    StreamSubscription<Object?>? events;
    var isCancelled = false;

    Future<void> start() async {
      final Object? answer;
      try {
        answer = await _methods.invokeMethod<Object?>('start', {'run': run});
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
      // False is the native side saying the app is not in front, so it
      // started nothing.
      if (answer == false) {
        controller.addError(const MotionSensorNotInFront());
        return;
      }
      onStarted?.call();
      events = _events
          .receiveBroadcastStream(run)
          .listen(
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
        final stopped = _stop(run);
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

  Future<void> _stop(int run) async {
    try {
      await _methods.invokeMethod<Object?>('stop', {'run': run});
    } on MissingPluginException {
      // No native side, so nothing is running.
    } on PlatformException {
      // The native side stops by itself when the app leaves the front.
    }
  }
}
