// Captures the surfaces that moved onto the one lock and are not part of the
// Personalize passes: the App icon screen, the Reliability screen with the
// weekly check row, the sound picker, and the plan badge as each surface asks
// for it. Off the device, with the mock API and the developer plan switches.
//
//   fvm flutter test tool/capture_personalize.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true
//
// At 390 by 844, light and dark, free and with both plans held, it writes
// one PNG per surface:
//   lock_app_icon_<plan>_...      the App icon screen on the first paid icon
//   lock_weekly_check_<plan>_...  the Reliability screen at the weekly check
//   lock_sounds_<plan>_...        the sound picker with one own sound saved,
//                                 scrolled so the own sound and both ways to
//                                 add one (Pick a file, Record) are in it
//   lock_badges_<plan>_...        the badge as each surface asks for it
//
// The Personalize root and its pages have their own tools
// (`capture_pass_root.dart` and one per page).
//
// The sound picker shot is of a phone that can bring in a sound. With nothing
// held it waits for the plan badge on the own sound and fails without it: a
// picker that draws that sound as open is a bug, and was one.
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
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
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
];

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

const _ownSound = AlarmSound(
  id: 'user_capture',
  name: 'My recording',
  source: AlarmSoundSource.user,
  path: '/sounds/user_capture.caf',
  duration: Duration(seconds: 4),
);

/// Puts one own sound on the phone as the saved default, or takes it off.
Future<void> _ownSoundSaved({required bool isSaved}) async {
  final sounds = getIt<AlarmSoundRepository>();
  await sounds.deleteUserSound(_ownSound.id);
  if (isSaved) {
    await sounds.addUserSound(_ownSound);
    await sounds.setDefaultSoundId(_ownSound.id);
  } else {
    await sounds.setDefaultSoundId(BundledSounds.fallbackId);
  }
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
  bool isStill = true,
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
      disableAnimations: isStill,
    ),
    child: RepaintBoundary(key: boundaryKey, child: child),
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
        // The topic page reads the shared list.
        BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
      ],
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
        await _ownSoundSaved(isSaved: false);
      }
    });
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

      capture('lock_sounds_${plan}_${sizeName}_${mode.name}', (
        tester,
        errors,
      ) async {
        await _hold(isPro: held, isHosted: held);
        await _ownSoundSaved(isSaved: true);
        // A phone that can bring in a sound, so the two ways in show.
        const soundChannel = MethodChannel(SoundHost.channelName);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              ..setMockMethodCallHandler(
                soundChannel,
                (call) async => switch (call.method) {
                  'capabilities' => <String, Object?>{
                    'can_import_sounds': true,
                  },
                  'readPeaks' => <double>[],
                  _ => true,
                },
              );
        addTearDown(
          () => messenger.setMockMethodCallHandler(soundChannel, null),
        );
        final key = await _open(
          tester,
          location: '/sounds',
          size: size,
          topInset: top,
          bottomInset: bottom,
          mode: mode,
          scale: 1,
        );
        final own = find.byWidgetPredicate(
          (w) => w is AppRadioRow && w.title == _ownSound.name,
        );
        final badge = find.descendant(of: own, matching: find.byType(ProBadge));
        if (!held) {
          // The row settles to its lock once the plan is read.
          for (var i = 0; i < 10 && badge.evaluate().isEmpty; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(
            badge,
            findsOneWidget,
            reason: 'The locked own sound has no plan badge.',
          );
        } else {
          expect(badge, findsNothing);
        }
        // Down to the own sound and the two ways to add one.
        final record = find.text(LocaleKeys.sound_picker_record.tr());
        expect(record, findsOneWidget);
        await tester.ensureVisible(record);
        await tester.pump(const Duration(milliseconds: 200));
        expect(own.hitTestable(), findsOneWidget);
        await _save(
          tester,
          key,
          'lock_sounds_${plan}_${sizeName}_${mode.name}',
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
