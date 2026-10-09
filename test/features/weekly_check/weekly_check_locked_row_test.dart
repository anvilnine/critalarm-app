import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/weekly_check/presentation/widgets/weekly_check_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/access/access_fakes.dart';

void main() {
  testWidgets('the locked weekly check row is its title and the badge, with '
      'no second line', (tester) async {
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

    expect(find.text('Weekly delivery check'), findsOneWidget);
    expect(find.byType(ProBadge), findsOneWidget);
    // The title already says it.
    expect(
      find.text('Checks each week whether a push reaches this phone.'),
      findsNothing,
    );
    // A screen reader hears the title and the plan, once each.
    expect(
      find.bySemanticsLabel(RegExp(r'^Weekly delivery check, Hosted$')),
      findsOneWidget,
    );
  });
}
