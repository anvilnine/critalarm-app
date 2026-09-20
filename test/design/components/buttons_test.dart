import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  /// The partial-opacity widgets in [of]'s subtree. The loading spinner hides
  /// the label behind an `Opacity(opacity: 0)`, which is not what we are after.
  Iterable<Opacity> partialOpacities(Finder of) {
    return find
        .descendant(of: of, matching: find.byType(Opacity))
        .evaluate()
        .map((element) => element.widget as Opacity)
        .where((opacity) => opacity.opacity > 0 && opacity.opacity < 1);
  }

  group('a filled button that is off', () {
    testWidgets('is not drawn see-through', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(
          wrap(AppButton(label: 'Next', variant: variant)),
        );
        await tester.pumpAndSettle();

        expect(
          partialOpacities(find.byType(AppButton)),
          isEmpty,
          reason: '$variant should not fade itself',
        );
      }
    });

    testWidgets('does not keep the colours it has when it is on', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const AppButton(label: 'Next')),
      );
      await tester.pumpAndSettle();
      final off = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(AnimatedContainer),
        ),
      );

      await tester.pumpWidget(
        wrap(AppButton(label: 'Next', onPressed: () {})),
      );
      await tester.pumpAndSettle();
      final on = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(AnimatedContainer),
        ),
      );

      expect(
        (off.decoration! as BoxDecoration).color,
        isNot((on.decoration! as BoxDecoration).color),
      );
    });
  });

  testWidgets('a button that is off says so to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(const AppButton(label: 'Next')));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(AppButton)),
      matchesSemantics(
        label: 'Next',
        isButton: true,
        // isEnabled is false by default in this matcher, and passing it
        // again trips avoid_redundant_argument_values.
        hasEnabledState: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('a button that is off ignores a tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        AppButton(
          label: 'Next',
          isLoading: true,
          onPressed: () => taps++,
        ),
      ),
    );
    // The spinner never stops, so this one pumps instead of settling.
    await tester.pump();

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('an icon button that is off is not drawn see-through', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const AppIconButton(glyph: GlyphType.close, ariaLabel: 'Close')),
    );
    await tester.pumpAndSettle();

    expect(partialOpacities(find.byType(AppIconButton)), isEmpty);
  });
}
