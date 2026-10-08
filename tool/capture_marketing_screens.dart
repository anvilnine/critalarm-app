// Renders the screens store listings and social posts show, from the real
// widgets in MOCK mode, at store and social sizes, light and dark.
//
// This is a tool, not a test. It runs only through `make screens`, which
// passes the output folder in SCREENS_OUT. Nothing it writes belongs in this
// repo.
//
// `make screens STORIES=1` draws something else: the ringing and the answered
// alarm screen once per story in `_stories`, at the social size only. It
// writes stories.json and leaves manifest.json alone.
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print, cast_nullable_to_non_nullable

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

/// One output size. `width` and `height` are logical points, so the PNG is
/// `width` x `height` times `ratio`.
typedef _Device = ({
  String id,
  String label,
  double width,
  double height,
  double ratio,
  TargetPlatform platform,
  bool isIphone,
});

// The 1080 x 1920 sizes use a 411 x 731 point phone at 2.625x, the common
// modern Android shape. At 360 x 640 points the alarm screen's buttons cover
// its message card, which no current phone shows.
const List<_Device> _devices = [
  (
    id: 'iphone69',
    label: 'iPhone 6.9 inch (App Store)',
    width: 440,
    height: 956,
    ratio: 3,
    platform: TargetPlatform.iOS,
    isIphone: true,
  ),
  (
    id: 'iphone65',
    label: 'iPhone 6.5 inch (App Store)',
    width: 414,
    height: 896,
    ratio: 3,
    platform: TargetPlatform.iOS,
    isIphone: true,
  ),
  (
    id: 'ipad13',
    label: 'iPad 13 inch (App Store)',
    width: 1032,
    height: 1376,
    ratio: 2,
    platform: TargetPlatform.iOS,
    isIphone: false,
  ),
  (
    id: 'playphone',
    label: 'Android phone (Play)',
    width: 1080 / 2.625,
    height: 1920 / 2.625,
    ratio: 2.625,
    platform: TargetPlatform.android,
    isIphone: false,
  ),
  (
    id: 'social916',
    label: 'Social 9:16 (Reels, TikTok, Shorts)',
    width: 1080 / 2.625,
    height: 1920 / 2.625,
    ratio: 2.625,
    platform: TargetPlatform.iOS,
    isIphone: true,
  ),
];

/// One marketed screen: a stable id content refers to, the route, and the
/// fixture that fills the mock server before it is drawn.
///
/// `after` runs once the screen has settled, for a shot that is not the top
/// of its route. `story` swaps the alarm in the fixture for that story's.
typedef _Screen = ({
  String id,
  String route,
  String fixture,
  Future<void> Function(WidgetTester tester)? after,
  _Story? story,
});

final List<_Screen> _screens = [
  (id: 'home.calm', route: '/', fixture: 'calm', after: null, story: null),
  // An open incident takes home straight to the alarm screen, so the home
  // shot with something on it is the acknowledged one.
  (id: 'home.acked', route: '/', fixture: 'acked', after: null, story: null),
  (
    id: 'alarm.ringing',
    route: '/alarm',
    fixture: 'alarmed',
    after: null,
    story: null,
  ),
  (
    id: 'alarm.acked',
    route: '/incidents/$_ackedId',
    fixture: 'acked',
    after: null,
    story: null,
  ),
  // The alarm this phone sets for itself to try the ring. It is on no
  // server, so the screen draws it from its id alone.
  (
    id: 'alarm.test',
    route: '/incidents/$phoneOnlyTestIncidentId',
    fixture: 'calm',
    after: null,
    story: null,
  ),
  (
    id: 'topic.detail',
    route: '/topics/db-1',
    fixture: 'calm',
    after: null,
    story: null,
  ),
  (
    id: 'topic.critical',
    route: '/topics/db-1',
    fixture: 'calm',
    after: _showCriticalSwitch,
    story: null,
  ),
  (id: 'history', route: '/history', fixture: 'calm', after: null, story: null),
  (
    id: 'settings',
    route: '/settings',
    fixture: 'calm',
    after: null,
    story: null,
  ),
  (
    id: 'paywall.hosted',
    route: _paywallRoute,
    fixture: 'calm',
    after: null,
    story: null,
  ),
];

