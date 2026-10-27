// Captures the New token sheet off the device, with a made-up token list and
// no server.
//
//   fvm flutter test tool/capture_new_token.dart
//
// It opens the real sheet over a plain Tokens page, drives it with taps and
// text, and writes a PNG named <scene>_<phone>_<theme>_<scale>x[_reduced].png.
// The path of every file is printed.
//
// Scenes:
//   step1_empty      the name step with nothing typed
//   step1_chip       a quick name chosen
//   step1_taken      a name this topic already uses (the note shows)
//   step1_working    Make token tapped, the request still out
//   step1_refused    the server refused: the sheet stays on step one
//   step2_short      the token shown once, a short name
//   step2_long       the token shown once, a name that fills the 40 characters
//   rise_mid         the sheet part way through its rise
//   swap_mid         the two steps part way through the crossfade
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows.
//
// Developer tool.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/widgets/new_token_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

const _value = 'tk_da393e7d43be4687a1c9f00b27c4e1a1c9';
const _longName = 'payments-service-eu-west-primary-db1';

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _phone = _Phone('390', Size(390, 844), 47, 34);
const _narrow = _Phone('320', Size(320, 640), 24, 0);

/// A repository nothing calls: the usecases below never reach it.
class _NoRepository implements TopicRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Create extends CreateTopicTokenUsecase {
  _Create({this.isRefused = false, this.hold}) : super(_NoRepository());

  final bool isRefused;

  /// When set, the answer waits for it.
  final Completer<void>? hold;

  @override
  Future<AppResult<TopicToken>> call(CreateTopicTokenParams params) async {
    await hold?.future;
    if (isRefused) {
      return const Failure.unexpected(message: 'rate limited').toFailure();
    }
    return Success(
      TopicToken(
        token: _value,
        tokenId: 'tid_new',
        name: params.name ?? 'Token 3',
      ),
    );
  }
}

class _Tokens extends GetTopicTokensUsecase {
  _Tokens() : super(_NoRepository());

  @override
  Future<AppResult<List<TopicTokenInfo>>> call(String topicName) async =>
      const Success([
        TopicTokenInfo(tokenId: 'tid_1', name: 'Token 1'),
        TopicTokenInfo(tokenId: 'tid_2', name: 'Grafana'),
      ]);
}

class _Revoke extends RevokeTopicTokenUsecase {
  _Revoke() : super(_NoRepository());
}

class _Rename extends RenameTopicTokenUsecase {
  _Rename() : super(_NoRepository());
}

class _Scene {
  const _Scene(
    this.name,
    this.run, {
    this.isRefused = false,
    this.holds = false,
  });

  final String name;

  /// Drives the open sheet to the state to capture.
  final Future<void> Function(WidgetTester tester, Completer<void>? hold) run;
  final bool isRefused;
  final bool holds;
}

Future<void> _settle(WidgetTester tester) async {
  // The cursor never stops, so pumpAndSettle would not return.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapMake(WidgetTester tester) async {
  await tester.tap(find.text('Make token'));
  await tester.pump(const Duration(milliseconds: 20));
}

