import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/components/top_bar.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen with a solid bar backing listens to its own scrolling. When
/// the list gets shorter while it is scrolled down, the scroll position is
/// corrected in the middle of layout, and the notification for that arrives
/// while the frame is being built. Nothing may ask for a rebuild then.
void main() {
  Widget screen({required double rowHeight, required ScrollController on}) =>
      MaterialApp(
        theme: buildLightTheme(),
        home: AppScreenScaffold(
          hasTabBar: false,
          withGhosts: false,
          barBacking: const Color(0xFF2A3BD8),
          topBar: const AppTopBar(title: 'Title'),
          bottomBar: const SizedBox(height: 120),
          scrollController: on,
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: rowHeight)),
          ],
        ),
      );

  testWidgets('a list that shrinks while scrolled down throws nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(screen(rowHeight: 2000, on: controller));
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));

    // The list is now shorter than the screen, so layout pulls the
    // position back to the top and says so mid-frame.
    await tester.pumpWidget(screen(rowHeight: 100, on: controller));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.offset, 0);
  });

  testWidgets('scrolling by hand still moves the backing in', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(screen(rowHeight: 2000, on: controller));
    await tester.pumpAndSettle();

    double backing() => tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity)
        .first;

    expect(backing(), 0);
    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(backing(), 1);
    expect(tester.takeException(), isNull);
  });
}
