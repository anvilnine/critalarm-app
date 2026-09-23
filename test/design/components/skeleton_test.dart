import 'package:critalarm/design/components/skeleton.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWithTheme(
    Widget child, {
    bool isDark = false,
    bool reduceMotion = false,
  }) {
    return MaterialApp(
      theme: isDark ? buildDarkTheme() : buildLightTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  group('AppSkeleton & AppSkeletonBone', () {
    testWidgets('renders in light mode with warm ink tones', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const AppSkeleton(
            child: AppSkeletonBone(width: 100, height: 20),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppSkeletonBone),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);
      // In light mode, ink is #1A140F (RGB: 26, 20, 15)
      expect(decoration.color!.r, closeTo(AppColors.light.ink.r, 0.01));
      expect(decoration.color!.g, closeTo(AppColors.light.ink.g, 0.01));
      expect(decoration.color!.b, closeTo(AppColors.light.ink.b, 0.01));
      expect(decoration.color!.a, greaterThan(0.05));
    });

    testWidgets('renders in dark mode with light ink tones', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const AppSkeleton(
            child: AppSkeletonBone(width: 100, height: 20),
          ),
          isDark: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppSkeletonBone),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);
      // In dark mode, ink is #F7F1EA (RGB: 247, 241, 234)
      expect(decoration.color!.r, closeTo(AppColors.dark.ink.r, 0.01));
      expect(decoration.color!.g, closeTo(AppColors.dark.ink.g, 0.01));
      expect(decoration.color!.b, closeTo(AppColors.dark.ink.b, 0.01));
      expect(decoration.color!.a, greaterThan(0.05));
    });

    testWidgets('respects reduceMotion without animating', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const AppSkeleton(
            child: AppSkeletonBone(width: 100, height: 20),
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump();

      final firstContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppSkeletonBone),
          matching: find.byType(Container),
        ),
      );
      final firstColor = (firstContainer.decoration! as BoxDecoration).color!;

      // Advance time by 450ms (half of 900ms pulse cycle)
      await tester.pump(const Duration(milliseconds: 450));

      final secondContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppSkeletonBone),
          matching: find.byType(Container),
        ),
      );
      final secondColor = (secondContainer.decoration! as BoxDecoration).color!;

      // With reduced motion, opacity should not animate or change
      expect(firstColor.a, equals(secondColor.a));
    });
  });

  group('AppMessageCardSkeleton', () {
    testWidgets('renders matching AppMessageCard dimensions and structure', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(const AppMessageCardSkeleton()),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AppMessageCardSkeleton), findsOneWidget);
      expect(find.byType(AppSkeletonBone), findsNWidgets(5));
    });

    testWidgets('renders properly in dark mode', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const AppMessageCardSkeleton(), isDark: true),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AppMessageCardSkeleton), findsOneWidget);
    });
  });

  group('AppTokenRowSkeleton & AppTokensSectionSkeleton', () {
    testWidgets('renders single token row skeleton', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const AppSkeleton(child: AppTokenRowSkeleton()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AppTokenRowSkeleton), findsOneWidget);
      expect(find.byType(AppSkeletonBone), findsNWidgets(3));
    });

    testWidgets('renders full tokens section skeleton', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const AppTokensSectionSkeleton()),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AppTokensSectionSkeleton), findsOneWidget);
      expect(find.byType(AppTokenRowSkeleton), findsNWidgets(2));
      expect(find.byType(AppButtonSkeleton), findsOneWidget);
    });
  });
}
