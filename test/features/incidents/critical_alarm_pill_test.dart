import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "2 alarms" pill under the topic name. Pumps the real screen so the pill
/// is read off the same code path the device uses.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  Future<void> pumpAlarmScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const CriticalAlarmScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows a 2 alarms pill with two open incidents', (tester) async {
    final server = getIt<MockServer>()..reset();
    final now = DateTime.now();
    server.seedState(
      incidents: [
        Incident(
          id: 'inc_older',
          topic: 'nas-backup',
          openedAt: now.subtract(const Duration(minutes: 5)),
        ),
        Incident(id: 'inc_newer', topic: 'prod-db', openedAt: now),
      ],
    );

    await pumpAlarmScreen(tester);

    expect(find.text('2 alarms'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows no pill with a single open incident', (tester) async {
    getIt<MockServer>()
      ..reset()
      ..seedState(
        incidents: [
          Incident(
            id: 'inc_only',
            topic: 'prod-db',
            openedAt: DateTime.now(),
          ),
        ],
      );

    await pumpAlarmScreen(tester);

    expect(find.text('2 alarms'), findsNothing);
    expect(find.text('1 alarm'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
