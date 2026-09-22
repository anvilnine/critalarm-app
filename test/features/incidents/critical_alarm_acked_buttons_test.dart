import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small render checks for A25's "At my desk" button, built straight from
/// [AcknowledgedScreen] with a state the test controls. Going through the
/// real screen and its cubit would also start the after-ack reminders timer,
/// which is a different feature's job to test.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  CriticalAlarmState stateFor(CriticalAlarmStatus status) {
    final now = DateTime.now();
    return CriticalAlarmState(
      status: status,
      incident: Incident(
        id: 'inc_1',
        topic: 'prod-db',
        openedAt: now.subtract(const Duration(minutes: 3)),
        ackedAt: now,
      ),
      topic: 'prod-db',
      isAcknowledged: true,
    );
  }

  Widget buildTestApp(CriticalAlarmStatus status) {
    return BlocProvider<TopicsCubit>.value(
      value: getIt<TopicsCubit>(),
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => AcknowledgedScreen(
            state: stateFor(status),
            colors: context.appColors,
          ),
        ),
      ),
    );
  }

  List<String> buttonLabels(WidgetTester tester) => tester
      .widgetList<AppButton>(find.byType(AppButton))
      .map((button) => button.label)
      .toList();

  group('the acked screen bottom bar', () {
    testWidgets('acked state renders At my desk first', (tester) async {
      await tester.pumpWidget(buildTestApp(CriticalAlarmStatus.acknowledged));
      await tester.pump();

      expect(buttonLabels(tester), [
        'At my desk',
        'Open prod-db',
        'Back to topics',
      ]);
    });

    testWidgets('closed state renders no At my desk', (tester) async {
      await tester.pumpWidget(buildTestApp(CriticalAlarmStatus.closed));
      await tester.pump();

      expect(buttonLabels(tester), ['Back to topics']);
    });
  });
}
