import 'dart:io';

import 'package:critalarm/design/faces/faces.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every reminder face names a real face state', () {
    for (final face in LocalReminderFace.values) {
      expect(
        FaceState.values.asNameMap().containsKey(face.name),
        isTrue,
        reason: face.name,
      );
    }
  });

  test('every reminder face has an image on disk', () {
    for (final face in LocalReminderFace.values) {
      expect(File(face.assetPath).existsSync(), isTrue, reason: face.name);
    }
  });

  test('pubspec bundles the folder', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/reminder_faces/'),
    );
  });
}
