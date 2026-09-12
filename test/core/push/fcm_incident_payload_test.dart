import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/push/fcm_incident_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/android_delivery_cases.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final vector in fixture['payloads'] as List<dynamic>) {
    final testCase = vector as Map<String, dynamic>;
    test(testCase['name'] as String, () {
      final data = (testCase['data'] as Map<String, dynamic>)
          .cast<String, String>();
      final parsed = FcmIncidentPayload.tryParse(data);
      expect(parsed != null, testCase['valid']);
    });
  }
}
