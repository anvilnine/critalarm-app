import 'dart:async';

import 'package:critalarm/design/ambient/ambient_page.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AmbientPage route creation', () {
    testWidgets('creates route with expected defaults and properties',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final page = AmbientPage<void>(
                name: 'test-page',
                child: const Text('Page Content'),
              );

              final route = page.createRoute(context);

              expect(route, isA<PageRoute<void>>());
              final pageRoute = route as PageRoute<void>;
              expect(pageRoute.opaque, isFalse);
              expect(pageRoute.transitionDuration, AppDurations.slow);
              expect(pageRoute.reverseTransitionDuration, AppDurations.slow);
              expect(pageRoute.fullscreenDialog, isFalse);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('iOS edge swipe back navigation with AmbientPage', () {
    testWidgets('edge swipe pops top route on iOS', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => AmbientPage(
              key: state.pageKey,
              child: const Scaffold(body: Text('Root Screen')),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) => AmbientPage(
                  key: state.pageKey,
                  child: const Scaffold(body: Text('Detail Screen')),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.iOS),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Root Screen'), findsOneWidget);
      expect(find.text('Detail Screen'), findsNothing);

      router.go('/detail');
      await tester.pumpAndSettle();

      expect(find.text('Detail Screen'), findsOneWidget);

      // Perform a swipe from the left edge across > 50% of the screen (500px).
      final gesture = await tester.startGesture(const Offset(5, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Detail Screen'), findsNothing);
      expect(find.text('Root Screen'), findsOneWidget);
    });

    testWidgets('short drag cancels swipe back on iOS', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => AmbientPage(
              key: state.pageKey,
              child: const Scaffold(body: Text('Root Screen')),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) => AmbientPage(
                  key: state.pageKey,
                  child: const Scaffold(body: Text('Detail Screen')),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.iOS),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      router.go('/detail');
      await tester.pumpAndSettle();
      expect(find.text('Detail Screen'), findsOneWidget);

      // Perform a very short drag and release (< 50% of width).
      final gesture = await tester.startGesture(const Offset(5, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Screen should still be Detail Screen.
      expect(find.text('Detail Screen'), findsOneWidget);
    });

    testWidgets('fullscreenDialog routes do not allow swipe back on iOS',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => AmbientPage(
              key: state.pageKey,
              child: const Scaffold(body: Text('Root Screen')),
            ),
            routes: [
              GoRoute(
                path: 'modal',
                pageBuilder: (context, state) => AmbientPage(
                  key: state.pageKey,
                  fullscreenDialog: true,
                  child: const Scaffold(body: Text('Modal Screen')),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.iOS),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      router.go('/modal');
      await tester.pumpAndSettle();
      expect(find.text('Modal Screen'), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(5, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Should still be on modal screen
      expect(find.text('Modal Screen'), findsOneWidget);
    });

    testWidgets('edge swipe does not trigger on Android', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => AmbientPage(
              key: state.pageKey,
              child: const Scaffold(body: Text('Root Screen')),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) => AmbientPage(
                  key: state.pageKey,
                  child: const Scaffold(body: Text('Detail Screen')),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.android),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      router.go('/detail');
      await tester.pumpAndSettle();
      expect(find.text('Detail Screen'), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(5, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // On Android, edge touch drag is not intercepted by iOS back gesture
      expect(find.text('Detail Screen'), findsOneWidget);
    });

    testWidgets('AmbientPageRoute also supports edge swipe on iOS',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push(
                        AmbientPageRoute<void>(
                          builder: (_) =>
                              const Scaffold(body: Text('Pushed Screen')),
                        ),
                      ),
                    );
                  },
                  child: const Text('Push Route'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Push Route'));
      await tester.pumpAndSettle();
      expect(find.text('Pushed Screen'), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(5, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Pushed Screen'), findsNothing);
      expect(find.text('Push Route'), findsOneWidget);
    });
  });
}
