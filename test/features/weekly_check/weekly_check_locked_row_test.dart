import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/weekly_check/presentation/widgets/weekly_check_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/access/access_fakes.dart';

void main() {
  testWidgets('the locked weekly check row is the real switch row, drawn off '
      'and badged', (tester) async {
    final access = TestAccess();
    addTearDown(access.dispose);
    await getIt.reset();
    getIt.registerSingleton<FeatureAccess>(access.features);
    addTearDown(getIt.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: WeeklyCheckLockedRow()),
      ),
    );

    await tester.pump();

    expect(find.text('Weekly delivery check'), findsOneWidget);
    expect(find.byType(ProBadge), findsOneWidget);
    // The line the open row has under its title.
    expect(
      find.text('Checks each week whether a push reaches this phone.'),
      findsOneWidget,
    );
    expect(find.byType(AppSwitch), findsOneWidget);
    expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isFalse);
    // A screen reader hears the title, the line and the plan, once each.
    expect(
      find.bySemanticsLabel(
        'Weekly delivery check, Checks each week whether a push reaches '
        'this phone., Hosted',
      ),
      findsOneWidget,
    );
  });
}