/// One alarm a video tells the story of: the topic it rings on and the words
/// its sender put in it.
///
/// The title and the message are what a person would type into their own
/// tool, with no product names. A story about something at home uses no
/// technical words, and its one tag is the room. Every story has a tag: the
/// card draws the time, a slash and the tags, and with none the slash is left
/// hanging.
typedef _Story = ({
  String slug,
  String topic,
  String title,
  String message,
  List<String> tags,
});

// Each message fits on one line of the alarm card at the social size, so the
// buttons under it sit in the same place in every story.
const List<_Story> _stories = [
  (
    slug: 'freezer',
    topic: 'freezer',
    title: 'Freezer door is open',
    message: 'It has been open for 10 minutes.',
    tags: ['kitchen'],
  ),
  (
    slug: 'chest-freezer',
    topic: 'chest-freezer',
    title: 'Freezer getting warm',
    message: 'It has been getting warmer for 20 minutes.',
    tags: ['garage'],
  ),
  (
    slug: 'freezer-door',
    topic: 'freezer-door',
    title: 'Freezer door left open',
    message: 'The door has been open for 10 minutes.',
    tags: ['kitchen'],
  ),
  (
    slug: 'sump-pump',
    topic: 'sump-pump',
    title: 'Sump pump stopped',
    message: 'It has not run for an hour. Water is rising.',
    tags: ['basement'],
  ),
  (
    slug: 'payment-webhook',
    topic: 'payment-webhook',
    title: 'Payment webhook went quiet',
    message: 'No payment events for 30 minutes.',
    tags: ['payments'],
  ),
  (
    slug: 'backup-job',
    topic: 'backup-job',
    title: 'Backup failed',
    message: 'The nightly backup stopped with an error.',
    tags: ['backup', 'nightly'],
  ),
  (
    slug: 'backup',
    topic: 'backup',
    title: 'Backup missed its check-in',
    message: 'It was due an hour ago and has not reported.',
    tags: ['backup', 'late'],
  ),
  (
    slug: 'scheduled-job',
    topic: 'scheduled-job',
    title: 'Job missed its check-in',
    message: 'The nightly job is 20 minutes overdue.',
    tags: ['job', 'late'],
  ),
  (
    slug: 'site',
    topic: 'site',
    title: 'Site is down',
    message: 'No answer from the home page for 2 minutes.',
    tags: ['site', 'down'],
  ),
  (
    slug: 'lab-server',
    topic: 'lab-server',
    title: 'Server is down',
    message: 'lab-server has not answered for 3 minutes.',
    tags: ['server', 'down'],
  ),
  (
    slug: 'coding-agent',
    topic: 'coding-agent',
    title: 'Agent is waiting for you',
    message: 'It needs a yes or no before it can go on.',
    tags: ['agent'],
  ),
];

String _storyRingingId(_Story s) => 'inc_story_${s.slug}';
String _storyAckedId(_Story s) => 'inc_story_${s.slug}_acked';

/// Two shots per story, drawn by the same routes and fixtures as
/// `alarm.ringing` and `alarm.acked`.
List<_Screen> _storyScreens() => [
  for (final s in _stories) ...[
    (
      id: 'alarm.ringing.${s.slug}',
      route: '/alarm',
      fixture: 'alarmed',
      after: null,
      story: s,
    ),
    (
      id: 'alarm.acked.${s.slug}',
      route: '/incidents/${_storyAckedId(s)}',
      fixture: 'acked',
      after: null,
      story: s,
    ),
  ],
];

