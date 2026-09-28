import 'package:critalarm/design/ambient/ambient_scope.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/components/scroll_fade.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// How tall the display is in the tests below, and how tall the one row in
/// the list is. Everything the list cannot show is room left at the bottom.
const double displayHeight = 874;
const double rowHeight = 2000;

late ScrollController controller;

/// Pumps the scaffold on a phone-sized display.
Future<void> pumpScaffold(
  WidgetTester tester, {
  bool hasTabBar = false,
  Widget? bottomBar,
  bool withFades = true,
  bool ambient = false,
}) async {
  controller = ScrollController();
  addTearDown(controller.dispose);

  tester.view.physicalSize = const Size(402, displayHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Widget screen = AppScreenScaffold(
    hasTabBar: hasTabBar,
    withGhosts: false,
    withFades: withFades,
    bottomBar: bottomBar,
    scrollController: controller,
    slivers: const [
      SliverToBoxAdapter(
        child: SizedBox(height: rowHeight, key: Key('row')),
      ),
    ],
  );
  if (ambient) {
    screen = AmbientScope(child: screen);
  }

  await tester.pumpWidget(MaterialApp(theme: buildLightTheme(), home: screen));
  // The bar is measured after it lays out, so the inset lands a frame later.
  await tester.pumpAndSettle();
}

/// The room the scroll view left under its last row. Whatever the list can
/// scroll past the one row it holds is that room.
double bottomInset() =>
    controller.position.maxScrollExtent - rowHeight + displayHeight;

void main() {
  const barHeight = 48.0;
  const bar = SizedBox(key: Key('bar'), height: barHeight, width: 200);

  // The safe area is empty in a test, so every number below is the 16 the
  // scaffold always leaves plus whatever floats over the bottom edge.
  const base = 16.0;

  testWidgets('a pinned bar leaves room for itself', (tester) async {
    await pumpScaffold(tester, bottomBar: bar);
    // The bar itself, plus the 12 the scaffold puts under it.
    expect(
      bottomInset(),
      base + barHeight + AppScreenScaffold.bottomBarGap,
    );
  });

  testWidgets('the last row scrolls clear of the pinned bar', (tester) async {
    await pumpScaffold(tester, bottomBar: bar);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    final row = tester.getRect(find.byKey(const Key('row')));
    final pinned = tester.getRect(find.byKey(const Key('bar')));
    expect(row.bottom, lessThanOrEqualTo(pinned.top));
  });

  testWidgets('the tab bar keeps the room it always had', (tester) async {
    await pumpScaffold(tester, hasTabBar: true);
    expect(bottomInset(), base + AppFloatingTabBar.contentGap);
  });

  testWidgets('a pinned bar stacks on top of the tab bar', (tester) async {
    const tallBar = SizedBox(height: 100, width: 200);
    await pumpScaffold(tester, hasTabBar: true, bottomBar: tallBar);

    // Home puts the backup notice above the floating tab bar rather than
    // behind it, so the content has to clear both. Before the notice existed
    // nothing had a tab bar and a pinned bar at once, and the room was the
    // taller of the two.
    expect(
      bottomInset(),
      base +
          AppFloatingTabBar.contentGap +
          100 +
          AppScreenScaffold.bottomBarGap,
    );
  });

  testWidgets('the scrim sits behind the pinned bar', (tester) async {
    await pumpScaffold(tester, bottomBar: bar);
    expect(find.byType(AppScrollScrim), findsOneWidget);
  });

  testWidgets('a screen with fades off gets no scrim', (tester) async {
    await pumpScaffold(tester, bottomBar: bar, withFades: false);
    expect(find.byType(AppScrollScrim), findsNothing);
  });

  testWidgets('a screen with its own ambient canvas still gets the scrim', (
    tester,
  ) async {
    await pumpScaffold(tester, bottomBar: bar, ambient: true);
    expect(find.byType(AppScrollScrim), findsOneWidget);
  });
}
