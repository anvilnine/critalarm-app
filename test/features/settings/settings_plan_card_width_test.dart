import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/settings/presentation/settings_plan_card.dart';
import 'package:critalarm/features/settings/presentation/settings_pro_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The parent does not stretch its children, as a plain Column does not.
  Future<void> pump(
    WidgetTester tester,
    double width,
    List<Widget> kids,
  ) async {
    tester.view.physicalSize = Size(width * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: kids,
            ),
          ),
        ),
      ),
    );
  }

  for (final width in [390.0, 320.0]) {
    testWidgets('a plan card with no pill is as wide as the Pro row, at '
        '${width.toInt()}', (tester) async {
      await pump(tester, width, [
        const SettingsPlanCard(
          key: Key('hosted'),
          title: 'Cloud',
          usage: '2 critical topics used',
        ),
        SettingsProRow(
          key: const Key('pro'),
          state: HoldingState.notHeld,
          onSee: () {},
        ),
        const SettingsProRow(
          key: Key('owned'),
          state: HoldingState.held,
          onSee: _noop,
        ),
      ]);

      final hosted = tester.getSize(find.byKey(const Key('hosted'))).width;
      final pro = tester.getSize(find.byKey(const Key('pro'))).width;
      final owned = tester.getSize(find.byKey(const Key('owned'))).width;
      expect(hosted, width - 40);
      expect(hosted, pro);
      expect(hosted, owned);
    });
  }
}

void _noop() {}
