import 'dart:convert';
import 'dart:io';

import 'package:critalarm/features/incidents/domain/setup_sample.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:flutter_test/flutter_test.dart';

/// The English strings, looked up by their dotted key the way the app does.
String _english(String key) {
  Object? node = jsonDecode(
    File('assets/translations/en.json').readAsStringSync(),
  );
  for (final part in key.split('.')) {
    node = (node! as Map<String, dynamic>)[part];
  }
  return node! as String;
}

void main() {
  group('setupSampleFor', () {
    const body = 'This is what a real one looks like.';

    test('the four answers with a sample give their text', () {
      const expected = {
        SetupUse.servers: 'Replication lag 14 min',
        SetupUse.homelab: 'Nextcloud is down',
        SetupUse.jobs: 'Nightly backup missed its check-in',
        SetupUse.home: 'Freezer is above -10 C',
      };
      for (final MapEntry(key: use, value: title) in expected.entries) {
        expect(
          setupSampleFor(
            kind: SetupTestKind.serverSent,
            use: use,
            text: _english,
          ),
          (title: title, body: body),
          reason: use.name,
        );
      }
    });

    test('something else and no answer leave the server text', () {
      for (final use in [SetupUse.other, null]) {
        expect(
          setupSampleFor(
            kind: SetupTestKind.serverSent,
            use: use,
            text: _english,
          ),
          isNull,
          reason: '$use',
        );
      }
    });

    test('only the test the server sent gets a sample', () {
      for (final kind in [SetupTestKind.phoneOnly, SetupTestKind.none]) {
        for (final use in SetupUse.values) {
          expect(
            setupSampleFor(kind: kind, use: use, text: _english),
            isNull,
            reason: '${kind.name} ${use.name}',
          );
        }
      }
    });

    test('the texts come from the lookup and nothing is asked for none', () {
      final asked = <String>[];
      setupSampleFor(
        kind: SetupTestKind.serverSent,
        use: SetupUse.homelab,
        text: (key) {
          asked.add(key);
          return '<$key>';
        },
      );
      expect(asked, ['setup_use.sample.homelab', 'setup_use.sample_body']);

      asked.clear();
      setupSampleFor(
        kind: SetupTestKind.none,
        use: SetupUse.homelab,
        text: (key) {
          asked.add(key);
          return key;
        },
      );
      expect(asked, isEmpty);
    });
  });
}
