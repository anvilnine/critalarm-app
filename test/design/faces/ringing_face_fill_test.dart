import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _yellow = Color(0xFFFFC93C);
const Color _ink = Color(0xFF1A140F);

void main() {
  test('the yellow token is the face fill in both themes', () {
    expect(AppColors.light.faceFill, _yellow);
    expect(AppColors.light.yellow, _yellow);
    expect(AppColors.dark.faceFill, _yellow);
  });

  for (final style in RingingStyle.values) {
    testWidgets('${style.name}: the head is yellow and the features are '
        'ink in the light and the dark theme', (tester) async {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        final colors = theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.copyWith(extensions: [colors]),
            home: Scaffold(
              body: RingingFaceWidget(style: style, isLive: false),
            ),
          ),
        );
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(RingingFaceWidget),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as RingingFacePainter;
        expect(painter.fillColor, _yellow, reason: '${theme.brightness}');
        expect(painter.inkColor, _ink, reason: '${theme.brightness}');
      }
    });
  }

  test('a capture can hold the shuffling face on one style, in a debug '
      'build only', () {
    expect(pinnedRingingStyle(), isNull);
    expect(pinnedRingingStyle(name: 'no_such_face'), isNull);
    expect(pinnedRingingStyle(name: 'rage'), RingingStyle.rage);
    expect(pinnedRingingStyle(name: 'rage', isDebug: false), isNull);
  });
}
