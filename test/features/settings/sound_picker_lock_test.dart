import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_sheet_page.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sound picker as the app builds it (real router, real access layer,
/// mock API), on a phone that holds no plan and has one own sound saved as
/// its default from when Pro was held.
void main() {
  const ownSound = AlarmSound(
    id: 'user_capture',
    name: 'My recording',
    source: AlarmSoundSource.user,
    path: '/sounds/user_capture.caf',
    duration: Duration(seconds: 4),
  );

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final soundCalls = <String>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  setUp(() {
    soundCalls.clear();
    // A phone that can bring in a sound, so Pick a file and Record show.
    messenger.setMockMethodCallHandler(
      const MethodChannel(SoundHost.channelName),
      (call) async {
        soundCalls.add(call.method);
        return switch (call.method) {
          'capabilities' => <String, Object?>{'can_import_sounds': true},
          'readPeaks' => <double>[],
          _ => true,
        };
      },
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel(SoundHost.channelName),
      null,
    );
  });

  /// The page on top, a pushed one included.
  String path(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// Lets reads that go through real I/O land, then draws.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  AppRadioRow rowOf(WidgetTester tester, String title) => tester.widget(
    find.byWidgetPredicate((w) => w is AppRadioRow && w.title == title),
  );

  Finder rowFinder(String title) =>
      find.byWidgetPredicate((w) => w is AppRadioRow && w.title == title);

  testWidgets('nothing held, one own sound saved: the own sound is locked, '
      'the mark is on the sound that rings, and every way in opens the '
      'paywall', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final sounds = getIt<AlarmSoundRepository>();
    await tester.runAsync(() async {
      await sounds.addUserSound(ownSound);
      await sounds.setDefaultSoundId(ownSound.id);
    });
    addTearDown(() => sounds.deleteUserSound(ownSound.id));

    // What the test stands on: once the plan is read, nothing is held and
    // own sounds are locked.
    final access = getIt<FeatureAccess>();
    await tester.runAsync(() => access.ready);
    expect(
      access.decide(AppFeature.ownSounds),
      isA<FeatureLocked>(),
      reason: 'the test needs a phone that holds nothing',
    );

    final router = buildRouter(initialLocation: '/sounds');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: getIt<ThemeCubit>(),
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp.router(
            theme: buildLightTheme(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    final own = rowFinder(ownSound.name);
    await tester.scrollUntilVisible(
      own,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);

    // The badge is on the own sound's row, and the row is not marked.
    expect(
      find.descendant(of: own, matching: find.byType(ProBadge)),
      findsOneWidget,
      reason: 'the locked own sound carries the plan badge',
    );
    expect(rowOf(tester, ownSound.name).selected, isFalse);

    // The mark is on the sound that will ring in its place.
    const ringing = 'Classic siren';
    expect(BundledSounds.fallbackId, 'classic_siren');
    expect(rowOf(tester, ringing).selected, isTrue);
    expect(find.text('Use $ringing'), findsOneWidget);
    expect(find.text('Use ${ownSound.name}'), findsNothing);

    Future<void> opensPaywall(Finder target, String what) async {
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await settle(tester);
      expect(path(router), proPackSheetPath, reason: '$what opens the paywall');
      router.pop();
      await settle(tester);
      expect(path(router), '/sounds');
    }

    await opensPaywall(find.text('Pick a file'), 'Pick a file');
    await opensPaywall(find.text('Record'), 'Record');
    await opensPaywall(find.text(ownSound.name), 'a tap on the own sound');

    // Nothing was picked, recorded or saved on the way.
    final saved = await tester.runAsync(sounds.getAssignments);
    expect(saved!.getOrNull()!.defaultSoundId, ownSound.id);
    expect(soundCalls, isNot(contains('importSound')));
  });
}
