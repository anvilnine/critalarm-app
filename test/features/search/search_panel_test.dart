import 'package:critalarm/design/components/list_rows.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:critalarm/features/history/presentation/widgets/history_row.dart';
import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/presentation/cubits/search_state.dart';
import 'package:critalarm/features/search/presentation/widgets/search_docs_row.dart';
import 'package:critalarm/features/search/presentation/widgets/search_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_translations.dart';

const _topic = SearchResult(
  kind: SearchResultKind.topic,
  id: 'prod',
  title: 'prod',
  subtitle: 'Topic',
  faceState: FaceState.calm,
);

const _alarm = SearchResult(
  kind: SearchResultKind.history,
  id: 'inc-1',
  title: 'prod-alarm',
  subtitle: 'Rang 2 min, answered',
  timeText: 'Oct 14',
  historyMark: HistoryMark.answered,
);

const _setting = SearchResult(
  kind: SearchResultKind.settings,
  id: 'sound',
  title: 'Alarm sound',
  subtitle: 'Sounds',
);

const _doc = SearchResult(
  kind: SearchResultKind.docs,
  id: 'self-host',
  title: 'Run your own server',
  subtitle: 'Self-hosting',
  externalUrl: 'https://critalarm.app/docs/self-host',
);

Future<void> _pump(WidgetTester tester, List<SearchResult> results) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SearchPanel(
            state: SearchState(
              status: SearchStatus.ready,
              query: 'prod',
              results: results,
            ),
            maxHeight: 2000,
            onTapResult: (_) {},
            onTapRecent: (_) {},
            onClearRecent: () {},
            onTapExample: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('each section title sits above its rows', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, const [_topic, _alarm, _setting, _doc]);

    double top(Finder f) => tester.getTopLeft(f).dy;

    expect(top(find.text('Topics')), lessThan(top(find.text('prod'))));
    expect(top(find.text('History')), lessThan(top(find.text('prod-alarm'))));
    expect(top(find.text('Settings')), lessThan(top(find.text('Alarm sound'))));
    expect(
      top(find.text('Documentation')),
      lessThan(top(find.text('Run your own server'))),
    );
  });

  testWidgets('the best section sits nearest the bar', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, const [_topic, _alarm, _setting, _doc]);

    double top(Finder f) => tester.getTopLeft(f).dy;

    // Topics ranked first, so it is lowest on screen, by the bar.
    expect(top(find.text('Topics')), greaterThan(top(find.text('History'))));
    expect(top(find.text('History')), greaterThan(top(find.text('Settings'))));
    expect(
      top(find.text('Settings')),
      greaterThan(top(find.text('Documentation'))),
    );
  });

  testWidgets('each kind draws with its own row', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, const [_topic, _alarm, _setting, _doc]);

    expect(
      find.ancestor(of: find.text('prod'), matching: find.byType(AppListRow)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('prod-alarm'),
        matching: find.byType(HistoryRow),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Alarm sound'),
        matching: find.byType(AppListRow),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Run your own server'),
        matching: find.byType(SearchDocsRow),
      ),
      findsOneWidget,
    );
  });
}
