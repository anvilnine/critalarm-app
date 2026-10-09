// Captures the Tokens page off the device, with made-up tokens and no server.
//
//   fvm flutter test tool/capture_tokens_page.dart
//
// It builds the real page around a cubit whose usecases are fakes, drives it
// with taps and text, and writes a PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced].png. The path of every file is
// printed.
//
// Scenes:
//   empty         no tokens (cannot happen in the app, drawn without a crash)
//   one           one token
//   two           two tokens, as the board draws them
//   six           six tokens
//   long          long names, one with no spaces
//   loading       the list request still out
//   failed        the list request failed, with its retry button
//   refused       a rename the server refused, the line under the list
//   edit          a row tapped, the edit sheet over the page
//   new_sheet     the New token button tapped, the sheet over the page
//   curl          opened with the curl flow: the sheet with Script in the name
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
import 'package:critalarm/features/topics/presentation/topic_tokens_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

const _topic = 'uptime-kuma';

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

class _Tokens extends GetTopicTokensUsecase {
  _Tokens(this.tokens, {this.isFailing = false, this.hold})
    : super(_NoRepository());

  final List<TopicTokenInfo> tokens;
  final bool isFailing;

  /// When set, the answer waits for it.
  final Completer<void>? hold;

  @override
  Future<AppResult<List<TopicTokenInfo>>> call(String topicName) async {
    await hold?.future;
    if (isFailing) {
      return const Failure.unexpected(message: 'offline').toFailure();
    }
    return Success(tokens);
  }
}

class _Create extends CreateTopicTokenUsecase {
  _Create() : super(_NoRepository());

  @override
  Future<AppResult<TopicToken>> call(CreateTopicTokenParams params) async =>
      Success(
        TopicToken(
          token: 'tk_da393e7d43be4687a1c9f00b27c4e1a1c9',
          tokenId: 'tid_new',
          name: params.name ?? 'Token 3',
        ),
      );
}

class _Revoke extends RevokeTopicTokenUsecase {
  _Revoke() : super(_NoRepository());
}

class _Rename extends RenameTopicTokenUsecase {
  _Rename() : super(_NoRepository());

  @override
  Future<AppResult<TopicTokenInfo>> call(RenameTopicTokenParams params) async =>
      const Failure.unexpected(message: 'rate limited').toFailure();
}

DateTime _at(int daysAgo, int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
}

List<TopicTokenInfo> _two() => [
  TopicTokenInfo(
    tokenId: 'tid_1',
    name: 'Uptime Kuma',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  TopicTokenInfo(tokenId: 'tid_2', name: 'Token 2', createdAt: _at(0, 0, 1)),
];

List<TopicTokenInfo> _six() => [
  ..._two(),
  TopicTokenInfo(tokenId: 'tid_3', name: 'Grafana', createdAt: _at(3, 9, 30)),
  TopicTokenInfo(tokenId: 'tid_4', name: 'cron', createdAt: _at(40, 9, 30)),
  TopicTokenInfo(
    tokenId: 'tid_5',
    name: 'Backup job',
    createdAt: _at(400, 9, 30),
  ),
  const TopicTokenInfo(tokenId: 'tid_6', name: 'Just made'),
];

List<TopicTokenInfo> _long() => [
  TopicTokenInfo(
    tokenId: 'tid_1',
    name: 'payments-service-eu-west-primary-db1',
    createdAt: _at(1, 8, 0),
  ),
  TopicTokenInfo(
    tokenId: 'tid_2',
    name: 'Nightly backup of the shared office file server',
    createdAt: _at(0, 0, 1),
  ),
  TopicTokenInfo(
    tokenId: 'tid_3',
    name: 'Averyveryveryverylongnamewithnospacesatalltoseewhathappens',
    createdAt: _at(9, 8, 0),
  ),
];

class _Scene {
  const _Scene(
    this.name, {
    this.tokens = const [],
    this.run,
    this.isFailing = false,
    this.holds = false,
    this.startCurlFlow = false,
  });

  final String name;
  final List<TopicTokenInfo> tokens;

  /// Drives the page to the state to capture. Null captures it as built.
  final Future<void> Function(WidgetTester tester)? run;
  final bool isFailing;
  final bool holds;
  final bool startCurlFlow;
}

Future<void> _settle(WidgetTester tester) async {
  // The cursor and the skeleton never stop, so pumpAndSettle would not return.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _scenes = <_Scene>[
  const _Scene('empty'),
  _Scene('one', tokens: [_two().first]),
  _Scene('two', tokens: _two()),
  _Scene('six', tokens: _six()),
  _Scene('long', tokens: _long()),
  const _Scene('loading', holds: true),
  const _Scene('failed', isFailing: true),
  _Scene(
    'refused',
    tokens: _two(),
    run: (tester) async {
      await _settle(tester);
      await tester.tap(find.text('Token 2'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Save'));
      await _settle(tester);
    },
  ),
  _Scene(
    'edit',
    tokens: _two(),
    run: (tester) async {
      await _settle(tester);
      await tester.tap(find.text('Uptime Kuma'));
      await _settle(tester);
    },
  ),
  _Scene(
    'new_sheet',
    tokens: _two(),
    run: (tester) async {
      await _settle(tester);
      await tester.tap(find.text('New token'));
      await _settle(tester);
    },
  ),
  _Scene('curl', tokens: _two(), startCurlFlow: true),
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
        _Tokens(scene.tokens, isFailing: scene.isFailing, hold: hold),
        _Create(),
        _Revoke(),
        _Rename(),
      );
      final boundaryKey = GlobalKey();
      try {
        final loading = cubit.load(_topic);
        if (hold == null) await loading;
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
              child: RepaintBoundary(
                key: boundaryKey,
                // The canvas is the shell's in the app.
                child: AmbientScope(
                  child: ColoredBox(
                    color: Theme.of(context).extension<AppColors>()!.canvas,
                    child: child,
                  ),
                ),
              ),
            ),
            home: TopicTokensScreen(
              topicName: _topic,
              cubit: cubit,
              startCurlFlow: scene.startCurlFlow,
              readServerUrl: () async => 'https://api.critalarm.app',
            ),
          ),
        );
        await tester.pump();
        await (scene.run?.call(tester) ?? _settle(tester));

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
  for (final s in _scenes) {
    capture(s, phone: _narrow, mode: ThemeMode.light);
  }

  // Large text.
  for (final scale in [1.3, 2.0]) {
    for (final name in [
      'two',
      'long',
      'six',
      'failed',
      'refused',
      'new_sheet',
    ]) {
      capture(scene(name), phone: _phone, mode: ThemeMode.light, scale: scale);
    }
    capture(scene('long'), phone: _narrow, mode: ThemeMode.dark, scale: scale);
  }

  // Reduced motion: the settled frame, no skeleton shimmer, no fades.
  for (final name in ['two', 'loading', 'new_sheet', 'curl']) {
    capture(scene(name), phone: _phone, mode: ThemeMode.light, isReduced: true);
  }
}
