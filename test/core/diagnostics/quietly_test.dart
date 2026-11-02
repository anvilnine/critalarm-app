import 'package:critalarm/core/diagnostics/quietly.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String?> lines;
  late DebugPrintCallback original;

  setUp(() {
    lines = <String?>[];
    original = debugPrint;
    debugPrint = (message, {wrapWidth}) => lines.add(message);
  });

  tearDown(() => debugPrint = original);

  group('quietly', () {
    test('runs the action and prints nothing when it succeeds', () async {
      var ran = false;
      await quietly('t.ok', () async => ran = true);
      expect(ran, isTrue);
      expect(lines, isEmpty);
    });

    test(
      'swallows an async failure and prints the tag and the error',
      () async {
        await quietly('t.async', () async => throw StateError('disk full'));
        expect(lines, hasLength(1));
        expect(lines.single, contains('t.async'));
        expect(lines.single, contains('disk full'));
      },
    );

    test('swallows a failure thrown before the first await', () async {
      await quietly('t.sync', () => throw const FormatException('bad'));
      expect(lines.single, contains('t.sync'));
      expect(lines.single, contains('bad'));
    });

    test('swallows an Error and a thrown non-Exception', () async {
      await quietly('t.error', () => throw ArgumentError('nope'));
      // A caller can throw anything, and the helper still has to hold.
      // ignore: only_throw_errors
      await quietly('t.int', () => throw 42);
      expect(lines, hasLength(2));
      expect(lines.last, contains('42'));
    });

    test('accepts a synchronous action', () async {
      var ran = false;
      await quietly('t.plain', () => ran = true);
      expect(ran, isTrue);
      expect(lines, isEmpty);
    });
  });

  group('noteQuiet', () {
    test('prints the tag and the error', () {
      noteQuiet('t.note', Exception('boom'));
      expect(lines.single, contains('t.note'));
      expect(lines.single, contains('boom'));
    });

    test('is usable as a catchError handler', () async {
      await Future<void>.error(
        StateError('late'),
      ).catchError((Object e) => noteQuiet('t.late', e));
      expect(lines.single, contains('late'));
    });
  });
}
