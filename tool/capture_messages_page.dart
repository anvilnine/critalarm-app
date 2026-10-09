// Captures a topic's full messages page off the device, with made-up messages
// and incidents and no server.
//
//   fvm flutter test tool/capture_messages_page.dart \
//     --dart-define=OUT=.scratch-a232
//
// It builds the real page around a topic cubit that holds a made-up state and
// an incident list that holds made-up incidents, and writes a PNG named
// <scene>_<phone>_<theme>_<scale>x[_reduced][_<frame>].png. The path of
// every file is printed.
//
// Scenes:
//   board      the four messages the board draws, one of them with a ring line
//   one        a single message
//   many       twelve days, every way an alarm can end, a repeat message
//   long       long titles and bodies, many tags, a long topic name
//   loading    the messages still being read
//   empty      nothing sent yet
//   failed     the messages could not be read, with the retry button
//
// Frames (on top of the settled one):
//   scrolled   the list moved up until the header is under the bar
//   full       the whole page on one tall screen
//   grow       200 ms after the page appears, the bars part way up
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default build/captures)
//   --dart-define=ONLY=a,b       only files whose name has one of these parts
//
// A capture fails when anything overflows.
//
// Developer tool.
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/topic_messages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

const _topic = 'uptime-kuma';
const _longTopic = 'payments-service-eu-west-primary-db-replica-lag';

class _Phone {
  const _Phone(this.name, this.size, this.top, this.bottom);

  final String name;
  final Size size;
  final double top;
  final double bottom;
}

const _phone = _Phone('390', Size(390, 844), 47, 34);
const _narrow = _Phone('320', Size(320, 640), 24, 0);
const _tall = _Phone('390', Size(390, 2400), 47, 34);

/// An incident list that holds exactly what the scene gives it.
class _Incidents extends IncidentsCubit {
  _Incidents(List<Incident> incidents) : super(getIt<GetIncidentsUsecase>()) {
    emit(IncidentsState(status: AppDataStatus.ready, incidents: incidents));
  }
}

/// How the alarm for a message ended.
class _Ring {
  const _Ring(this.state, {this.seconds});

  final String state;

  /// How long after it opened the incident stopped, or null for neither.
  final int? seconds;
}

class _Msg {
  const _Msg(
    this.daysAgo,
    this.hour,
    this.minute,
    this.title,
    this.body, {
    this.tags = const [],
    this.isHigh = false,
    this.ring,
    this.incident,
  });

  final int daysAgo;
  final int hour;
  final int minute;
  final String title;
  final String body;
  final List<String> tags;
  final bool isHigh;
  final _Ring? ring;

  /// Messages that share this id belong to one incident.
  final String? incident;
}

DateTime _at(_Msg m, DateTime now) =>
    DateTime(now.year, now.month, now.day - m.daysAgo, m.hour, m.minute);

class _Scene {
  const _Scene(
    this.name, {
    this.messages = const [],
    this.topic = _topic,
    this.status = TopicDetailStatus.success,
    this.error,
  });

  final String name;
  final List<_Msg> messages;
  final String topic;
  final TopicDetailStatus status;
  final String? error;
}

const _board = <_Msg>[
  _Msg(
    0,
    18,
    10,
    'Crit Alarm test',
    'triggered',
    ring: _Ring('acked', seconds: 12),
  ),
  _Msg(
    0,
    11,
    18,
    'Sample Notification',
    'Demo notification title for App Store',
    tags: ['postgres', 'db-1'],
  ),
  _Msg(1, 0, 45, 'uptime-kuma', 'hello from my server'),
  _Msg(
    1,
    0,
    42,
    'Down',
    '[api.example.com] is down. Connection timed out after 10 s.',
    ring: _Ring('acked', seconds: 180),
  ),
];

