import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/access_lab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a feature row of the lab shows its whole note, however long, '
      'on a narrow phone at a large text size', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const note =
        'Needs Hosted, not offered on own server. Goes to Reliability.';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccessLabFeatureRow(
              title: 'Weekly check',
              value: 'Locked, sells Hosted',
              note: note,
              glyph: GlyphType.arrow,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final text in [note, 'Locked, sells Hosted', 'Weekly check']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(paragraph.didExceedMaxLines, isFalse, reason: '"$text" is cut');
      expect(tester.widget<Text>(find.text(text)).maxLines, isNull);
    }
  });
}
