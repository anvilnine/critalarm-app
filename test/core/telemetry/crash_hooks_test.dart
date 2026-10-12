import 'dart:ui';

import 'package:critalarm/core/telemetry/crash_hooks.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Report = ({
  Object error,
  StackTrace? stack,
  bool fatal,
  String? reason,
});

class _RecordingGate extends NoopTelemetryGate {
  final reports = <_Report>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    reports.add((error: error, stack: stack, fatal: fatal, reason: reason));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterExceptionHandler? flutterBefore;
  late ErrorCallback? platformBefore;
  late _RecordingGate gate;

  setUp(() {
    flutterBefore = FlutterError.onError;
    platformBefore = PlatformDispatcher.instance.onError;
    gate = _RecordingGate();
  });

  tearDown(() {
    FlutterError.onError = flutterBefore;
    PlatformDispatcher.instance.onError = platformBefore;
  });

  test('a framework error is reported as not fatal, with its library', () {
    final seen = <FlutterErrorDetails>[];
    FlutterError.onError = seen.add;
    installCrashHooks(gate);

    final error = StateError('x');
    final stack = StackTrace.current;
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'widgets library',
      ),
    );

    expect(gate.reports, hasLength(1));
    expect(gate.reports.single.error, same(error));
    expect(gate.reports.single.stack, same(stack));
    expect(gate.reports.single.fatal, isFalse);
    expect(gate.reports.single.reason, 'widgets library');
    expect(seen, hasLength(1), reason: 'the earlier handler still runs');
  });

  test('a silent framework error is not reported', () {
    FlutterError.onError = (_) {};
    installCrashHooks(gate);

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('x'), silent: true),
    );

    expect(gate.reports, isEmpty);
  });

  test('an error nothing caught is reported as fatal', () {
    PlatformDispatcher.instance.onError = null;
    installCrashHooks(gate);

    final error = StateError('x');
    final stack = StackTrace.current;
    final handled = PlatformDispatcher.instance.onError!(error, stack);

    expect(gate.reports.single.error, same(error));
    expect(gate.reports.single.fatal, isTrue);
    expect(handled, isFalse, reason: 'the engine still prints it');
  });

  test('the earlier platform handler still runs and keeps its answer', () {
    var calls = 0;
    PlatformDispatcher.instance.onError = (_, _) {
      calls++;
      return true;
    };
    installCrashHooks(gate);

    final handled = PlatformDispatcher.instance.onError!(
      StateError('x'),
      StackTrace.current,
    );

    expect(calls, 1);
    expect(handled, isTrue);
    expect(gate.reports, hasLength(1));
  });
}
