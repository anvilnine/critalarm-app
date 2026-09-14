import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the scaffold on a display of [size] and returns how wide the row
/// inside it ended up.
Future<double> rowWidth(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: const AppScreenScaffold(
        hasTabBar: false,
        withGhosts: false,
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: 60, key: Key('row'))),
        ],
      ),
    ),
  );
  await tester.pump();
  return tester.getSize(find.byKey(const Key('row'))).width;
}

void main() {
  testWidgets('a phone fills the display', (tester) async {
    expect(await rowWidth(tester, const Size(402, 874)), 402);
  });

  testWidgets('an iPad mini upright caps the column at 560', (tester) async {
    expect(
      await rowWidth(tester, const Size(744, 1133)),
      AppSize.contentMaxWidth,
    );
  });

  testWidgets('an iPad Pro on its side caps the column at 560', (tester) async {
    expect(
      await rowWidth(tester, const Size(1210, 834)),
      AppSize.contentMaxWidth,
    );
  });

  testWidgets('a phone hides the detail pane', (tester) async {
    await pumpWithDetail(tester, const Size(402, 874));
    expect(find.byKey(const Key('detail')), findsNothing);
  });

  testWidgets('an iPad on its side shows the detail pane', (tester) async {
    await pumpWithDetail(tester, const Size(1210, 834));
    expect(find.byKey(const Key('detail')), findsOneWidget);
  });
}

/// Pumps the scaffold on a display of [size] with a detail pane supplied.
Future<void> pumpWithDetail(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: const AppScreenScaffold(
        hasTabBar: false,
        withGhosts: false,
        detail: SizedBox(key: Key('detail')),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: 60, key: Key('row'))),
        ],
      ),
    ),
  );
  await tester.pump();
}
