import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/search/domain/entities/docs_page.dart';
import 'package:critalarm/features/search/presentation/screens/docs_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_translations.dart';

const _pages = <DocsPage>[
  DocsPage(
    slug: 'a',
    title: 'First page',
    description: '',
    group: 'Getting Started',
    url: 'https://critalarm.app/a/',
  ),
  DocsPage(
    slug: 'b',
    title: 'Docker Installation',
    description: '',
    group: 'Installation',
    url: 'https://critalarm.app/b/',
  ),
  DocsPage(
    slug: 'c',
    title: 'Second page',
    description: '',
    group: 'Getting Started',
    url: 'https://critalarm.app/c/',
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Future<List<DocsPage>?> Function() load,
  DocsPageOpener open,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: DocsListScreen(load: load, open: open),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadTestTranslations);

  test('groups keep the order the index lists them in', () {
    final groups = DocsListScreenGrouping.of(_pages);
    expect(groups.keys, ['Getting Started', 'Installation']);
    expect(groups['Getting Started']!.map((p) => p.slug), ['a', 'c']);
  });

  testWidgets('shows a header per group and opens the tapped url', (
    tester,
  ) async {
    final opened = <String>[];
    await _pump(tester, () async => _pages, (p) async => opened.add(p.url));

    expect(find.text('Getting Started'), findsOneWidget);
    expect(find.text('Installation'), findsOneWidget);
    expect(find.text('Docs'), findsOneWidget);

    await tester.tap(find.text('Docker Installation'));
    expect(opened, ['https://critalarm.app/b/']);
  });

  testWidgets('says so when the index did not load', (tester) async {
    await _pump(tester, () async => null, (_) async {});
    expect(find.text('The docs list did not load.'), findsOneWidget);
  });
}
