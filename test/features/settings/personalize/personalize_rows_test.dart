import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget row({
    required FeatureDecision decision,
    required double width,
    required double textScale,
    String word = 'Hosted',
  }) => MaterialApp(
    theme: buildLightTheme(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: FeatureLock(
              decision: decision,
              planWord: word,
              lockedWord: 'locked',
              drawsBadge: false,
              child: PersonalizeRow(
                picture: const SizedBox.shrink(),
                title: 'App icon',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a locked row keeps its title clear of the badge, narrow and '
      'at large text', (tester) async {
    // The right half of the wide page at its narrowest, at 1.3.
    for (final width in [242.0, 300.0, 358.0]) {
      await tester.pumpWidget(
        row(
          decision: const FeatureLocked(Holding.hosted),
          width: width,
          textScale: 1.3,
        ),
      );
      final title = tester.getRect(find.text('App icon'));
      final badge = tester.getRect(find.byType(ProBadge));

      expect(badge.overlaps(title), isFalse, reason: 'at $width');
      expect(title.right, lessThanOrEqualTo(badge.left), reason: 'at $width');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('an open row has an arrow and no badge', (tester) async {
    await tester.pumpWidget(
      row(decision: const FeatureOpen(), width: 358, textScale: 1),
    );
    expect(find.byType(ProBadge), findsNothing);
    expect(find.byType(AppGlyph), findsOneWidget);
  });
}
