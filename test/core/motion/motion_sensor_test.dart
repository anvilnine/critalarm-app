import 'dart:async';

import 'package:critalarm/core/motion/motion_sensor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The native side, stood in for: it records the calls of the method
/// channel and hands the event channel a sink.
final class _FakeNative {
  _FakeNative({this.startError});

  final PlatformException? startError;
  final calls = <String>[];
  MockStreamHandlerEventSink? sink;
  int streamListens = 0;
  int streamCancels = 0;

  static const _methods = MethodChannel(MotionSensorHost.methodsName);
  static const _events = EventChannel(MotionSensorHost.readingsName);

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void attach() {
    _messenger
      ..setMockMethodCallHandler(_methods, (call) async {
        calls.add(call.method);
        if (call.method == 'start' && startError != null) throw startError!;
        return null;
      })
      ..setMockStreamHandler(
        _events,
        MockStreamHandler.inline(
          onListen: (_, events) {
            streamListens++;
            sink = events;
          },
          onCancel: (_) {
            streamCancels++;
            sink = null;
          },
        ),
      );
  }

  void detach() {
    _messenger
      ..setMockMethodCallHandler(_methods, null)
      ..setMockStreamHandler(_events, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MotionReading.fromEvent', () {
    test('reads x, y, z and the time in seconds', () {
      final reading = MotionReading.fromEvent(<Object?>[0.5, -0.25, -1, 12.5])!;
      expect(reading.x, 0.5);
      expect(reading.y, -0.25);
      expect(reading.z, -1);
      expect(reading.at, const Duration(milliseconds: 12500));
    });

    test('anything else is no reading', () {
      expect(MotionReading.fromEvent(null), isNull);
      expect(MotionReading.fromEvent('1,2,3,4'), isNull);
      expect(MotionReading.fromEvent(<Object?>[1.0, 2.0, 3.0]), isNull);
      expect(MotionReading.fromEvent(<Object?>[1.0, 'x', 3.0, 4.0]), isNull);
      expect(MotionReading.fromEvent(<Object?>[1.0, null, 3.0, 4.0]), isNull);
      expect(
        MotionReading.fromEvent(<Object?>[double.nan, 0.0, 0.0, 1.0]),
        isNull,
      );
      expect(
        MotionReading.fromEvent(<Object?>[0.0, 0.0, 0.0, double.infinity]),
        isNull,
      );
    });
  });

  group('MotionSensorHost', () {
    test('uses channels named in the app style', () {
      expect(MotionSensorHost.methodsName, 'app.critalarm/motion');
      expect(MotionSensorHost.readingsName, 'app.critalarm/motion/readings');
    });

    test('nothing is asked of the native side until it is listened to', () {
      final native = _FakeNative()..attach();
      addTearDown(native.detach);
      MotionSensorHost().readings();
      expect(native.calls, isEmpty);
      expect(native.streamListens, 0);
    });

    test('listening starts the sensor and readings come through', () async {
      final native = _FakeNative()..attach();
      addTearDown(native.detach);
      final got = <MotionReading>[];
      final subscription = MotionSensorHost().readings().listen(got.add);
      await pumpEventQueue();
      expect(native.calls, ['start']);
      expect(native.streamListens, 1);
      native.sink!
        ..success(<Object?>[0.0, 0.0, -1.0, 1.0])
        ..success('not a reading')
        ..success(<Object?>[2.0, 0.0, -1.0, 1.02]);
      await pumpEventQueue();
      expect(got.map((reading) => reading.x), [0.0, 2.0]);
      expect(got.last.at, const Duration(milliseconds: 1020));
      await subscription.cancel();
    });

    test('cancelling stops the sensor and lets go of the stream', () async {
      final native = _FakeNative()..attach();
      addTearDown(native.detach);
      final subscription = MotionSensorHost().readings().listen((_) {});
      await pumpEventQueue();
      await subscription.cancel();
      await pumpEventQueue();
      expect(native.calls, ['start', 'stop']);
      expect(native.streamCancels, 1);
      expect(native.sink, isNull);
    });

    test('cancelled before the start answered, it still stops', () async {
      final native = _FakeNative()..attach();
      addTearDown(native.detach);
      final subscription = MotionSensorHost().readings().listen((_) {});
      // No turn of the event loop in between: the start is still on its
      // way.
      await subscription.cancel();
      await pumpEventQueue();
      expect(native.calls, ['start', 'stop']);
      // The readings were never asked for.
      expect(native.streamListens, 0);
    });

    test('every listen is its own start and its own stop', () async {
      final native = _FakeNative()..attach();
      addTearDown(native.detach);
      final host = MotionSensorHost();
      for (var i = 0; i < 3; i++) {
        final subscription = host.readings().listen((_) {});
        await pumpEventQueue();
        await subscription.cancel();
        await pumpEventQueue();
      }
      expect(native.calls, ['start', 'stop', 'start', 'stop', 'start', 'stop']);
      expect(native.streamListens, 3);
      expect(native.streamCancels, 3);
    });

    test('a phone with no accelerometer gives one plain error', () async {
      final native = _FakeNative(
        startError: PlatformException(code: MotionSensorHost.noAccelerometer),
      )..attach();
      addTearDown(native.detach);
      final errors = <Object>[];
      final subscription = MotionSensorHost().readings().listen(
        (_) {},
        onError: errors.add,
      );
      await pumpEventQueue();
      expect(errors, hasLength(1));
      expect(
        errors.single,
        isA<MotionSensorUnavailable>().having(
          (error) => error.reason,
          'reason',
          'no_accelerometer',
        ),
      );
      // The readings were never asked for.
      expect(native.streamListens, 0);
      await subscription.cancel();
      await pumpEventQueue();
      expect(native.calls, ['start', 'stop']);
    });

    test('with no native side at all it says so, and never throws', () async {
      final errors = <Object>[];
      final subscription = MotionSensorHost().readings().listen(
        (_) {},
        onError: errors.add,
      );
      await pumpEventQueue();
      expect(errors.single, isA<MotionSensorUnavailable>());
      await subscription.cancel();
    });

    test('an error from the stream is passed on', () async {
      final native = _FakeNative()..attach();
      addTearDown(native.detach);
      final errors = <Object>[];
      final subscription = MotionSensorHost().readings().listen(
        (_) {},
        onError: errors.add,
      );
      await pumpEventQueue();
      native.sink!.error(code: 'sensor_failed');
      await pumpEventQueue();
      expect(errors, hasLength(1));
      await subscription.cancel();
    });

    test('a stream the native side ends is ended here too', () async {
      final native = _FakeNative()..attach();
      addTearDown(native.detach);
      final done = Completer<void>();
      MotionSensorHost().readings().listen((_) {}, onDone: done.complete);
      await pumpEventQueue();
      native.sink!.endOfStream();
      await done.future.timeout(const Duration(seconds: 1));
    });
  });
}
