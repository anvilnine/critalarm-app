import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every way a link can open the Android app is an intent filter in a
/// manifest. A `critalarm://` filter would let any app or web page hand the
/// app a connect link that skips the verified https host.
void main() {
  final manifests = Directory('android/app/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('AndroidManifest.xml'))
      .toList();

  final scheme = RegExp(r'android:scheme\s*=\s*"([^"]*)"');

  test('the manifests are where the test looks', () {
    expect(
      manifests.map((file) => file.path),
      contains('android/app/src/main/AndroidManifest.xml'),
    );
  });

  test('no manifest has a critalarm:// filter, and https is the only '
      'scheme a link can arrive on', () {
    for (final manifest in manifests) {
      final schemes = scheme
          .allMatches(manifest.readAsStringSync())
          .map((match) => match.group(1))
          .toSet();
      expect(schemes, isNot(contains('critalarm')), reason: manifest.path);
      expect(schemes.difference({'https'}), isEmpty, reason: manifest.path);
    }
  });

  test('the one https filter is the verified critalarm.app host', () {
    final main = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(scheme.allMatches(main).length, 1);
    expect(main, contains('<intent-filter android:autoVerify="true">'));
    expect(main, contains('<data android:host="critalarm.app"/>'));
  });
}
