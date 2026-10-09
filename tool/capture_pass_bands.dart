// Captures the compact band stack (`AppPassBands`) off the device, with made-up
// data: the four cards of a topic (Look, Sound, Wake-up challenge, Tokens).
//
//   fvm flutter test tool/capture_pass_bands.dart \
//     --dart-define=OUT=build/captures/bands
//
// One PNG per state, display, theme and text size, named by the pass kit
// (`capture_pass_kit.dart`):
//   bands-short    short values: Standard, Piano, Off, a count of 2
//   bands-long     long look and sound names, a plan tag on the challenge and
//                  an empty count, the card that keeps its height with no value
//   bands-inset    the cards asked to sit 12 in from the sides
//   bands-reduce   the resting frame under reduce motion (390 wide)
//   bands-column   a topic-like column: a sheet above the stack and a link
//                  below it, to show the stack inside a page that pads
//
// Displays: 390 and 320 wide. Light and dark. Text scale 1.0, 1.3 and 2.0
// (1.3 and 2.0 are the flat form). A shot that overflows fails. It also taps
// each card and checks that the caller gets a `PassOrigin` of that card.
//
// This captures stills. It does not show anything moving.
//
// Developer tool.
// ignore_for_file: avoid_print

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/gallery/passes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_pass_kit.dart';

class _Column extends StatelessWidget {
  const _Column();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Messages, as the topic page draws them above the stack.',
              style: TextStyle(color: colors.ink),
            ),
          ),
        ),
        const SizedBox(height: 22),
        AppPassBands(
          groupLabel: 'Topic settings',
          cards: passBandDemoCards(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Center(
            child: Text('Delete topic', style: TextStyle(color: colors.error)),
          ),
        ),
      ],
    );
  }
}

void main() {
  setUpAll(setUpPassCaptures);

  for (final mode in passThemes) {
    for (final device in const [passPhone, passNarrowPhone]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        String name(String page) => passFileName(
          page: page,
          device: device,
          mode: mode,
          scale: scale,
          frame: 'rest',
        );

        registerPassShot(
          name: name('bands-short'),
          device: device,
          mode: mode,
          scale: scale,
          kind: PassShotKind.section,
          build: (context) => AppPassBands(
            groupLabel: 'Topic settings',
            cards: passBandDemoCards(context),
          ),
        );
        registerPassShot(
          name: name('bands-long'),
          device: device,
          mode: mode,
          scale: scale,
          kind: PassShotKind.section,
          build: (context) => AppPassBands(
            groupLabel: 'Topic settings',
            cards: passBandDemoCards(
              context,
              look: 'Ringing red with a very long name',
              sound: 'My recording of the kitchen timer going off',
              hasTag: true,
              tokens: '',
            ),
          ),
        );
        registerPassShot(
          name: name('bands-inset'),
          device: device,
          mode: mode,
          scale: scale,
          kind: PassShotKind.section,
          build: (context) => AppPassBands(
            hasInsets: true,
            cards: passBandDemoCards(context),
          ),
        );
        registerPassShot(
          name: name('bands-column'),
          device: device,
          mode: mode,
          scale: scale,
          kind: PassShotKind.section,
          build: (_) => const _Column(),
        );
      }

      registerPassShot(
        name: passFileName(
          page: 'bands-reduce',
          device: device,
          mode: mode,
          scale: 1,
          frame: 'rest',
        ),
        device: device,
        mode: mode,
        scale: 1,
        reduceMotion: true,
        kind: PassShotKind.section,
        build: (context) => AppPassBands(
          groupLabel: 'Topic settings',
          cards: passBandDemoCards(context),
        ),
      );
    }
  }

  for (final scale in const [1.0, 2.0]) {
    testWidgets('a tap hands the caller a PassOrigin at scale $scale', (
      tester,
    ) async {
      final taps = <PassOrigin>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) {
                    final colors = context.appColors;
                    return AppPassBands(
                      cards: [
                        for (final pass in [
                          PassId.look,
                          PassId.sound,
                          PassId.challenge,
                          PassId.tokens,
                        ])
                          AppPassCard(
                            pass: pass,
                            tone: passToneFor(pass, colors),
                            label: pass.name,
                            value: pass == PassId.tokens ? '2' : 'Value',
                            onTap: taps.add,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      for (final pass in PassId.values) {
        if (pass == PassId.widgets || pass == PassId.appIcon) continue;
        await tester.tap(find.text(pass.name.toUpperCase()).first);
        await tester.pump();
      }
      expect(taps.map((o) => o.pass), [
        PassId.look,
        PassId.sound,
        PassId.challenge,
        PassId.tokens,
      ]);
      // Every card but the last shows a band. The last is whole and round.
      final flat = scale >= 1.3;
      for (final origin in taps.take(3)) {
        expect(origin.visibleHeight, flat ? isNull : 104);
        expect(origin.bottomRadius, flat ? kPassCardRadius : 0);
      }
      expect(taps.last.visibleHeight, isNull);
      expect(taps.last.bottomRadius, kPassCardRadius);
      // The cards sit where the board puts them.
      if (!flat) {
        expect(taps[1].rect.top - taps[0].rect.top, 104);
        expect(taps[3].rect.top - taps[2].rect.top, 104);
        expect(taps[3].rect.height, 124);
      }
      print('ORIGIN OK scale $scale: ${taps.map((o) => o.rect).join(' ')}');
    });
  }
}
