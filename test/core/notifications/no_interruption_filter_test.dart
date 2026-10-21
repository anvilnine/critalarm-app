import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Crit Alarm never turns Do Not Disturb on or off. The Android alarm channel
/// may bypass it (`setBypassDnd`), and that is all. Changing the phone's
/// interruption filter would silence a person's own alarms after ours, so no
/// Kotlin, Java, Swift or Dart file may call `setInterruptionFilter`.

const _sourceExtensions = {'.kt', '.java', '.swift', '.dart'};

/// Folders that hold code we write. Generated and vendored output below them
/// is skipped by [_skippedSegments].
const _sourceRoots = ['lib', 'android', 'ios'];

const _skippedSegments = {
  'build',
  '.gradle',
  '.dart_tool',
  'Pods',
  'ephemeral',
  '.symlinks',
};

final _call = RegExp(r'\bsetInterruptionFilter\b');

/// Every `path:line` under [root] where a source file names
/// `setInterruptionFilter`.
List<String> findInterruptionFilterCalls(Directory root) {
  final hits = <String>[];
  for (final name in _sourceRoots) {
    final dir = Directory('${root.path}/$name');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = entity.path.substring(root.path.length + 1);
      final segments = relative.split('/');
      if (segments.any(_skippedSegments.contains)) continue;
      final dot = entity.path.lastIndexOf('.');
      if (dot < 0 || !_sourceExtensions.contains(entity.path.substring(dot))) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_call.hasMatch(lines[i])) hits.add('$relative:${i + 1}');
      }
    }
  }
  return hits;
}

void main() {
  test('no source file calls setInterruptionFilter', () {
    expect(findInterruptionFilterCalls(Directory.current), isEmpty);
  });

  test('the scan sees a call added to a Kotlin, Swift or Dart file', () {
    final scratch = Directory.systemTemp.createTempSync('dnd_scan_');
    addTearDown(() => scratch.deleteSync(recursive: true));

    const files = {
      'android/app/src/main/kotlin/Scratch.kt':
          'fun f(m: NotificationManager) {\n'
          '  m.setInterruptionFilter(FILTER_NONE)\n'
          '}\n',
      'ios/Runner/Scratch.swift':
          'let x = 1\nmanager.setInterruptionFilter(1)\n',
      'lib/scratch.dart': "final x = 'setInterruptionFilter';\n",
      'android/app/build/Ignored.kt': 'm.setInterruptionFilter(1)\n',
    };
    for (final entry in files.entries) {
      File('${scratch.path}/${entry.key}')
        ..createSync(recursive: true)
        ..writeAsStringSync(entry.value);
    }

    expect(
      findInterruptionFilterCalls(scratch),
      unorderedEquals([
        'android/app/src/main/kotlin/Scratch.kt:2',
        'ios/Runner/Scratch.swift:2',
        'lib/scratch.dart:1',
      ]),
    );
  });
}
