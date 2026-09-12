import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/incidents/incident_action_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/android_delivery_cases.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final vector in fixture['actions'] as List<dynamic>) {
    final testCase = vector as Map<String, dynamic>;
    test(testCase['name'] as String, () {
      final route = IncidentActionRoute.fromTrigger(
        testCase['trigger'] as String,
        testCase['incident_id'] as String,
      );
      expect(route?.action.wireValue, testCase['action']);
      expect(route?.path, testCase['path']);
    });
  }
}