const _many = <_Msg>[
  _Msg(0, 9, 5, 'Disk almost full', '/var is at 94%', isHigh: true),
  _Msg(
    0,
    7,
    58,
    'Down',
    '[api.example.com] is down',
    ring: _Ring('open'),
    incident: 'a',
  ),
  _Msg(
    0,
    7,
    59,
    'Down',
    '[api.example.com] is still down',
    ring: _Ring('open'),
    incident: 'a',
  ),
  _Msg(
    1,
    23,
    40,
    'Backup finished',
    'nightly, 41 GB',
    tags: ['backup', 'nas'],
  ),
  _Msg(
    1,
    3,
    12,
    'Database unreachable',
    'db-1 does not answer',
    ring: _Ring('expired', seconds: 600),
  ),
  _Msg(
    2,
    14,
    2,
    'Certificate expires soon',
    'api.example.com in 9 days',
    ring: _Ring('closed', seconds: 95),
  ),
  _Msg(
    2,
    9,
    30,
    'Deploy done',
    'v2.14.1 is live',
    tags: ['deploy'],
  ),
  _Msg(
    3,
    22,
    15,
    'Queue backed up',
    'jobs waiting: 4,210',
    ring: _Ring('acked', seconds: 47),
  ),
  _Msg(
    5,
    6,
    0,
    'Heartbeat',
    'cron ok',
  ),
  _Msg(
    8,
    12,
    30,
    'Restarted',
    'worker-3 restarted',
  ),
  _Msg(
    8,
    12,
    29,
    'Down',
    'worker-3 does not answer',
    ring: _Ring('acked', seconds: 2700),
  ),
  _Msg(
    300,
    8,
    0,
    'Welcome',
    'First message on this topic',
  ),
];

const _long = <_Msg>[
  _Msg(
    0,
    18,
    10,
    'Replication lag on payments-service-eu-west-primary-db-replica has been '
        'above the limit for more than five minutes and is still growing',
    'The replica is 412 seconds behind. Writes to the primary are not '
        'affected yet, but reads that go to the replica return stale rows '
        'and the nightly export will be wrong if this carries on. Check the '
        'network link between the two regions first, then the long running '
        'queries on the replica, then the disk. If none of those explain it, '
        'fail over before the export starts at midnight so the numbers are '
        'right.',
    tags: [
      'postgres',
      'db-1',
      'eu-west-1',
      'replication',
      'payments',
      'production',
      'high-memory',
      'primary-replica',
    ],
    ring: _Ring('acked', seconds: 4000),
  ),
  _Msg(
    0,
    11,
    18,
    'Averyveryveryverylongtitlewithnospacesatalltoseewhathappens',
    'Averyveryveryverylongbodywithnospacesatalltoseewhathappenswhenthereisno'
        'room',
  ),
];

final _scenes = <_Scene>[
  const _Scene('board', messages: _board),
  const _Scene('one', messages: [_Msg(0, 9, 0, 'Hello', 'from my server')]),
  const _Scene('many', messages: _many),
  const _Scene('long', messages: _long, topic: _longTopic),
  const _Scene('loading', status: TopicDetailStatus.loading),
  const _Scene('empty'),
  const _Scene(
    'failed',
    status: TopicDetailStatus.failure,
    error: "Could not read this topic's messages.",
  ),
];

