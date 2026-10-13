// Captures the Pro row in the Settings plan section, off the device, on the
// mock server and the developer plan switches.
//
//   fvm flutter test tool/capture_settings_pro_row.dart \
//     --dart-define=SKIP_PAYWALL=true --dart-define=OUT=<folder>
//
// Each shot boots the app's dependencies with the holdings the scene needs,
// opens Settings, scrolls the Plan section to the top third of the screen and
// writes <scene>_<phone>_<theme>_<scale>x.png. The path of every file is
// printed.
//
// Scenes (Hosted, Pro, server):
//   pro_owned        Free, Pro held
//   pro_checking     Free, Pro pending
//   pro_not_owned    Free, Pro not held: the line and "See Pro"
//   pro_unknown      Free, Pro unreadable: no mark, the line and "See Pro"
//   hosted_pro_none  Hosted held, Pro not held
//   own_pro_none     an own server, Pro not held
//
// Phones: 390 by 844 light and dark at 1.0 and light at 2.0, and 320 by 568
// light and dark at 1.0.
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default
//                                build/settings_pro_row)
//   --dart-define=ONLY=<part>,<part>
//                                only the files whose name has one of these
//                                parts
//
// A capture fails when anything overflows. Nothing here plays motion.
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/settings_pro_row',
);
const _only = String.fromEnvironment('ONLY');

class _Scene {
  const _Scene(this.name, this.prefs);

  final String name;

  /// The developer switches the scene starts with.
  final Map<String, Object> prefs;
}

const _scenes = <_Scene>[
  _Scene('pro_owned', {
    'dev.access.hosted': 'notHeld',
    'dev.access.pro': 'held',
    'dev.access.server': 'cloud',
  }),
  _Scene('pro_checking', {
    'dev.access.hosted': 'notHeld',
    'dev.access.pro': 'pending',
    'dev.access.server': 'cloud',
  }),
  _Scene('pro_not_owned', {
    'dev.access.hosted': 'notHeld',
    'dev.access.pro': 'notHeld',
    'dev.access.server': 'cloud',
  }),
  _Scene('pro_unknown', {
    'dev.access.hosted': 'notHeld',
    'dev.access.pro': 'unknown',
    'dev.access.server': 'cloud',
  }),
  _Scene('hosted_pro_none', {
    'dev.access.hosted': 'held',
    'dev.access.pro': 'notHeld',
    'dev.access.server': 'cloud',
  }),
  _Scene('own_pro_none', {
    'dev.access.hosted': 'notHeld',
    'dev.access.pro': 'notHeld',
    'dev.access.server': 'ownServer',
  }),
];

const _variants = <(String, Size, ThemeMode, double)>[
  ('390x844', Size(390, 844), ThemeMode.light, 1.0),
  ('390x844', Size(390, 844), ThemeMode.dark, 1.0),
  ('390x844', Size(390, 844), ThemeMode.light, 2.0),
  ('320x568', Size(320, 568), ThemeMode.light, 1.0),
  ('320x568', Size(320, 568), ThemeMode.dark, 1.0),
];

Future<void> _real(WidgetTester tester, [int ms = 300]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

Future<void> _boot(_Scene scene) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'api.critalarm.app',
    'admin_token': 'adm_demo_token',
    'home_widgets_card_seen': true,
    'setup_checklist_done': true,
    'tour_guides_seen': '["topics","topic","settings","history"]',
    'has_completed_showcase_tour': true,
    ...scene.prefs,
  });
  await getIt.reset();
  await configureDependencies(useMockApi: true);
  getIt<MockServer>().seedCalm();
  // The Settings plan section reads the saved session for the server mode,
  // not the developer switch, so an own-server scene saves one.
  if (scene.prefs['dev.access.server'] == 'ownServer') {
    await getIt<ApiSessionStore>().write(
      ApiSession(
        baseUri: Uri.parse('https://alerts.example.net'),
        relayUri: Uri.parse('https://relay.critalarm.app'),
        mode: ServerMode.selfhosted,
        managementCredential: 'admin_demo_token',
      ),
    );
  }
  // A registered account, so the plan card reads Free or Hosted as it does on
  // a phone that has been used, not "Plan unavailable".
  await getIt<DeviceIdentityStore>().saveRegistration(
    deviceToken: 'dev_capture_token',
    accountId: 'acc_capture',
    tier: scene.prefs['dev.access.hosted'] == 'held' ? 'pro' : 'free',
    caps: scene.prefs['dev.access.hosted'] == 'held'
        ? const AccountCaps()
        : AccountCaps.free,
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _real(tester, 400);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _real(tester, 200);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Puts the Plan section's label in the top third of the screen, so the plan
/// card and the Pro row under it are both in view.
Future<void> _showPlan(WidgetTester tester) async {
  final label = find.text(LocaleKeys.settings_plan_header.tr());
  expect(label, findsWidgets);
  await Scrollable.ensureVisible(
    tester.element(label.first),
    alignment: 0.2,
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<GlobalKey> _open(
  WidgetTester tester,
  _Scene scene, {
  required Size phone,
  required ThemeMode mode,
  required double scale,
}) async {
  await tester.runAsync(() => _boot(scene));
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  final router = buildRouter();
  await tester.pumpWidget(
    BlocProvider<ThemeCubit>.value(
      value: getIt<ThemeCubit>(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(
            key: key,
            child: AppAmbientShell(
              router: router,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
  router.go('/settings');
  await _settle(tester);
  await tester.pump(const Duration(seconds: 2));
  await _showPlan(tester);
  await _frames(tester);
  return key;
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey key,
  String name,
  List<String> errors,
) => tester.runAsync(() async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${errors.isEmpty ? 'FIT ' : 'BAD '} ${file.path}');
});

/// The one layout assertion that reduce motion trips: an `AnimatedSize` with
/// a zero duration marks itself dirty while it lays out when its child
/// changes size. It exists in a debug build only.
bool _isKnownReduceMotionAssert(String error) =>
    error.contains('RenderAnimatedSize was mutated in its own performLayout');

void main() {
  final onlyParts = _only.split(',').where((p) => p.isNotEmpty).toList();

  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  for (final scene in _scenes) {
    for (final (phoneName, phone, mode, scale) in _variants) {
      final name = '${scene.name}_${phoneName}_${mode.name}_${scale}x';
      if (onlyParts.isNotEmpty && !onlyParts.any(name.contains)) continue;
      testWidgets('capture $name', (tester) async {
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (d) {
          final text = d.exceptionAsString();
          if (_isKnownReduceMotionAssert(text)) {
            print('  NOTE: $text');
            return;
          }
          errors.add(d.toString());
        };
        addTearDown(() => FlutterError.onError = oldHandler);

        final key = await _open(
          tester,
          scene,
          phone: phone,
          mode: mode,
          scale: scale,
        );
        await _save(tester, key, name, errors);
        // Unmount and let the clocks run out, so nothing is left pending.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        for (final e in errors) {
          print('  ERROR: ${e.split('\n').take(40).join('\n')}');
        }
        expect(errors, isEmpty, reason: 'overflow or build error in $name');
      });
    }
  }
}
