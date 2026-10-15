// Draws the search results panel with one section of every kind, light and
// dark, so its look can be checked without a phone.
//
//   fvm flutter test tool/capture_search_panel.dart
//
// Writes build/search_shots/search_panel.<light|dark>.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/presentation/cubits/search_state.dart';
import 'package:critalarm/features/search/presentation/widgets/search_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/search_shots');

const _results = <SearchResult>[
  SearchResult(
    kind: SearchResultKind.topic,
    id: 'prod-db',
    title: 'prod-db',
    subtitle: 'Topic, critical delivery on',
    faceState: FaceState.alarmed,
    isCrit: true,
  ),
  SearchResult(
    kind: SearchResultKind.topic,
    id: 'prod-api',
    title: 'prod-api',
    subtitle: 'Topic',
    faceState: FaceState.calm,
  ),
  SearchResult(
    kind: SearchResultKind.history,
    id: 'inc-1',
    title: 'prod-db',
    subtitle: 'Rang 1 min 12 s, answered on this phone',
    timeText: 'Oct 14',
    historyMark: HistoryMark.answered,
  ),
  SearchResult(
    kind: SearchResultKind.history,
    id: 'inc-2',
    title: 'prod-api',
    subtitle: 'Rang 5 min, nobody answered',
    timeText: 'Oct 12',
    historyMark: HistoryMark.notAnswered,
  ),
  SearchResult(
    kind: SearchResultKind.settings,
    id: 'server',
    title: 'Server',
    subtitle: 'Settings',
  ),
  SearchResult(
    kind: SearchResultKind.docs,
    id: 'self-host',
    title: 'Run your own server',
    subtitle: 'Self-hosting',
    externalUrl: 'https://critalarm.app/docs/self-host',
  ),
  SearchResult(
    kind: SearchResultKind.docs,
    id: 'docker',
    title: 'Docker compose',
    subtitle: 'Self-hosting',
    externalUrl: 'https://critalarm.app/docs/docker',
  ),
];

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(
        File(
          'assets/fonts/$file',
        ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  }

  await family('Instrument Sans', [
    'InstrumentSans-Regular.ttf',
    'InstrumentSans-Medium.ttf',
    'InstrumentSans-SemiBold.ttf',
    'InstrumentSans-Bold.ttf',
  ]);
  await family('JetBrains Mono', [
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-SemiBold.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
}

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('capture the search panel', (tester) async {
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false;

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    for (final (name, colors) in [
      ('light', AppColors.light),
      ('dark', AppColors.dark),
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(extensions: [colors]),
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              // The scrim: the canvas, dimmed and blurred behind the panel.
              color: Color.alphaBlend(
                colors.canvas.withValues(alpha: 0.7),
                colors.canvasAlt,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SearchPanel(
                  state: const SearchState(
                    status: SearchStatus.ready,
                    query: 'prod',
                    results: _results,
                  ),
                  maxHeight: 844,
                  topInset: 44,
                  bottomInset: 90,
                  onTapResult: (_) {},
                  onTapRecent: (_) {},
                  onClearRecent: () {},
                  onTapExample: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$_out/search_panel.$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    // A test must leave the painting switches as it found them.
    debugDisableShadows = true;
  });
}