/// The scene's messages as the topic cubit and the incident list hold them.
({TopicDetailState state, List<Incident> incidents}) _build(
  _Scene scene,
  DateTime now,
) {
  final sorted = [...scene.messages]
    ..sort((a, b) => _at(b, now).compareTo(_at(a, now)));
  final items = <TopicDetailMessageItem>[];
  final times = <DateTime>[];
  final incidentMessages = <String, List<Message>>{};
  final incidentRings = <String, _Ring>{};
  final incidentOpened = <String, DateTime>{};
  for (final (i, m) in sorted.indexed) {
    final at = _at(m, now);
    items.add(
      TopicDetailMessageItem(
        title: m.title,
        timestamp: DateFormat.Hm().format(at),
        sentAt: at,
        body: m.body,
        source: m.tags.join(', '),
        isHigh: m.isHigh,
      ),
    );
    times.add(at);
    final ring = m.ring;
    if (ring != null) {
      final id = m.incident ?? 'inc_$i';
      incidentRings[id] = ring;
      final opened = incidentOpened[id];
      if (opened == null || at.isBefore(opened)) incidentOpened[id] = at;
      (incidentMessages[id] ??= []).add(
        Message(
          id: 'm_$i',
          topic: scene.topic,
          time: at.millisecondsSinceEpoch ~/ 1000,
          title: m.title,
          message: m.body,
          priority: 5,
          incidentId: id,
        ),
      );
    }
  }
  final incidents = <Incident>[
    for (final entry in incidentRings.entries)
      () {
        final opened = incidentOpened[entry.key]!;
        final ring = entry.value;
        final stop = ring.seconds == null
            ? null
            : opened.add(Duration(seconds: ring.seconds!));
        return Incident(
          id: entry.key,
          topic: scene.topic,
          state: ring.state,
          openedAt: opened,
          ackedAt: ring.state == 'acked' ? stop : null,
          closedAt: ring.state == 'closed' || ring.state == 'expired'
              ? stop
              : null,
          messages: incidentMessages[entry.key]!,
        );
      }(),
  ];
  return (
    state: TopicDetailState(
      status: scene.status,
      topicName: scene.topic,
      messages: items,
      messageTimes: times,
      errorMessage: scene.error,
    ),
    incidents: incidents,
  );
}

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

Future<void> _settle(WidgetTester tester) async {
  // The skeleton and the disc never stop, so pumpAndSettle would not return.
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
    await loadTestTranslations();
    await loadAppFonts();
  });

  void capture(
    _Scene scene, {
    required _Phone phone,
    required ThemeMode mode,
    double scale = 1,
    bool isReduced = false,
    String frame = '',
  }) {
    final name =
        '${scene.name}_${phone.name}_${mode.name}_${scale}x'
        '${isReduced ? '_reduced' : ''}${frame.isEmpty ? '' : '_$frame'}';
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

      final built = _build(scene, DateTime.now());
      final incidents = _Incidents(built.incidents);
      final cubit = TopicDetailCubit(
        incidents,
        getIt<TopicsCubit>(),
        getIt<UpdateTopicUsecase>(),
        getIt<IncidentRepository>(),
      )..showExample(built.state);
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
            home: TopicMessagesScreen(
              topicName: scene.topic,
              cubit: cubit,
              incidents: incidents,
            ),
          ),
        );
        await tester.pump();
        if (frame == 'grow') {
          await tester.pump(const Duration(milliseconds: 200));
        } else {
          await _settle(tester);
        }
        if (frame == 'scrolled') {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -260),
          );
          await _settle(tester);
        }

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
        await cubit.close();
        await incidents.close();
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
      }
    });
  }

  final byName = {for (final s in _scenes) s.name: s};
  _Scene scene(String name) => byName[name]!;

  // Every state, light and dark.
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
    for (final name in ['board', 'many', 'long', 'loading', 'failed']) {
      capture(scene(name), phone: _phone, mode: ThemeMode.light, scale: scale);
    }
    capture(scene('long'), phone: _narrow, mode: ThemeMode.dark, scale: scale);
  }

  // Reduced motion: the settled frame, no growth, no breath.
  for (final name in ['board', 'loading']) {
    capture(scene(name), phone: _phone, mode: ThemeMode.light, isReduced: true);
  }

  // The bar title once the header is under the bar.
  capture(
    scene('many'),
    phone: _phone,
    mode: ThemeMode.light,
    frame: 'scrolled',
  );
  capture(
    scene('many'),
    phone: _narrow,
    mode: ThemeMode.dark,
    frame: 'scrolled',
  );

  // The whole page at once.
  capture(scene('many'), phone: _tall, mode: ThemeMode.light, frame: 'full');
  capture(scene('long'), phone: _tall, mode: ThemeMode.light, frame: 'full');

  // The bars part way up.
  capture(scene('board'), phone: _phone, mode: ThemeMode.light, frame: 'grow');
}
