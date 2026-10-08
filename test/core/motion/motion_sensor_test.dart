import 'dart:async';

import 'package:critalarm/core/motion/motion_sensor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The native side, stood in for, with the rule the real one has: the
/// newest start owns the sensor, and a stop or a cancel with any other
/// number is ignored.
final class _FakeNative {
  _FakeNative({this.startError, this.isInFront = true});

  final PlatformException? startError;

  /// What `start` answers: false is "the app is not in front".
  bool isInFront;

  /// The method names, in the order they arrived.
  final calls = <String>[];

  /// Every message of both channels with its number, in order.
  final log = <String>[];
  MockStreamHandlerEventSink? sink;
  int streamListens = 0;
  int streamCancels = 0;
  bool isOn = false;
  int? _owner;
  Object? _listener;

  static const _methods = MethodChannel(MotionSensorHost.methodsName);
  static const _events = EventChannel(MotionSensorHost.readingsName);

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void attach() {
    _messenger
      ..setMockMethodCallHandler(_methods, (call) async {
        final run = (call.arguments as Map?)?['run'] as int?;
        calls.add(call.method);
        log.add('${call.method} $run');
        if (call.method == 'start') {
          if (startError != null) throw startError!;
          if (!isInFront) return false;
          isOn = true;
          _owner = run;
          return true;
        }
        if (call.method == 'stop' && run == _owner) isOn = false;
        return null;
      })
      ..setMockStreamHandler(
        _events,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            streamListens++;
            log.add('listen $arguments');
            sink = events;
            _listener = arguments;
          },
          onCancel: (arguments) {
            streamCancels++;
            log.add('cancel $arguments');
            if (arguments == _listener) sink = null;
            if (arguments == _owner) isOn = false;
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

    test(
      'one listener going as the next arrives leaves the sensor on',
      () async {
        // A widget that remounts inside one frame: the new one listens and
        // the old one cancels with no turn of the event loop between them.
        final native = _FakeNative()..attach();
        addTearDown(native.detach);
        final host = MotionSensorHost();
        final old = <MotionReading>[];
        final first = host.readings().listen(old.add);
        await pumpEventQueue();
        expect(native.log, ['start 1', 'listen 1']);

        final got = <MotionReading>[];
        final second = host.readings().listen(got.add);
        final cancelling = first.cancel();
        await pumpEventQueue();
        await cancelling;

        expect(native.log, [
          'start 1',
          'listen 1',
          'start 2',
          'stop 1',
          'cancel 1',
          'listen 2',
        ]);
        // The old stop and the old cancel did not end the new start.
        expect(native.isOn, isTrue);
        expect(native.sink, isNotNull);
        native.sink!.success(<Object?>[2.0, 0.0, -1.0, 3.0]);
        await pumpEventQueue();
        expect(got, hasLength(1));
        expect(old, isEmpty);

        await second.cancel();
        await pumpEventQueue();
        expect(native.isOn, isFalse);
        expect(native.sink, isNull);
        expect(native.log.sublist(6), ['stop 2', 'cancel 2']);
      },
    );

    test(
      'a start the phone refuses is its own error, not a broken sensor',
      () async {
        final native = _FakeNative(isInFront: false)..attach();
        addTearDown(native.detach);
        final host = MotionSensorHost();
        final errors = <Object>[];
        var started = 0;
        final subscription = host
            .readings(onStarted: () => started++)
            .listen((_) {}, onError: errors.add);
        await pumpEventQueue();
        expect(errors.single, isA<MotionSensorNotInFront>());
        expect(started, 0);
        // The readings were never asked for.
        expect(native.streamListens, 0);
        await subscription.cancel();
        await pumpEventQueue();

        // Asked again once the app is back, it starts.
        native.isInFront = true;
        final again = host
            .readings(onStarted: () => started++)
            .listen((_) {}, onError: errors.add);
        await pumpEventQueue();
        expect(errors, hasLength(1));
        expect(started, 1);
        expect(native.isOn, isTrue);
        expect(native.streamListens, 1);
        await again.cancel();
      },
    );

    test('it says the sensor started once the start is accepted', () async {
      final native = _FakeNative()..attach();
      addTearDown(native.detach);
      var started = 0;
      final subscription = MotionSensorHost()
          .readings(onStarted: () => started++)
          .listen((_) {});
      expect(started, 0);
      await pumpEventQueue();
      expect(started, 1);
      await subscription.cancel();
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
