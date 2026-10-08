// Captures the Personalize page and the three older locked surfaces, off
// the device, with the mock API and the developer plan switches.
//
//   fvm flutter test tool/capture_personalize.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true
//
// For 390 by 844 and 375 by 667, light and dark, at the default text size
// and 1.3, with motion still, it writes one PNG per state:
//   free      nothing held
//   pro       the Pro pack held
//   hosted    Hosted held
//   both      both held
//   trying    free, after a tap on the locked "Yours" chip: the bar shows
//   full      free, after a tap on the preview: the full-screen preview
// and, at 1024 by 768, the wide layout for `free` and `trying`.
//
// It also writes the surfaces that moved onto the one lock, free and with
// both held: the App icon screen on a paid icon, the Reliability screen
// with the weekly check row, and the Home widgets card's badge.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default
//                                build/personalize_shots)
//   --dart-define=ONLY=<part>,<part>
//                                capture only the files whose name has one
//                                of these parts
//
// A capture fails when anything overflows.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/personalize/ringing_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/personalize_shots',
);
const _only = String.fromEnvironment('ONLY');

const _phones = <(String, Size, double, double)>[
  ('390x844', Size(390, 844), 47, 34),
  ('375x667', Size(375, 667), 20, 0),
];
const _tablet = ('1024x768', Size(1024, 768), 24.0, 20.0);

/// What is held, and what is done once the page is up.
enum _Shot {
  free(isPro: false, isHosted: false),
  pro(isPro: true, isHosted: false),
  hosted(isPro: false, isHosted: true),
  both(isPro: true, isHosted: true),
  trying(isPro: false, isHosted: false),
  full(isPro: false, isHosted: false);

  const _Shot({required this.isPro, required this.isHosted});

  final bool isPro;
  final bool isHosted;
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(
        File('assets/fonts/$file').readAsBytes().then(
          (bytes) => ByteData.view(bytes.buffer),
        ),
      );
    }
    await loader.load();
  }

  await family('Bricolage Grotesque', [
    'BricolageGrotesque-Bold.ttf',
    'BricolageGrotesque-ExtraBold.ttf',
  ]);
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

Future<void> _hold({required bool isPro, required bool isHosted}) async {
  await getIt<DevProSwitch>().setPro(isPro: isHosted);
  await getIt<ProPackDevSwitch>().setHeld(isHeld: isPro);
}

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