/// The Hero layout selling the hosted plan, listing what this build has.
final String _paywallRoute = paywallLayoutLocation(
  PaywallLayoutId.hero,
  PaywallProduct.hosted,
);

/// Scrolls a topic's page until its Critical switch sits mid screen.
Future<void> _showCriticalSwitch(WidgetTester tester) async {
  final row = find.byWidgetPredicate(
    (w) =>
        w is FeatureGuideAnchor && w.id == FeatureGuideAnchorId.topicCritical,
  );
  await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

final int _nowMs = DateTime.now().millisecondsSinceEpoch;

/// Where the capture's local store lives, set in `setUpAll`.
String _dbPath = '';

const _ringingId = 'inc_mkt_db1_disk';
const _ackedId = 'inc_mkt_db1_acked';

// ---------------------------------------------------------------------------
// Marketing fixture. Topic names a reader recognises from their own servers,
// no placeholder names and no other product's name.
// ---------------------------------------------------------------------------

int _unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

List<Topic> _topics(DateTime now) => [
  Topic(
    name: 'db-1',
    critical: true,
    createdAt: now.subtract(const Duration(days: 41)),
    token: 'tk_mkt_db1',
    tokenId: 'tok_mkt_db1',
    tokenName: 'db-1 cron',
  ),
  Topic(
    name: 'api-gateway',
    critical: true,
    createdAt: now.subtract(const Duration(days: 33)),
    token: 'tk_mkt_api',
    tokenId: 'tok_mkt_api',
    tokenName: 'health check',
  ),
  Topic(
    name: 'nightly-backup',
    createdAt: now.subtract(const Duration(days: 28)),
    token: 'tk_mkt_backup',
    tokenId: 'tok_mkt_backup',
    tokenName: 'backup script',
  ),
  Topic(
    name: 'tls-certs',
    createdAt: now.subtract(const Duration(days: 12)),
    token: 'tk_mkt_tls',
    tokenId: 'tok_mkt_tls',
    tokenName: 'renew job',
  ),
];

/// Closed incidents from the last few days, so history and topic screens
/// have a past.
(List<Incident>, List<Message>) _past(DateTime now) {
  final incidents = <Incident>[];
  final messages = <Message>[];
  void add(
    String id,
    String topic,
    Duration ago,
    Duration toAck,
    String title,
    String body,
  ) {
    final opened = now.subtract(ago);
    final msg = Message(
      id: 'm_$id',
      topic: topic,
      time: _unix(opened),
      title: title,
      message: body,
      priority: 5,
      tags: const ['prod'],
      incidentId: id,
    );
    messages.add(msg);
    incidents.add(
      Incident(
        id: id,
        topic: topic,
        state: IncidentStates.closed,
        openedAt: opened,
        ackedAt: opened.add(toAck),
        closedAt: opened.add(toAck + const Duration(minutes: 9)),
        updatedAt: opened.add(toAck + const Duration(minutes: 9)),
        lastMessageAt: opened,
        messages: [msg],
      ),
    );
  }

  add(
    'inc_mkt_api_5xx',
    'api-gateway',
    const Duration(days: 2, hours: 5),
    const Duration(seconds: 38),
    '5xx rate above 20% on api-gateway',
    'p95 latency 4.1 s, 312 errors in the last minute',
  );
  add(
    'inc_mkt_db1_replica',
    'db-1',
    const Duration(days: 4, hours: 2),
    const Duration(seconds: 51),
    'Replica lag 180 s on db-1',
    'Replication is behind the primary by 180 s',
  );
  add(
    'inc_mkt_api_down',
    'api-gateway',
    const Duration(days: 6, hours: 9),
    const Duration(seconds: 22),
    'api-gateway health check failing',
    'GET /healthz timed out from 3 of 3 probes',
  );

  final backup = Message(
    id: 'm_mkt_backup_ok',
    topic: 'nightly-backup',
    time: _unix(now.subtract(const Duration(hours: 6))),
    title: 'Backup finished',
    message: '412 GB in 38 min, 0 errors',
    tags: const ['white_check_mark'],
  );
  final tls = Message(
    id: 'm_mkt_tls_renew',
    topic: 'tls-certs',
    time: _unix(now.subtract(const Duration(days: 1, hours: 3))),
    title: 'Certificate renewed',
    message: 'Next renewal in 60 days',
    priority: 2,
  );
  messages.addAll([backup, tls]);
  return (incidents, messages);
}

/// A story's fixture: its topic alone, one earlier alarm of the same kind
/// that was answered and closed, and the alarm itself, ringing or answered.
/// The timings match the plain `alarmed` and `acked` fixtures.
void _seedStory(MockServer server, String fixture, _Story story) {
  final now = DateTime.now().toUtc();

  Message message(String id, String incidentId, DateTime at) => Message(
    id: id,
    topic: story.topic,
    time: _unix(at),
    title: story.title,
    message: story.message,
    priority: 5,
    tags: story.tags,
    incidentId: incidentId,
  );

  final earlier = now.subtract(const Duration(days: 9, hours: 4));
  final earlierId = 'inc_story_${story.slug}_past';
  final earlierMsg = message('m_story_${story.slug}_past', earlierId, earlier);
  final incidents = <Incident>[
    Incident(
      id: earlierId,
      topic: story.topic,
      state: IncidentStates.closed,
      openedAt: earlier,
      ackedAt: earlier.add(const Duration(seconds: 47)),
      closedAt: earlier.add(const Duration(minutes: 12)),
      updatedAt: earlier.add(const Duration(minutes: 12)),
      lastMessageAt: earlier,
      messages: [earlierMsg],
    ),
  ];
  final messages = <Message>[earlierMsg];

  switch (fixture) {
    case 'alarmed':
      final opened = now.subtract(const Duration(seconds: 14));
      final id = _storyRingingId(story);
      final msg = message('m_story_${story.slug}', id, opened);
      messages.add(msg);
      incidents.add(
        Incident(
          id: id,
          topic: story.topic,
          openedAt: opened,
          updatedAt: opened,
          lastMessageAt: opened,
          messages: [msg],
        ),
      );
    case 'acked':
      final opened = now.subtract(const Duration(minutes: 3));
      final acked = opened.add(const Duration(seconds: 41));
      final id = _storyAckedId(story);
      final msg = message('m_story_${story.slug}_acked', id, opened);
      messages.add(msg);
      incidents.add(
        Incident(
          id: id,
          topic: story.topic,
          state: IncidentStates.acked,
          openedAt: opened,
          ackedAt: acked,
          updatedAt: acked,
          deskTimerFiresAt: acked.add(const Duration(minutes: 10)),
          lastMessageAt: opened,
          messages: [msg],
        ),
      );
    default:
      throw ArgumentError('A story has no fixture $fixture');
  }

  server.seedState(
    topics: [
      Topic(
        name: story.topic,
        critical: true,
        createdAt: now.subtract(const Duration(days: 41)),
        token: 'tk_story_${story.slug}',
        tokenId: 'tok_story_${story.slug}',
        tokenName: story.topic,
      ),
    ],
    incidents: incidents,
    messages: messages,
  );
}

void _seed(MockServer server, String fixture, {_Story? story}) {
  server.reset();
  if (story != null) {
    _seedStory(server, fixture, story);
    return;
  }
  final now = DateTime.now().toUtc();
  final (past, pastMessages) = _past(now);
  final incidents = <Incident>[...past];
  final messages = <Message>[...pastMessages];

  switch (fixture) {
    case 'alarmed':
      // Opened 14 s ago, so the ringing line reads about "Ringing 14 s."
      final opened = now.subtract(const Duration(seconds: 14));
      final msg = Message(
        id: 'm_mkt_db1_disk',
        topic: 'db-1',
        time: _unix(opened),
        title: 'Disk full on db-1',
        message: '/var/lib/postgresql is at 100%. Writes are failing.',
        priority: 5,
        tags: const ['postgres', 'disk'],
        incidentId: _ringingId,
      );
      messages.add(msg);
      incidents.add(
        Incident(
          id: _ringingId,
          topic: 'db-1',
          openedAt: opened,
          updatedAt: opened,
          lastMessageAt: opened,
          messages: [msg],
        ),
      );
    case 'acked':
      final opened = now.subtract(const Duration(minutes: 3));
      final acked = opened.add(const Duration(seconds: 41));
      final msg = Message(
        id: 'm_mkt_db1_acked',
        topic: 'db-1',
        time: _unix(opened),
        title: 'Disk full on db-1',
        message: '/var/lib/postgresql is at 100%. Writes are failing.',
        priority: 5,
        tags: const ['postgres', 'disk'],
        incidentId: _ackedId,
      );
      messages.add(msg);
      incidents.add(
        Incident(
          id: _ackedId,
          topic: 'db-1',
          state: IncidentStates.acked,
          openedAt: opened,
          ackedAt: acked,
          updatedAt: acked,
          deskTimerFiresAt: acked.add(const Duration(minutes: 10)),
          lastMessageAt: opened,
          messages: [msg],
        ),
      );
    case 'calm':
      break;
    default:
      throw ArgumentError('Unknown fixture $fixture');
  }

  messages.sort((a, b) => a.time.compareTo(b.time));
  server.seedState(
    topics: _topics(now),
    incidents: incidents,
    messages: messages,
  );
}

/// Reports every permission the app checks as granted.
class _AllGranted implements DevicePermissionsRepository {
  _AllGranted(this._real);

  final DevicePermissionsRepository _real;

  @override
  Future<AppResult<List<DevicePermissionItem>>> getPermissions() async {
    final result = await _real.getPermissions();
    final items = result.getOrNull() ?? const <DevicePermissionItem>[];
    return [
      for (final item in items)
        item.copyWith(status: DevicePermissionStatus.granted),
    ].toSuccess();
  }

  @override
  Future<AppResult<DevicePermissionStatus>> checkPermission(
    DevicePermissionType type,
  ) async => DevicePermissionStatus.granted.toSuccess();

  @override
  Future<AppResult<bool>> openPermissionSettings(
    DevicePermissionType type,
  ) async => false.toSuccess();

  @override
  Future<AppResult<bool>> openAppSettings() async => false.toSuccess();
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

String _env(String key, String fallback) {
  final v = Platform.environment[key];
  return v == null || v.isEmpty ? fallback : v;
}

String _appVersion() {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
  return line.substring('version:'.length).trim();
}

void main() {
  final outDir = Directory(
    _env('SCREENS_OUT', '../critalarm-content-pipeline/ui-snapshots'),
  );
  final only = _env('SCREENS_ONLY', '');
  // Stories are for videos, so they are drawn at the social size and no
  // other, whatever SCREENS_DEVICES says.
  final storiesOnly = const {'1', 'true'}.contains(_env('SCREENS_STORIES', ''));
  final onlyDevices = storiesOnly ? 'social916' : _env('SCREENS_DEVICES', '');
  final screens = storiesOnly ? _storyScreens() : _screens;
  final entries = <Map<String, Object?>>[];

  setUpAll(() async {
    // After the translations: loading them resets the mock preferences.
    await loadTestTranslations();
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://api.critalarm.app',
      'admin_token': 'adm_marketing',
      // A registered device, so history has a plan to read its window from.
      'device_id': 'dev_marketing',
      'device_token': 'dt_marketing',
      'account_id': 'acc_marketing',
      'account_tier': 'free',
      'account_caps': '{"history_days": 7}',
      // Nudges a store shot should not carry: the sign-in reminder and the
      // review, consent and feedback asks all count as just answered.
      'home_prompt_account_dismissed_at': _nowMs,
      'home_prompt_consent_asked_at': _nowMs,
      'home_prompt_review_asked_at': _nowMs,
      'home_prompt_feedback_asked_at': _nowMs,
    });
    // The phone's own incident store, on a real SQLite file in a temp
    // folder. Without it history has nothing to list.
    final docs = Directory.systemTemp.createTempSync('critalarm_screens_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    // The alarm channel has no native side here. An iPhone answers as one
    // that can set a real alarm (iOS 26 or later) and has said yes to it.
    // Android has no such permission and answers nothing, as it does on a
    // phone.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(AlarmHost.channelName),
          (call) async =>
              call.method == 'authorizationStatus' &&
                  defaultTargetPlatform == TargetPlatform.iOS
              ? AlarmAuthorization.authorized.name
              : null,
        );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    _dbPath = p.join(docs.path, LocalStore.fileName);
    // MOCK on, whatever the build defines: every screen reads the fixture,
    // never a real server.
    await configureDependencies(useMockApi: true);
    // A test binding has no permission plugins, so every permission reads as
    // off and the home screen leads with a "cannot reach you" banner. A store
    // shot shows a phone that is set up.
    final real = getIt<DevicePermissionsRepository>();
    getIt
      ..unregister<DevicePermissionsRepository>()
      ..registerSingleton<DevicePermissionsRepository>(_AllGranted(real))
      // The store is not there to ask, so the paywall draws the made-up plans
      // a build without a store draws. Its amounts are not real prices.
      ..unregister<PaywallBuyCubit>()
      ..registerFactoryParam<
        PaywallBuyCubit,
        PaywallProduct,
        PaywallBuyStatus?
      >((product, status) => DemoPaywallBuyCubit(product, startAs: status));
    // Settings leads with the answer of the phone's own checks. Its row asks
    // for them when it is drawn, and under a test clock that read never comes
    // back, so the row would say "Checking". Read them once here, in real
    // time: the row then shows the answer it already holds.
    await getIt<ReliabilityCubit>().refresh();
    await loadAppFonts();
  });

  tearDownAll(() {
    if (entries.isEmpty) return;
    entries.sort(
      (a, b) => (a['file'] as String).compareTo(b['file'] as String),
    );
    final manifest = {
      'app_version': _appVersion(),
      'app_commit': _env('GIT_SHA', 'unknown'),
      'app_commit_dirty': _env('GIT_DIRTY', 'false') == 'true',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'generator': 'critalarm-app tool/capture_marketing_screens.dart',
      'locale': 'en',
      'devices': {
        for (final d in _devices)
          d.id: {
            'label': d.label,
            'platform': d.platform.name,
            'points': [d.width, d.height],
            'pixel_ratio': d.ratio,
            'pixels': [
              (d.width * d.ratio).round(),
              (d.height * d.ratio).round(),
            ],
          },
      },
      if (storiesOnly)
        'stories': [
          for (final s in _stories)
            {
              'slug': s.slug,
              'topic': s.topic,
              'title': s.title,
              'message': s.message,
              'tags': s.tags,
            },
        ],
      'screens': entries,
    };
    final name = storiesOnly ? 'stories.json' : 'manifest.json';
    File('${outDir.path}/$name').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
    print('Wrote ${entries.length} screens to ${outDir.path}');
  });

  for (final device in _devices) {
    if (onlyDevices.isNotEmpty && !onlyDevices.split(',').contains(device.id)) {
      continue;
    }
    for (final theme in const [ThemeMode.light, ThemeMode.dark]) {
      for (final screen in screens) {
        if (only.isNotEmpty && !only.split(',').contains(screen.id)) continue;
        final rel = '${device.id}/${theme.name}/${screen.id}.png';
        testWidgets('screen $rel', (tester) async {
          _seed(getIt<MockServer>(), screen.fixture, story: screen.story);
          // The store keeps what the last capture synced. Empty it so this
          // screen sees only its own fixture. sqflite hands back the open
          // connection for the same path.
          await tester.runAsync(() async {
            final db = await databaseFactory.openDatabase(_dbPath);
            await db.delete('messages');
            await db.delete('incidents');
          });
          debugDefaultTargetPlatformOverride = device.platform;
          // The app works out its platform once, at launch. Say it again for
          // this size, or an iPhone shot names the other platform's store.
          getIt
            ..unregister<PlatformCapabilities>()
            ..registerSingleton<PlatformCapabilities>(
              PlatformCapabilities(isWeb: false, platform: device.platform),
            );

          tester.view.physicalSize = Size(
            device.width * device.ratio,
            device.height * device.ratio,
          );
          tester.view.devicePixelRatio = device.ratio;
          addTearDown(tester.view.reset);

          final boundary = GlobalKey();
          final router = buildRouter(initialLocation: screen.route);

          // The shared cubits outlive one capture, so they reload from the
          // freshly seeded mock before the screen reads them.
          await tester.runAsync(() async {
            await getIt<TopicsCubit>().refresh();
            await getIt<IncidentsCubit>().refresh(full: true);
          });

          // The same cubits the app provides above its router (app.dart).
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider<IncidentsCubit>.value(
                  value: getIt<IncidentsCubit>(),
                ),
                BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
                BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
                BlocProvider<AppearanceCubit>.value(
                  value: getIt<AppearanceCubit>(),
                ),
              ],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: buildLightTheme(),
                darkTheme: buildDarkTheme(),
                themeMode: theme,
                routerConfig: router,
                builder: (context, child) => RepaintBoundary(
                  key: boundary,
                  child: AppDeviceScope(
                    isIphone: device.isIphone,
                    child: AppAmbientShell(
                      router: router,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          );

          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 300));
            // Cubits that await a platform channel or the mock server need
            // real time, not pumped time.
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
          }
          await tester.pump(const Duration(seconds: 1));
          await screen.after?.call(tester);

          // A screen that threw while it was laid out or painted is not the
          // app as a user sees it. It gets no file and no manifest entry,
          // and the run fails so the gap is noticed.
          final broken = tester.takeException();
          if (broken != null) {
            debugDefaultTargetPlatformOverride = null;
            final why = '$broken'.split('\n').first;
            print('skipped $rel: $why');
            fail('$rel did not draw cleanly: $why');
          }

          // Where a video taps on a ringing story shot: the middle of the
          // button that stops the ring, as a fraction of the frame.
          final story = screen.story;
          List<double>? tapPoint;
          if (story != null && screen.fixture == 'alarmed') {
            final c = tester.getCenter(
              find.text('critical_alarm.acknowledge_button'.tr()),
            );
            tapPoint = [
              double.parse((c.dx / device.width).toStringAsFixed(4)),
              double.parse((c.dy / device.height).toStringAsFixed(4)),
            ];
          }

          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: device.ratio);
            final data = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final bytes = data!.buffer.asUint8List();
            final file = File('${outDir.path}/$rel');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes);
            entries.add({
              'id': screen.id,
              'route': screen.route,
              'fixture': screen.fixture,
              'device': device.id,
              'platform': device.platform.name,
              'theme': theme.name,
              'locale': 'en',
              'size': [image.width, image.height],
              'file': rel,
              'sha256': sha256.convert(bytes).toString(),
              if (story != null) 'story': story.slug,
              'im_up_tap_point': ?tapPoint,
            });
            print('captured $rel ${image.width}x${image.height}');
          });

          // A screen can start a timer as it closes (the paywall's closing
          // haptic). Take the tree down and let those run out, or the test
          // ends with one pending.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));

          debugDefaultTargetPlatformOverride = null;
        });
      }
    }
  }
}
