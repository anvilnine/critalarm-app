// Developer tool: draws the floating tab bar on its own, in both themes, with
// word labels and with glyphs, and steps a tab change in 16 ms frames so the
// sliding pill can be looked at frame by frame.
//
//   fvm flutter test tool/capture_tab_bar.dart
//
// Set CAPTURE_DIR to choose where the PNGs land (default screenshots/tab_bar).
// Tool prints progress to stdout.
// ignore_for_file: avoid_print, cast_nullable_to_non_nullable

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

final String _dir =
    Platform.environment['CAPTURE_DIR'] ?? 'screenshots/tab_bar';

const _items = [
  AppTabItem(label: 'Topics', glyph: GlyphType.list),
  AppTabItem(label: 'History', glyph: GlyphType.clock),
  AppTabItem(label: 'Settings', glyph: GlyphType.gear, showFlag: true),
];

class _Harness extends StatelessWidget {
  const _Harness({
    required this.index,
    required this.dark,
    required this.iconsOnly,
    required this.boundary,
    this.reduceMotion = false,
  });

  final int index;
  final bool dark;
  final bool iconsOnly;
  final bool reduceMotion;
  final GlobalKey boundary;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? buildDarkTheme() : buildLightTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              // The shell hands the bar unbounded constraints through a
              // FittedBox, so do the same here.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppFloatingTabBar(
                    items: _items,
                    currentIndex: index,
                    iconsOnly: iconsOnly,
                    onSelect: (_) {},
                    onCompose: () {},
                    onSearch: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    print('Captured ${file.path}');
  });
}

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final dark in [false, true]) {
    for (final iconsOnly in [false, true]) {
      final tag =
          '${dark ? 'dark' : 'light'}_${iconsOnly ? 'icons' : 'labels'}';

      testWidgets('stills $tag', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 120 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        for (var i = 0; i < _items.length; i++) {
          await tester.pumpWidget(
            _Harness(index: i, dark: dark, iconsOnly: iconsOnly, boundary: key),
          );
          await tester.pumpAndSettle();
          await _shot(tester, key, 'still_${tag}_tab$i');
        }
      });

      testWidgets('frames $tag', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 120 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          _Harness(index: 0, dark: dark, iconsOnly: iconsOnly, boundary: key),
        );
        await tester.pumpAndSettle();
        // Topics to Settings: the longest move, so any jump shows.
        await tester.pumpWidget(
          _Harness(index: 2, dark: dark, iconsOnly: iconsOnly, boundary: key),
        );
        for (var f = 0; f <= 24; f++) {
          await _shot(
            tester,
            key,
            'frames_$tag/f${f.toString().padLeft(2, '0')}',
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
    }
  }

  testWidgets('reduce motion jumps', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 120 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      _Harness(
        index: 0,
        dark: false,
        iconsOnly: false,
        boundary: key,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _Harness(
        index: 2,
        dark: false,
        iconsOnly: false,
        boundary: key,
        reduceMotion: true,
      ),
    );
    await tester.pump();
    await _shot(tester, key, 'reduce_motion_first_frame');
  });
}