/// Pumps [location] at [size] and hands back the key of what to capture.
Future<GlobalKey> _open(
  WidgetTester tester, {
  required String location,
  required Size size,
  required double topInset,
  required double bottomInset,
  required ThemeMode mode,
  required double scale,
  Widget? home,
}) async {
  const dpr = 2.0;
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(
    top: topInset * dpr,
    bottom: bottomInset * dpr,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
  final boundaryKey = GlobalKey();
  Widget framed(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: RepaintBoundary(key: boundaryKey, child: child),
  );
  await tester.pumpWidget(
    BlocProvider<ThemeCubit>.value(
      value: getIt<ThemeCubit>(),
      child: home == null
          ? MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: buildLightTheme(),
              darkTheme: buildDarkTheme(),
              themeMode: mode,
              routerConfig: buildRouter(initialLocation: location),
              builder: framed,
            )
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildLightTheme(),
              darkTheme: buildDarkTheme(),
              themeMode: mode,
              home: home,
              builder: framed,
            ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    // Reads that go through real I/O land between the frames.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  return boundaryKey;
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name, {
  required bool isGood,
}) => tester.runAsync(() async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${isGood ? 'FIT ' : 'BAD '} ${file.path}');
});

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadTestTranslations();
    await configureDependencies();
    await _loadFonts();
    // The phone can change its icon and shows the standard one.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(AppIconHost.channelName),
          (call) async =>
              call.method == 'current' ? AppIcon.standard.platformName : true,
        );
  });

  void capture(
    String name,
    Future<void> Function(WidgetTester tester, List<String> errors) body,
  ) {
    if (!_wanted(name)) return;
    testWidgets('capture $name', (tester) async {
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString());
      debugDisableShadows = false;
      try {
        await body(tester, errors);
        expect(errors, isEmpty, reason: errors.join('\n'));
      } finally {
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
        await _hold(isPro: false, isHosted: false);
      }
    });
  }

  final screens = [
    for (final phone in _phones)
      for (final shot in _Shot.values) (phone, shot),
    (_tablet, _Shot.free),
    (_tablet, _Shot.trying),
  ];

  for (final ((sizeName, size, top, bottom), shot) in screens) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, 1.3]) {
        final name =
            'personalize_${shot.name}_${sizeName}_${mode.name}_${scale}x';
        capture(name, (tester, errors) async {
          await _hold(isPro: shot.isPro, isHosted: shot.isHosted);
          final key = await _open(
            tester,
            location: '/settings/personalize',
            size: size,
            topInset: top,
            bottomInset: bottom,
            mode: mode,
            scale: scale,
          );
          if (shot == _Shot.trying) {
            final yours = find.byKey(const ValueKey('sound-yours'));
            await tester.ensureVisible(yours);
            await tester.pump();
            await tester.tap(yours, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
          if (shot == _Shot.full) {
            await tester.tap(find.byType(RingingPreview));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.byType(RingingPreviewPage), findsOneWidget);
          }
          await _save(tester, key, name, isGood: errors.isEmpty);
        });
      }
    }
  }

  // The surfaces that moved onto the one lock.
  final (sizeName, size, top, bottom) = _phones.first;
  for (final held in [false, true]) {
    final plan = held ? 'both' : 'free';
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      capture('lock_app_icon_${plan}_${sizeName}_${mode.name}', (
        tester,
        errors,
      ) async {
        await _hold(isPro: held, isHosted: held);
        final key = await _open(
          tester,
          location: '/app-icon',
          size: size,
          topInset: top,
          bottomInset: bottom,
          mode: mode,
          scale: 1,
        );
        // On to the first paid icon.
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await _save(
          tester,
          key,
          'lock_app_icon_${plan}_${sizeName}_${mode.name}',
          isGood: errors.isEmpty,
        );
      });

      capture('lock_weekly_check_${plan}_${sizeName}_${mode.name}', (
        tester,
        errors,
      ) async {
        await _hold(isPro: held, isHosted: held);
        final key = await _open(
          tester,
          location: '/settings/reliability',
          size: size,
          topInset: top,
          bottomInset: bottom,
          mode: mode,
          scale: 1,
        );
        final badge = find.byType(FeatureLockBadge);
        if (badge.evaluate().isNotEmpty) {
          await tester.ensureVisible(badge.first);
          await tester.pump(const Duration(milliseconds: 200));
        }
        await _save(
          tester,
          key,
          'lock_weekly_check_${plan}_${sizeName}_${mode.name}',
          isGood: errors.isEmpty,
        );
      });

      capture('lock_badges_${plan}_${sizeName}_${mode.name}', (
        tester,
        errors,
      ) async {
        await _hold(isPro: held, isHosted: held);
        // The badge as each surface asks for it, side by side: the Home
        // widgets card and the weekly check keep the plain pill once the
        // plan is held, the app icon and a Personalize option drop it.
        final key = await _open(
          tester,
          location: '/',
          size: const Size(390, 220),
          topInset: 0,
          bottomInset: 0,
          mode: mode,
          scale: 1,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.appColors.cream,
              body: const Padding(
                padding: EdgeInsets.all(Spacing.s5),
                child: Wrap(
                  spacing: Spacing.s4,
                  runSpacing: Spacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AccessLock.inline(
                      feature: AppFeature.widgets,
                      source: LockSource.homeWidgets,
                      child: FeatureLockBadge(staysWhenOpen: true),
                    ),
                    AccessLock.inline(
                      feature: AppFeature.weeklyCheck,
                      source: LockSource.reliability,
                      child: FeatureLockBadge(staysWhenOpen: true),
                    ),
                    AccessLock.inline(
                      feature: AppFeature.appIcons,
                      source: LockSource.appIcon,
                      child: FeatureLockBadge(),
                    ),
                    AccessLock(
                      feature: AppFeature.ownSounds,
                      source: LockSource.personalizeSound,
                      child: AppPlainChip(text: 'option'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await _save(
          tester,
          key,
          'lock_badges_${plan}_${sizeName}_${mode.name}',
          isGood: errors.isEmpty,
        );
      });
    }
  }
}