final _scenes = <_Scene>[
  _Scene('step1_empty', (tester, _) async => _settle(tester)),
  _Scene('step1_chip', (tester, _) async {
    await _settle(tester);
    await tester.tap(find.text('Uptime Kuma'));
    await _settle(tester);
  }),
  _Scene('step1_taken', (tester, _) async {
    await _settle(tester);
    await _type(tester, 'Grafana');
    await _settle(tester);
  }),
  _Scene(
    'step1_working',
    (tester, hold) async {
      await _settle(tester);
      await _type(tester, 'cron');
      await _tapMake(tester);
      await _settle(tester);
    },
    holds: true,
  ),
  _Scene(
    'step1_refused',
    (tester, _) async {
      await _settle(tester);
      await _type(tester, 'cron');
      await _tapMake(tester);
      await _settle(tester);
    },
    isRefused: true,
  ),
  _Scene('step2_short', (tester, _) async {
    await _settle(tester);
    await tester.tap(find.text('cron'));
    await tester.pump(const Duration(milliseconds: 50));
    await _tapMake(tester);
    await _settle(tester);
  }),
  _Scene('step2_long', (tester, _) async {
    await _settle(tester);
    await _type(tester, _longName);
    await _tapMake(tester);
    await _settle(tester);
  }),
  _Scene('rise_mid', (tester, _) async {
    await tester.pump(const Duration(milliseconds: 180));
  }),
  _Scene('swap_mid', (tester, _) async {
    await _settle(tester);
    await tester.tap(find.text('cron'));
    await tester.pump(const Duration(milliseconds: 50));
    await _tapMake(tester);
    await tester.pump(const Duration(milliseconds: 100));
  }),
];

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    await loadAppFonts();
  });

  void capture(
    _Scene scene, {
    required _Phone phone,
    required ThemeMode mode,
    double scale = 1,
    bool isReduced = false,
  }) {
    final name =
        '${scene.name}_${phone.name}_${mode.name}_${scale}x'
        '${isReduced ? '_reduced' : ''}';
    if (!_wanted(name)) return;
    testWidgets('capture $name', (tester) async {
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString());
      debugDisableShadows = false;
      const dpr = 2.0;
      tester.view.physicalSize = phone.size * dpr;
      tester.view.devicePixelRatio = dpr;
      tester.view.padding = FakeViewPadding(
        top: phone.top * dpr,
        bottom: phone.bottom * dpr,
      );
      tester.view.viewPadding = tester.view.padding;
      addTearDown(tester.view.reset);

      final hold = scene.holds ? Completer<void>() : null;
      final cubit = TopicTokensCubit(
        _Tokens(),
        _Create(isRefused: scene.isRefused, hold: hold),
        _Revoke(),
        _Rename(),
      );
      await cubit.load('uptime-kuma');

      final boundaryKey = GlobalKey();
      try {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: isReduced,
                textScaler: TextScaler.linear(scale),
              ),
              child: RepaintBoundary(key: boundaryKey, child: child),
            ),
            home: Builder(
              builder: (context) {
                final colors = context.appColors;
                return Scaffold(
                  backgroundColor: colors.canvas,
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
                      child: Text(
                        'Tokens',
                        style: AppTypography.headline(colors.onCanvas),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        unawaited(
          showNewTokenSheet(
            tester.element(find.byType(Scaffold)),
            cubit: cubit,
            readServerUrl: () async => 'https://api.critalarm.app',
          ),
        );
        await tester.pump();
        await scene.run(tester, hold);

        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_out/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          print('SAVED ${file.path}');
        });
        expect(errors, isEmpty, reason: errors.join('\n'));
      } finally {
        hold?.complete();
        await cubit.close();
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
      }
    });
  }

  final byName = {for (final s in _scenes) s.name: s};
  _Scene scene(String name) => byName[name]!;

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final s in _scenes) {
      capture(s, phone: _phone, mode: mode);
    }
  }

  // 320 wide.
  for (final name in [
    'step1_empty',
    'step1_taken',
    'step1_refused',
    'step2_short',
    'step2_long',
  ]) {
    capture(scene(name), phone: _narrow, mode: ThemeMode.light);
  }

  // Large text.
  for (final scale in [1.3, 2.0]) {
    for (final name in ['step1_taken', 'step1_refused', 'step2_long']) {
      capture(scene(name), phone: _phone, mode: ThemeMode.light, scale: scale);
    }
    capture(
      scene('step2_long'),
      phone: _narrow,
      mode: ThemeMode.dark,
      scale: scale,
    );
  }

  // Reduced motion: the settled frame, no rise, no crossfade, no blink.
  for (final name in ['step1_chip', 'step2_short', 'rise_mid', 'swap_mid']) {
    capture(scene(name), phone: _phone, mode: ThemeMode.light, isReduced: true);
  }
}
