import 'dart:async';

import 'package:critalarm/core/sound/sound_recorder.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRecorder implements SoundRecorder {
  bool permission = true;
  int permissionAsks = 0;
  String? startPath = '/tmp/recording_1.m4a';
  int starts = 0;
  int stops = 0;
  int cancels = 0;
  int settingsOpened = 0;
  int size = 4000;
  final List<String> deleted = [];
  final levelsCtrl = StreamController<double>.broadcast(sync: true);
  final interruptedCtrl = StreamController<void>.broadcast(sync: true);

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return permission;
  }

  @override
  Future<String?> start() async {
    starts++;
    return startPath;
  }

  @override
  Stream<double> get levels => levelsCtrl.stream;

  @override
  Stream<void> get interrupted => interruptedCtrl.stream;

  @override
  Future<String?> stop() async {
    stops++;
    return startPath;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (startPath != null) deleted.add(startPath!);
  }

  @override
  Future<int> sizeOf(String path) async => size;

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> dispose() async {}
}

class _Clock {
  DateTime now = DateTime(2026, 9, 22, 14, 32);
  void advance(Duration d) => now = now.add(d);
}

void main() {
  late _FakeRecorder recorder;
  late _Clock clock;
  late bool ringing;
  late int previewStops;
  late RecorderCubit cubit;

  const max = Duration(milliseconds: 29500);

  RecorderCubit build() => RecorderCubit(
    recorder,
    maxDuration: max,
    isRinging: () async => ringing,
    stopPreview: () async => previewStops++,
    now: () => clock.now,
  );

  /// One amplitude sample, [ms] after the last.
  void level(double db, {int ms = 70}) {
    clock.advance(Duration(milliseconds: ms));
    recorder.levelsCtrl.add(db);
  }

  /// Quiet samples until [elapsed] from the start.
  void runTo(Duration elapsed) {
    while (cubit.state.elapsed + const Duration(milliseconds: 70) <= elapsed &&
        cubit.state.status == RecorderStatus.recording) {
      level(-30);
    }
  }

  setUp(() {
    recorder = _FakeRecorder();
    clock = _Clock();
    ringing = false;
    previewStops = 0;
    cubit = build();
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test('starts ready with a calm face and the max length', () {
    expect(cubit.state.status, RecorderStatus.ready);
    expect(cubit.state.face, FaceState.calm);
    expect(cubit.state.maxDuration, max);
    expect(recorder.permissionAsks, 0);
  });

  test('asks for the microphone on the first tap, not before', () async {
    await cubit.toggle();
    expect(recorder.permissionAsks, 1);
    expect(cubit.state.status, RecorderStatus.recording);
    expect(cubit.state.face, FaceState.interested);
  });

  test('stops any preview before recording starts', () async {
    await cubit.toggle();
    expect(previewStops, 1);
    expect(recorder.starts, 1);
  });

  test('denied shows the sad face and never starts', () async {
    recorder.permission = false;
    await cubit.toggle();
    expect(cubit.state.status, RecorderStatus.denied);
    expect(cubit.state.face, FaceState.sad);
    expect(recorder.starts, 0);
    await cubit.openSettings();
    expect(recorder.settingsOpened, 1);
  });

  test('a tap after denied asks again, in case Settings changed it', () async {
    recorder.permission = false;
    await cubit.toggle();
    recorder.permission = true;
    await cubit.toggle();
    expect(recorder.permissionAsks, 2);
    expect(cubit.state.status, RecorderStatus.recording);
  });

  test('does nothing while an alarm rings', () async {
    ringing = true;
    await cubit.toggle();
    expect(cubit.state.status, RecorderStatus.ready);
    expect(recorder.starts, 0);
    expect(recorder.permissionAsks, 0);
  });

  test('a failed start goes back to ready', () async {
    recorder.startPath = null;
    await cubit.toggle();
    expect(cubit.state.status, RecorderStatus.ready);
  });

  test('levels move the timer and fill the bars', () async {
    await cubit.toggle();
    level(-20);
    level(-10);
    expect(cubit.state.elapsed, const Duration(milliseconds: 140));
    expect(cubit.state.levels, hasLength(2));
    expect(cubit.state.levels.last, greaterThan(cubit.state.levels.first));
    expect(cubit.state.progress, closeTo(140 / 29500, 1e-9));
  });

  test('keeps only the most recent bars', () async {
    await cubit.toggle();
    for (var i = 0; i < RecorderState.barCount + 10; i++) {
      level(-20);
    }
    expect(cubit.state.levels, hasLength(RecorderState.barCount));
  });

  test(
    'a loud spike held 300 ms turns the face surprised, then back',
    () async {
      await cubit.toggle();
      level(-3);
      level(-3);
      level(-3);
      expect(cubit.state.face, FaceState.interested, reason: 'only 210 ms');
      level(-3);
      level(-3);
      expect(cubit.state.face, FaceState.surprised);
      level(-30);
      expect(cubit.state.face, FaceState.surprised, reason: 'lingers');
      level(-30, ms: 600);
      expect(cubit.state.face, FaceState.interested);
    },
  );

  test('a short loud blip does not surprise', () async {
    await cubit.toggle();
    level(-3);
    level(-3);
    level(-30);
    level(-3);
    level(-3);
    expect(cubit.state.face, FaceState.interested);
  });

  test('the last 5 seconds turn the face worried', () async {
    await cubit.toggle();
    runTo(const Duration(milliseconds: 24000));
    expect(cubit.state.face, FaceState.interested);
    expect(cubit.state.isLastSeconds, isFalse);
    runTo(const Duration(milliseconds: 24600));
    expect(cubit.state.isLastSeconds, isTrue);
    expect(cubit.state.face, FaceState.worried);
  });

  test('the timer blinks only in the last 5 seconds', () async {
    await cubit.toggle();
    // Early on the timer shows at every point of the second.
    for (var ms = 0; ms < 2000; ms += 70) {
      final s = cubit.state.copyWith(elapsed: Duration(milliseconds: ms));
      expect(s.showsTimer(reduceMotion: false), isTrue);
    }
    final start = max - const Duration(seconds: 5);
    RecorderState at(int ms) =>
        cubit.state.copyWith(elapsed: start + Duration(milliseconds: ms));
    expect(at(100).showsTimer(reduceMotion: false), isTrue);
    expect(at(600).showsTimer(reduceMotion: false), isFalse);
    expect(at(1100).showsTimer(reduceMotion: false), isTrue);
    expect(at(1600).showsTimer(reduceMotion: false), isFalse);
    expect(at(600).showsTimer(reduceMotion: true), isTrue);
  });

  test('stops by itself at the max and hands the file on', () async {
    await cubit.toggle();
    runTo(max + const Duration(seconds: 1));
    await pumpEventQueue();
    expect(recorder.stops, 1);
    expect(cubit.state.status, RecorderStatus.stopped);
    expect(cubit.state.face, FaceState.success);
    expect(cubit.state.elapsed, max);
    expect(cubit.state.recorded?.path, '/tmp/recording_1.m4a');
  });

  test('stop hands the file on with a name and a size', () async {
    await cubit.toggle();
    runTo(const Duration(seconds: 3));
    await cubit.toggle();
    final file = cubit.state.recorded!;
    expect(file.path, '/tmp/recording_1.m4a');
    expect(file.name, '2026-09-22 14.32.m4a');
    expect(file.sizeBytes, 4000);
    expect(recorder.deleted, isEmpty);
    await cubit.close();
    expect(recorder.deleted, isEmpty, reason: 'the cropper owns it now');
  });

  test('stop under a second throws the clip away and goes back', () async {
    await cubit.toggle();
    runTo(const Duration(milliseconds: 500));
    await cubit.toggle();
    expect(cubit.state.status, RecorderStatus.ready);
    expect(cubit.state.recorded, isNull);
    expect(recorder.deleted, ['/tmp/recording_1.m4a']);
  });

  test(
    'an interruption keeps the partial clip and opens the cropper',
    () async {
      await cubit.toggle();
      runTo(const Duration(seconds: 4));
      recorder.interruptedCtrl.add(null);
      await pumpEventQueue();
      expect(recorder.stops, 1);
      expect(cubit.state.status, RecorderStatus.stopped);
      expect(cubit.state.recorded?.path, '/tmp/recording_1.m4a');
    },
  );

  test('an interruption with nothing usable says so', () async {
    await cubit.toggle();
    runTo(const Duration(milliseconds: 300));
    await cubit.interrupt();
    expect(cubit.state.status, RecorderStatus.interrupted);
    expect(cubit.state.face, FaceState.confused);
    expect(cubit.state.recorded, isNull);
    expect(recorder.deleted, ['/tmp/recording_1.m4a']);
    // And a new tap records again.
    await cubit.toggle();
    expect(cubit.state.status, RecorderStatus.recording);
    expect(cubit.state.elapsed, Duration.zero);
    expect(cubit.state.levels, isEmpty);
  });

  test('interrupt does nothing when not recording', () async {
    await cubit.interrupt();
    expect(cubit.state.status, RecorderStatus.ready);
    expect(recorder.stops, 0);
  });

  test('closing mid-recording throws the clip away', () async {
    await cubit.toggle();
    runTo(const Duration(seconds: 2));
    await cubit.close();
    expect(recorder.cancels, 1);
  });

  test('levels after close are ignored', () async {
    await cubit.toggle();
    await cubit.close();
    expect(() => level(-3), returnsNormally);
  });
}
