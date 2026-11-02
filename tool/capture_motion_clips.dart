// The clips `capture_motion.dart` records: the fixtures, the scenes and the
// list. Part of that tool, not of the app.
//
// The tool stands in for the alarm cubit when it moves the alarm's start.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: invalid_use_of_protected_member

part of 'capture_motion.dart';

// ---------------------------------------------------------------------------
// The alarm screen's clock
// ---------------------------------------------------------------------------

/// Builds the alarm cubit as `di.dart` does, with pumped time for its clock.
///
/// The cubit takes a clock so a test can hand it one. With the real clock a
/// clip's "Ringing 3 s." would count as fast as frames are saved, several
/// seconds a second.
Future<void> _giveAlarmScreenThePumpedClock() async {
  await getIt.unregister<CriticalAlarmCubit>();
  getIt.registerFactory(
    () => CriticalAlarmCubit(
      _LocalGet(getIt<GetIncidentUsecase>()),
      getIt<GetIncidentsUsecase>(),
      _LocalAck(getIt<AcknowledgeIncidentUsecase>()),
      _LocalClose(getIt<CloseIncidentUsecase>()),
      getIt<IncidentsCubit>(),
      getIt<AlarmHost>(),
      const Duration(seconds: 1),
      _clock.now,
      getIt<GetOnboardingCompletedUsecase>(),
      () => getIt<OnboardingFlowEngine>().isStepSatisfied(
        OnboardingStepId.firstTopic,
      ),
      () => getIt<SetupTestRing>().incidentIds,
      () => getIt<OnboardingFlowEngine>().runningFlow().contains(
        OnboardingStepId.realRing,
      ),
      getIt<EndSetupTestUsecase>(),
      getIt<SetupTestRing>(),
      getIt<ProofLog>(),
    ),
  );
}

/// The same incident with its times as local times.
///
/// The answered screen prints "Started" and "Acknowledged" straight off the
/// incident's times, which the server sends in UTC, and prints "Source" in
/// local time. On a phone outside UTC the two disagree. A clip shows them
/// agreeing, on the phone's clock.
Incident _inLocalTime(Incident i) => i.copyWith(
  openedAt: i.openedAt?.toLocal(),
  ackedAt: i.ackedAt?.toLocal(),
);

class _LocalGet implements GetIncidentUsecase {
  _LocalGet(this._real);

  final GetIncidentUsecase _real;

  @override
  Future<AppResult<Incident>> call(String id) async =>
      (await _real(id)).map(_inLocalTime);
}

class _LocalAck implements AcknowledgeIncidentUsecase {
  _LocalAck(this._real);

  final AcknowledgeIncidentUsecase _real;

  @override
  Future<AppResult<Incident>> call(String id) async =>
      (await _real(id)).map(_inLocalTime);
}

class _LocalClose implements CloseIncidentUsecase {
  _LocalClose(this._real);

  final CloseIncidentUsecase _real;

  @override
  Future<AppResult<Incident>> call(String id) async =>
      (await _real(id)).map(_inLocalTime);
}

// ---------------------------------------------------------------------------
// Stories and fixtures
// ---------------------------------------------------------------------------

/// One alarm a film tells the story of. The same words as the still
/// snapshots use (`capture_marketing_screens.dart`, `_stories`), so a clip
/// and a still of one story match.
typedef _Story = ({
  String slug,
  String topic,
  String title,
  String message,
  List<String> tags,
});

const _Story _db1 = (
  slug: 'db-1',
  topic: 'db-1',
  title: 'Disk full on db-1',
  message: '/var/lib/postgresql is at 100%. Writes are failing.',
  tags: ['postgres', 'disk'],
);

const _Story _freezer = (
  slug: 'freezer',
  topic: 'freezer',
  title: 'Freezer door is open',
  message: 'It has been open for 10 minutes.',
  tags: ['kitchen'],
);

const _Story _sumpPump = (
  slug: 'sump-pump',
  topic: 'sump-pump',
  title: 'Sump pump stopped',
  message: 'It has not run for an hour. Water is rising.',
  tags: ['basement'],
);

const _Story _paymentWebhook = (
  slug: 'payment-webhook',
  topic: 'payment-webhook',
  title: 'Payment webhook went quiet',
  message: 'No payment events for 30 minutes.',
  tags: ['payments'],
);

const _Story _backupJob = (
  slug: 'backup-job',
  topic: 'backup-job',
  title: 'Backup failed',
  message: 'The nightly backup stopped with an error.',
  tags: ['backup', 'nightly'],
);

const _Story _site = (
  slug: 'site',
  topic: 'site',
  title: 'Site is down',
  message: 'No answer from the home page for 2 minutes.',
  tags: ['site', 'down'],
);

int _unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

String _ringingId(_Story s) => 'inc_motion_${s.slug}';

/// What a clip does before its first frame: fills the mock server, saves
/// what the phone would hold, and opens a route.
class _Scene {
  _Scene(this.tester, this.server);

  final WidgetTester tester;
  final MockServer server;
  late Future<_Take> Function(String route) _open;
  _Take? take;

  /// Pumped time now, as a UTC instant. Fixtures count back from it.
  DateTime get now => _clock.now().toUtc();

  /// Builds the app on [route] and lets it settle. Not recorded.
  Future<_Take> open(String route) async => take = await _open(route);

  /// The four topics of the still snapshots, and a few closed alarms from
  /// the last days so Home, History and a topic have a past.
  void seedHome({bool withPast = true, bool db1Critical = true}) {
    final n = now;
    server.seedState(
      topics: [
        Topic(
          name: 'db-1',
          critical: db1Critical,
          createdAt: n.subtract(const Duration(days: 41)),
          token: 'tk_mkt_db1',
          tokenId: 'tok_mkt_db1',
          tokenName: 'db-1 cron',
        ),
        Topic(
          name: 'api-gateway',
          critical: true,
          createdAt: n.subtract(const Duration(days: 33)),
          token: 'tk_mkt_api',
          tokenId: 'tok_mkt_api',
          tokenName: 'health check',
        ),
        Topic(
          name: 'nightly-backup',
          createdAt: n.subtract(const Duration(days: 28)),
          token: 'tk_mkt_backup',
          tokenId: 'tok_mkt_backup',
          tokenName: 'backup script',
        ),
        Topic(
          name: 'tls-certs',
          createdAt: n.subtract(const Duration(days: 12)),
          token: 'tk_mkt_tls',
          tokenId: 'tok_mkt_tls',
          tokenName: 'renew job',
        ),
      ],
    );
    if (!withPast) return;
    final incidents = <Incident>[];
    final messages = <Message>[];
    void closed(
      String id,
      String topic,
      Duration ago,
      Duration toAck,
      String title,
      String body,
    ) {
      final opened = n.subtract(ago);
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

    closed(
      'inc_mkt_api_5xx',
      'api-gateway',
      const Duration(days: 2, hours: 5),
      const Duration(seconds: 38),
      '5xx rate above 20% on api-gateway',
      'p95 latency 4.1 s, 312 errors in the last minute',
    );
    closed(
      'inc_mkt_api_down',
      'api-gateway',
      const Duration(days: 6, hours: 9),
      const Duration(seconds: 22),
      'api-gateway health check failing',
      'GET /healthz timed out from 3 of 3 probes',
    );
    messages
      // The db-1 story: the disk was filling before it was full, and those
      // warnings were not critical. Every screen of db-1 tells this story.
      ..add(
        Message(
          id: 'm_mkt_db1_disk_85',
          topic: 'db-1',
          time: _unix(n.subtract(const Duration(hours: 5))),
          title: 'Disk at 85% on db-1',
          message: '/var/lib/postgresql has 31 GB left.',
          tags: const ['postgres', 'disk'],
        ),
      )
      ..add(
        Message(
          id: 'm_mkt_backup_ok',
          topic: 'nightly-backup',
          time: _unix(n.subtract(const Duration(hours: 6))),
          title: 'Backup finished',
          message: '412 GB in 38 min, 0 errors',
          tags: const ['white_check_mark'],
        ),
      )
      ..add(
        Message(
          id: 'm_mkt_tls_renew',
          topic: 'tls-certs',
          time: _unix(n.subtract(const Duration(days: 1, hours: 3))),
          title: 'Certificate renewed',
          message: 'Next renewal in 60 days',
          priority: 2,
        ),
      )
      ..sort((a, b) => a.time.compareTo(b.time));
    server.seedState(incidents: incidents, messages: messages);
  }

  /// A story's topic alone, with one earlier alarm of the same kind that
  /// was answered and closed.
  void seedStoryTopic(_Story story) {
    final n = now;
    final earlier = n.subtract(const Duration(days: 9, hours: 4));
    final earlierId = 'inc_motion_${story.slug}_past';
    final msg = Message(
      id: 'm_motion_${story.slug}_past',
      topic: story.topic,
      time: _unix(earlier),
      title: story.title,
      message: story.message,
      priority: 5,
      tags: story.tags,
      incidentId: earlierId,
    );
    server.seedState(
      topics: [
        Topic(
          name: story.topic,
          critical: true,
          createdAt: n.subtract(const Duration(days: 41)),
          token: 'tk_motion_${story.slug}',
          tokenId: 'tok_motion_${story.slug}',
          tokenName: story.topic,
        ),
      ],
      incidents: [
        Incident(
          id: earlierId,
          topic: story.topic,
          state: IncidentStates.closed,
          openedAt: earlier,
          ackedAt: earlier.add(const Duration(seconds: 47)),
          closedAt: earlier.add(const Duration(minutes: 12)),
          updatedAt: earlier.add(const Duration(minutes: 12)),
          lastMessageAt: earlier,
          messages: [msg],
        ),
      ],
      messages: [msg],
    );
  }

  /// Opens [story]'s alarm on the mock server, ringing for [rungFor]. No
  /// request is made: the incident is written into the mock's own state,
  /// which is what a message from a tool would have left there.
  void ring(_Story story, {Duration rungFor = Duration.zero}) {
    final opened = now.subtract(rungFor);
    final id = _ringingId(story);
    final msg = Message(
      id: 'm_motion_${story.slug}',
      topic: story.topic,
      time: _unix(opened),
      title: story.title,
      message: story.message,
      priority: 5,
      tags: story.tags,
      incidentId: id,
    );
    server.seedState(
      incidents: [
        Incident(
          id: id,
          topic: story.topic,
          openedAt: opened,
          updatedAt: opened,
          lastMessageAt: opened,
          messages: [msg],
        ),
      ],
      messages: [msg],
    );
  }

  /// Brings pumped time and the real clock together again, just before a
  /// tap whose answer the mock server stamps with the real clock.
  ///
  /// Saving frames takes longer than the frames last, so by now the real
  /// clock is ahead. The ringing alarm's start moves forward by that much,
  /// on the mock server, in the shared list and on the alarm screen, and
  /// pumped time catches up by the same amount. The ring count on screen
  /// does not change, and "Rang for" then matches it.
  void syncClocks(_Story story) {
    final id = _ringingId(story);
    final lag = _clock.lag;
    final held = server.getIncident(id);
    final opened = held.openedAt;
    if (opened == null) return;
    final moved = opened.add(lag);
    server.seedState(
      incidents: [
        held.copyWith(openedAt: moved, updatedAt: moved, lastMessageAt: moved),
      ],
    );
    _clock.catchUp(lag);
    final cubit = CriticalAlarmCubit.current;
    final shown = cubit?.state.incident;
    if (cubit == null || shown == null || shown.id != id) return;
    final local = shown.copyWith(openedAt: moved.toLocal());
    getIt<IncidentsCubit>().applyIncident(local);
    cubit.emit(cubit.state.copyWith(incident: local));
  }

  /// Opens [story]'s alarm in front of a screen that reads the real clock,
  /// so that screen and the alarm screen both count from 0.
  ///
  /// Home's card counts an open alarm with the real clock. The alarm screen
  /// counts it with pumped time. Saving a frame takes about three times as
  /// long as the frame lasts, so during the takeover Home read
  /// "RINGING 0:02" over an alarm screen that read "Ringing 0 s.".
  ///
  /// Two steps put that right. Pumped time first catches up with the real
  /// clock. Then the alarm opens [_takeoverLead] ahead of that instant: the
  /// real clock needs that long, and a second more, before Home can read
  /// 0:01, and the takeover is over by then. Both screens print a start
  /// that is less than a second away as 0. [ringSettles] moves the start
  /// back once Home is out of view.
  void ringMet(_Story story) {
    _clock.catchUp(_clock.lag);
    ring(story, rungFor: -_takeoverLead);
  }

  /// Moves the alarm [ringMet] opened back to the instant it was opened
  /// at, on the mock server, in the shared list and on the alarm screen.
  /// From here the alarm screen counts pumped time from that instant, as
  /// it would have with no lead. Call it once the takeover is over.
  void ringSettles(_Story story) {
    final id = _ringingId(story);
    Incident back(Incident i) {
      final at = i.openedAt?.subtract(_takeoverLead);
      return i.copyWith(openedAt: at, updatedAt: at, lastMessageAt: at);
    }

    server.seedState(incidents: [back(server.getIncident(id))]);
    final shared = getIt<IncidentsCubit>();
    for (final i in shared.state.incidents) {
      if (i.id != id) continue;
      shared.applyIncident(back(i));
      break;
    }
    final cubit = CriticalAlarmCubit.current;
    final shown = cubit?.state.incident;
    if (cubit == null || shown == null || shown.id != id) return;
    cubit.emit(cubit.state.copyWith(incident: back(shown)));
  }

  /// Saves [look] as the phone's alarm look and holds the plan that draws
  /// it. The standard look needs neither.
  Future<void> useLook(AlarmStyleId look) async {
    if (look == AlarmStyleId.standard) return;
    await tester.runAsync(() async {
      await getIt<ProPackDevSwitch>().setHeld(isHeld: true);
      await getIt<AlarmStyleChoices>().setDefault(look.id);
      await getIt<AlarmStyleGate>().check();
    });
  }

  /// Holds the Pro pack through the developer switch, so paid looks and
  /// challenges are drawn open. Nothing is bought and no store is asked.
  Future<void> holdPro() => tester.runAsync(() async {
    await getIt<ProPackDevSwitch>().setHeld(isHeld: true);
    await getIt<AlarmStyleGate>().check();
  });

  /// Asks the shared lists to read the mock server again, as a push or a
  /// return to the app does. It does not wait: the answer lands during the
  /// frames that follow, as it does on a phone.
  Future<void> reload() async {
    unawaited(getIt<TopicsCubit>().refresh());
    unawaited(getIt<IncidentsCubit>().refresh(full: true));
  }
}

// ---------------------------------------------------------------------------
// The clips
// ---------------------------------------------------------------------------

/// How long after an alarm opens the screen under it is out of view. The
/// alarm screen has covered it by about 0.4 s.
const double _takeoverS = 0.8;

/// How far ahead of pumped "now" [_Scene.ringMet] opens an alarm. Under a
/// second, so the alarm screen never prints a start that is still to come
/// as anything but 0.
const Duration _takeoverLead = Duration(milliseconds: 900);

const Map<AlarmStyleId, String> _lookNames = {
  AlarmStyleId.standard: 'Standard',
  AlarmStyleId.minimal: 'Minimal',
  AlarmStyleId.terminal: 'Terminal',
  AlarmStyleId.redAlert: 'Red Alert',
  AlarmStyleId.critPanic: 'Crit Panic',
};

/// Home, quiet. Then the alarm's push lands and the alarm screen takes over
/// and rings.
_Clip _alarmArrives(AlarmStyleId look, _Story story) => (
  id: 'alarm.arrive.${look.id}',
  screen: 'Home, then the ringing alarm screen',
  look: _lookNames[look]!,
  story: story.slug,
  theme: _theme,
  features: [
    'F-alarm-screen',
    'F-redesigned-screens',
    if (look != AlarmStyleId.standard) 'F-alarm-looks',
  ],
  note:
      "Home is calm for 0.7 s. Then the open alarm reaches the app's "
      'shared list, as it does when a push lands, and the app itself swaps '
      'Home for the alarm screen, which rings from 0 s.',
  run: (scene) async {
    scene
      ..seedHome()
      ..seedStoryTopic(story);
    await scene.useLook(look);
    final take = await scene.open('/');
    await take.record();
    await take.hold(0.7);
    scene.ringMet(story);
    await scene.reload();
    take.mark(
      'the alarm opens: Home hears of it and the alarm screen takes over',
    );
    await take.hold(_takeoverS);
    scene.ringSettles(story);
    await take.hold(4.3 - _takeoverS);
  },
);

/// The alarm has rung for 14 s. A finger taps "I'm up" and the screen turns
/// into the answered one.
_Clip _alarmAnswered(AlarmStyleId look, _Story story) => (
  id: 'alarm.im-up.${look.id}',
  screen: 'Ringing alarm screen, then the answered screen',
  look: _lookNames[look]!,
  story: story.slug,
  theme: _theme,
  features: [
    'F-alarm-screen',
    'F-ack-im-up',
    'F-alarm-stopped-screen',
    if (look != AlarmStyleId.standard) 'F-alarm-looks',
  ],
  note:
      'Rings from 14 s, "I\'m up" is tapped at about 1.5 s, the answered '
      'screen draws. There is no confetti: the app throws it only on its '
      'setup demo.',
  run: (scene) async {
    scene
      ..seedStoryTopic(story)
      ..ring(story, rungFor: const Duration(seconds: 14));
    await scene.useLook(look);
    final take = await scene.open('/incidents/${_ringingId(story)}');
    await take.record();
    await take.hold(1.5);
    scene.syncClocks(story);
    await take.tap(find.text("I'm up"), what: "I'm up", press: 0.12);
    await take.hold(2.6);
  },
);

/// A finger taps "Silence": the sound stops on this phone and the alarm
/// stays open.
_Clip _alarmSilenced(_Story story) => (
  id: 'alarm.silence.standard',
  screen: 'Ringing alarm screen',
  look: 'Standard',
  story: story.slug,
  theme: _theme,
  features: ['F-alarm-screen'],
  note:
      'Rings from 22 s, "Silence" is tapped at about 1.4 s. The button '
      'shows the press and nothing else on the screen changes: Silence '
      'stops the sound on this phone and the alarm stays open.',
  run: (scene) async {
    scene
      ..seedStoryTopic(story)
      ..ring(story, rungFor: const Duration(seconds: 22));
    final take = await scene.open('/incidents/${_ringingId(story)}');
    await take.record();
    await take.hold(1.4);
    await take.tap(find.text('Silence'), what: 'Silence', press: 0.12);
    await take.hold(2.6);
  },
);

/// A finger taps "Read the full message" and the topic's messages open.
_Clip _alarmReadMessage(_Story story) => (
  id: 'alarm.read-full-message.standard',
  screen: "Ringing alarm screen, then the topic's messages",
  look: 'Standard',
  story: story.slug,
  theme: _theme,
  features: ['F-alarm-screen', 'F-redesigned-screens'],
  note:
      'Rings from 9 s, "Read the full message" is tapped at about 1.2 s, '
      'the topic opens on its messages.',
  run: (scene) async {
    scene
      ..seedStoryTopic(story)
      ..ring(story, rungFor: const Duration(seconds: 9));
    final take = await scene.open('/incidents/${_ringingId(story)}');
    await take.record();
    await take.hold(1.2);
    await take.tap(
      find.text('Read the full message'),
      what: 'Read the full message',
      press: 0.12,
    );
    await take.hold(3.3);
  },
);

/// A long ring with nothing touched, for a film that needs the screen to
/// sit there ringing.
_Clip _alarmRings(_Story story) => (
  id: 'alarm.ringing.${story.slug}',
  screen: 'Ringing alarm screen',
  look: 'Standard',
  story: story.slug,
  theme: _theme,
  features: ['F-alarm-screen'],
  note: 'Rings from 14 s to 20 s, nothing touched.',
  run: (scene) async {
    scene
      ..seedStoryTopic(story)
      ..ring(story, rungFor: const Duration(seconds: 14));
    final take = await scene.open('/incidents/${_ringingId(story)}');
    await take.record();
    await take.hold(6);
  },
);

/// The answered screen, then "At my desk" closes the alarm.
_Clip _alarmAtMyDesk(_Story story) => (
  id: 'alarm.at-my-desk.standard',
  screen: 'Answered alarm screen',
  look: 'Standard',
  story: story.slug,
  theme: _theme,
  features: [
    'F-alarm-stopped-screen',
    'F-ack-at-desk',
    'F-redesigned-screens',
  ],
  note:
      'The alarm was answered before the first frame. "At my desk" is '
      'tapped at about 1.2 s and the alarm closes, then "Back to topics" '
      'goes to a calm Home.',
  run: (scene) async {
    scene
      ..seedHome()
      ..seedStoryTopic(story)
      ..ring(story, rungFor: const Duration(seconds: 41));
    final take = await scene.open('/incidents/${_ringingId(story)}');
    scene.syncClocks(story);
    await take.real(() => CriticalAlarmCubit.current!.acknowledge());
    await take.settle();
    await take.record();
    await take.hold(1.2);
    await take.tap(find.text('At my desk'), what: 'At my desk', press: 0.12);
    await take.hold(1.3);
    await take.tap(
      find.text('Back to topics'),
      what: 'Back to topics',
      press: 0.12,
    );
    await take.hold(2.2);
  },
);

/// Home, quiet, with nothing touched: the face blinks and breathes.
_Clip _homeCalm() => (
  id: 'home.calm',
  screen: 'Home (Topics)',
  look: '-',
  story: null,
  theme: _theme,
  features: ['F-home-face', 'F-redesigned-screens'],
  note: 'Four seconds of a calm Home, nothing touched.',
  run: (scene) async {
    scene.seedHome();
    final take = await scene.open('/');
    await take.record();
    await take.hold(4);
  },
);

/// The answered screen, then Home while the desk timer runs.
_Clip _homeAfterImUp(_Story story) => (
  id: 'home.open-alarm',
  screen: 'Answered alarm screen, then Home with the answered alarm',
  look: 'Standard',
  story: story.slug,
  theme: _theme,
  features: [
    'F-home-face',
    'F-ack-im-up',
    'F-alarm-stopped-screen',
    'F-redesigned-screens',
  ],
  note:
      'The alarm was answered before the first frame. "Back to topics" is '
      'tapped at 1 s. Home shows the answered alarm with its desk timer '
      'counting down.',
  run: (scene) async {
    scene
      ..seedHome()
      ..ring(story, rungFor: const Duration(seconds: 41));
    final take = await scene.open('/incidents/${_ringingId(story)}');
    scene.syncClocks(story);
    await take.real(() => CriticalAlarmCubit.current!.acknowledge());
    await take.settle();
    await take.record();
    await take.hold(1);
    await take.tap(
      find.text('Back to topics'),
      what: 'Back to topics',
      press: 0.12,
    );
    await take.hold(2.4);
  },
);

/// The db-1 story, start to end, in clips that cut together: every screen
/// shows the same topic, the same words and the same night.
///
/// 1. Home, a tap on db-1, the topic page with Critical delivery OFF.
/// 2. The switch goes on.
/// 3. Home, then the alarm arrives and rings.
/// 4. "I'm up".
/// 5. The answered screen, "At my desk", back to Home.
///
/// Clip 3 is quiet for [_db1QuietS], then rings for [_db1RingsS]. Clip 4
/// opens the same alarm that far into its ring and records from there, so
/// the two cut together with the ring count unbroken.
const double _db1QuietS = 0.8;
const double _db1RingsS = 4.7;

/// Ringing clip 4 plays before its frame 0, not recorded: 50 frames. See
/// the clip for why.
const double _db1LeadIn = 50 / 60;

/// Clips that are cut one after the other, for the manifest.
const Map<String, Map<String, Object?>> _joins = {
  'story.db-1.3-alarm-arrives': {
    'continued_by': 'story.db-1.4-im-up',
    'cut': "this clip's last frame, then frame 0 of the next clip",
    'ring_s_at_last_frame': _db1RingsS,
  },
  'story.db-1.4-im-up': {
    'continues': 'story.db-1.3-alarm-arrives',
    'cut': "the last frame of that clip, then this clip's frame 0",
    'ring_s_at_frame_0': _db1RingsS,
    'same_between_the_two': 'the ring count, the words, the clock',
    'can_differ': 'the ringing face, which the app picks at random',
  },
};

List<_Clip> _db1Story() {
  const story = _db1;
  final base = (
    look: 'Standard',
    story: 'db-1',
    theme: _theme,
  );
  return [
    (
      id: 'story.db-1.1-topic-critical-off',
      screen: 'Home, then the db-1 topic with Critical delivery off',
      look: base.look,
      story: base.story,
      theme: base.theme,
      features: ['F-critical-switch', 'F-redesigned-screens'],
      note:
          'The db-1 row is tapped on Home at 0.9 s and the topic opens. '
          'Critical delivery is OFF, as it is on every new topic. The last '
          'frame is the clear still of the switch in its off state.',
      run: (scene) async {
        scene.seedHome(db1Critical: false);
        final take = await scene.open('/');
        await take.record();
        await take.hold(0.9);
        await take.tap(find.text('db-1'), what: 'db-1 row');
        await take.hold(3);
      },
    ),
    (
      id: 'story.db-1.2-critical-on',
      screen: 'The db-1 topic',
      look: base.look,
      story: base.story,
      theme: base.theme,
      features: ['F-critical-switch', 'F-redesigned-screens'],
      note:
          'Critical delivery is OFF for the first 1.5 s (the first frame is '
          'a still of that). The switch is tapped and it goes ON.',
      run: (scene) async {
        scene.seedHome(db1Critical: false);
        final take = await scene.open('/topics/db-1');
        await take.record();
        await take.hold(1.5);
        await take.tap(
          find.descendant(
            of: find.byType(TopicCriticalCard),
            matching: find.byType(AppSwitch),
          ),
          what: 'Critical delivery switch',
        );
        await take.hold(2.8);
      },
    ),
    (
      id: 'story.db-1.3-alarm-arrives',
      screen: 'The db-1 topic, then the ringing alarm screen',
      look: base.look,
      story: base.story,
      theme: base.theme,
      features: [
        'F-alarm-screen',
        'F-critical-switch',
        'F-redesigned-screens',
      ],
      note:
          'The db-1 topic with Critical delivery ON, quiet for 0.8 s. Then '
          '"Disk full on db-1" opens an alarm and the alarm screen takes '
          'over and rings from 0 s.',
      run: (scene) async {
        scene.seedHome();
        final take = await scene.open('/topics/db-1');
        await take.record();
        await take.hold(_db1QuietS);
        scene.ringMet(story);
        await scene.reload();
        take.mark('the alarm opens and the alarm screen takes over');
        await take.hold(_takeoverS);
        scene.ringSettles(story);
        await take.hold(_db1RingsS - _takeoverS);
      },
    ),
    (
      id: 'story.db-1.4-im-up',
      screen: 'Ringing alarm screen, then the answered screen',
      look: base.look,
      story: base.story,
      theme: base.theme,
      features: ['F-alarm-screen', 'F-ack-im-up', 'F-alarm-stopped-screen'],
      note:
          'Carries on from clip 3 with no gap: at frame 0 the alarm is one '
          "frame further into its ring than at clip 3's last frame (4.7 s), "
          'so the count reads "Ringing 4 s." on both sides of the cut and '
          'goes up from there. "I\'m up" is tapped at about 2 s and the '
          'answered screen draws. There is no confetti: the app throws it only '
          'on its setup demo. The ringing face is picked at random, so it can '
          "differ from clip 3's.",
      run: (scene) async {
        // Recording starts where clip 3 stops: the alarm is _db1RingsS
        // into its ring at the last frame of clip 3, and a frame further
        // at frame 0 here. The alarm screen is opened on its own route,
        // as in every other "I'm up" clip. Opened over the topic page, as
        // clip 3 leaves it, the answered screen drew on the topic's yellow
        // ground with white words, which no film can use.
        //
        // The screen prints a new count once a second, counted from when
        // it opened, so the count on screen can be up to a second behind.
        // _db1LeadIn of unrecorded ringing puts that beat where clip 3 has
        // it: the count goes from 4 to 5 about a third of a second in.
        scene
          ..seedHome()
          ..ring(
            story,
            rungFor: Duration(
              microseconds: ((_db1RingsS - _db1LeadIn) * 1e6).round(),
            ),
          );
        final take = await scene.open('/incidents/${_ringingId(story)}');
        await take.skip(_db1LeadIn);
        await take.record();
        await take.hold(2);
        scene.syncClocks(story);
        await take.tap(find.text("I'm up"), what: "I'm up", press: 0.12);
        await take.hold(2.8);
      },
    ),
    (
      id: 'story.db-1.5-answered-at-my-desk',
      screen: 'Answered alarm screen, then Home',
      look: base.look,
      story: base.story,
      theme: base.theme,
      features: [
        'F-alarm-stopped-screen',
        'F-ack-at-desk',
        'F-home-face',
        'F-redesigned-screens',
      ],
      note:
          'The answered screen of the same alarm. It reads "Rang for 0 min '
          '6 s.", as the end of clip 4 does. "At my '
          'desk" is tapped at 1.6 s, then "Back to topics", and Home is '
          "calm again with the alarm in db-1's row.",
      run: (scene) async {
        scene
          ..seedHome()
          // Clip 4 answers the alarm 6.8 s into its ring.
          ..ring(story, rungFor: const Duration(milliseconds: 6800));
        final take = await scene.open('/incidents/${_ringingId(story)}');
        scene.syncClocks(story);
        await take.real(() => CriticalAlarmCubit.current!.acknowledge());
        await take.settle();
        await take.record();
        await take.hold(1.6);
        await take.tap(
          find.text('At my desk'),
          what: 'At my desk',
          press: 0.12,
        );
        await take.hold(1.2);
        await take.tap(
          find.text('Back to topics'),
          what: 'Back to topics',
          press: 0.12,
        );
        await take.hold(2.4);
      },
    ),
  ];
}

/// A message that is not critical arrives on a topic. The phone shows it
/// as a system notification, which this method cannot draw. In the app it
/// is a new row in the topic's messages, there after the list reloads.
_Clip _messageArrives() => (
  id: 'topic.message-arrives',
  screen: 'The nightly-backup topic',
  look: '-',
  story: 'nightly-backup',
  theme: _theme,
  features: ['F-publish-http', 'F-redesigned-screens'],
  note:
      'A topic with Critical delivery off. A normal message ("Backup '
      'finished") reaches the server at 0.8 s. The app has no banner of '
      'its own for it: the list is pulled down to reload and the new row '
      'is there. Nothing rings.',
  run: (scene) async {
    scene.seedHome();
    final take = await scene.open('/topics/nightly-backup');
    await take.record();
    await take.hold(0.8);
    scene.server.seedState(
      messages: [
        Message(
          id: 'm_motion_backup_tonight',
          topic: 'nightly-backup',
          time: _unix(DateTime.now()),
          title: 'Backup finished',
          message: '418 GB in 41 min, 0 errors',
          tags: const ['white_check_mark'],
        ),
      ],
    );
    take.mark('a normal message reaches the server');
    await take.hold(0.5);
    await take.drag(
      const Offset(210, 330),
      const Offset(210, 560),
      what: 'pull down to reload',
      seconds: 0.6,
      curve: Curves.easeOut,
    );
    await take.hold(3);
  },
);

/// The three tabs, one after the other.
_Clip _tabs() => (
  id: 'tabs.topics-history-settings',
  screen: 'Home, History, Settings',
  look: '-',
  story: null,
  theme: _theme,
  features: ['F-redesigned-screens', 'F-history-window'],
  note: 'The tab bar is tapped: History at 0.8 s, Settings near 2.4 s.',
  run: (scene) async {
    scene.seedHome();
    final take = await scene.open('/');
    await take.record();
    await take.hold(0.8);
    await take.tap(find.text('HISTORY'), what: 'History tab');
    await take.hold(1.5);
    await take.tap(find.text('SETTINGS'), what: 'Settings tab');
    await take.hold(1.5);
    await take.tap(find.text('TOPICS'), what: 'Topics tab');
    await take.hold(1.2);
  },
);

/// A topic's page. Critical delivery is off. A finger switches it on.
_Clip _topicCriticalOn(_Story story) => (
  id: 'topic.critical-on',
  screen: 'Topic',
  look: '-',
  story: story.slug,
  theme: _theme,
  features: ['F-critical-switch', 'F-redesigned-screens'],
  note: 'Critical delivery is off. The switch is tapped at about 1.3 s.',
  run: (scene) async {
    scene.seedStoryTopic(story);
    final topic = scene.server.getTopics().firstWhere(
      (t) => t.name == story.topic,
    );
    scene.server.seedState(topics: [topic.copyWith(critical: false)]);
    final take = await scene.open('/topics/${story.topic}');
    await take.record();
    await take.hold(1.3);
    await take.tap(
      find.descendant(
        of: find.byType(TopicCriticalCard),
        matching: find.byType(AppSwitch),
      ),
      what: 'Critical delivery switch',
    );
    await take.hold(2.8);
  },
);

/// A topic's page scrolled to its look, sound and challenge cards.
_Clip _topicScroll() => (
  id: 'topic.scroll',
  screen: 'Topic',
  look: '-',
  story: 'db-1',
  theme: _theme,
  features: ['F-redesigned-screens', 'F-critical-switch', 'F-topic-tokens'],
  note: 'The db-1 topic page, scrolled down to its cards and back.',
  run: (scene) async {
    scene.seedHome();
    final take = await scene.open('/topics/db-1');
    await take.record();
    await take.hold(0.8);
    await take.drag(
      const Offset(210, 600),
      const Offset(210, 250),
      what: 'scroll down',
      seconds: 0.7,
    );
    await take.hold(1.2);
    await take.drag(
      const Offset(210, 300),
      const Offset(210, 640),
      what: 'scroll up',
      seconds: 0.7,
    );
    await take.hold(1);
  },
);

/// Personalize: the stack of cards. A finger taps Look and the card grows
/// into the deck of phones.
_Clip _personalizeOpensLook() => (
  id: 'personalize.open-look',
  screen: 'Personalize, then Look',
  look: 'Standard',
  story: null,
  theme: _theme,
  features: ['F-personalize', 'F-personalize-passes', 'F-alarm-looks'],
  note:
      'The Personalize stack with its two live thumbnails. The Look card '
      'is tapped at about 1.6 s and grows into its page.',
  run: (scene) async {
    scene.seedHome();
    await scene.holdPro();
    final take = await scene.open('/settings/personalize');
    await take.record();
    await take.hold(1.6);
    await take.tap(find.text('LOOK'), what: 'Look card');
    await take.hold(2.6);
  },
);

/// The Look page: a finger swipes through the deck of phones.
_Clip _lookDeck() => (
  id: 'personalize.look-deck',
  screen: 'Personalize, Look',
  look: 'Standard, Minimal, Terminal, Red Alert, Crit Panic',
  story: null,
  theme: _theme,
  features: ['F-personalize-passes', 'F-alarm-looks'],
  note:
      'Four swipes to the left, one look each. The page takes the colour '
      'of the look in the middle.',
  run: (scene) async {
    scene.seedHome();
    await scene.holdPro();
    final take = await scene.open('/settings/personalize/look');
    await take.record();
    await take.hold(0.9);
    for (var i = 0; i < 4; i++) {
      await take.drag(
        const Offset(300, 420),
        const Offset(110, 420),
        what: 'swipe the deck left',
        seconds: 0.28,
        flick: true,
      );
      await take.hold(0.95);
    }
    await take.hold(0.4);
  },
);

/// The Wake-up challenge page: the shelf of tiles, scrolled, one picked.
_Clip _challengeShelf() => (
  id: 'personalize.challenge-shelf',
  screen: 'Personalize, Wake-up challenge',
  look: '-',
  story: null,
  theme: _theme,
  features: ['F-wake-up-challenges', 'F-personalize-passes'],
  note: 'The shelf of challenges with Pro held, scrolled down and back.',
  run: (scene) async {
    scene.seedHome();
    await scene.holdPro();
    final take = await scene.open('/settings/personalize/challenge');
    await take.record();
    await take.hold(0.8);
    await take.drag(
      const Offset(210, 600),
      const Offset(210, 330),
      what: 'scroll the shelf up',
      seconds: 0.6,
    );
    await take.hold(1.3);
    await take.drag(
      const Offset(210, 330),
      const Offset(210, 620),
      what: 'scroll the shelf back',
      seconds: 0.6,
    );
    await take.hold(0.8);
  },
);

/// An accelerometer the clip drives, in place of the phone's.
final class _HandSensor implements MotionSensor {
  StreamController<MotionReading>? _open;
  int _tick = 0;

  @override
  Stream<MotionReading> readings({void Function()? onStarted}) {
    late final StreamController<MotionReading> controller;
    controller = StreamController<MotionReading>(
      sync: true,
      onListen: () {
        _open = controller;
        onStarted?.call();
      },
      onCancel: () {
        if (identical(_open, controller)) _open = null;
      },
    );
    return controller.stream;
  }

  /// One reading of a hard swing, [step] of 15 through it.
  void swing(int step) {
    _tick++;
    _open?.add(
      MotionReading(
        x: 3 * math.sin(2 * math.pi * step / 15),
        y: 0,
        z: -1,
        at: Duration(milliseconds: 20 * _tick),
      ),
    );
  }
}

/// The shake challenge: the alarm is answered, "At my desk" owes a
/// challenge, the phone is shaken until the count is full and the alarm
/// closes.
_Clip _challengeShake(_Story story) => (
  id: 'challenge.shake',
  screen: 'Answered alarm screen, the Shake wake-up challenge',
  look: 'Standard',
  story: story.slug,
  theme: _theme,
  features: ['F-wake-up-challenges', 'F-ack-at-desk'],
  note:
      '"At my desk" is tapped at about 0.8 s and the Shake challenge '
      'opens. A made-up accelerometer then feeds thirty shakes, five a '
      'second. No finger is on the glass while it counts: a film shows '
      'the phone being shaken.',
  run: (scene) async {
    scene
      ..seedHome()
      ..seedStoryTopic(story)
      ..ring(story, rungFor: const Duration(seconds: 41));
    await scene.holdPro();
    final sensor = _HandSensor();
    await scene.tester.runAsync(() async {
      await getIt<ChallengeChoices>().setChoice(
        story.topic,
        ChallengeKind.shake,
      );
      await getIt.unregister<MotionSensor>();
      getIt.registerSingleton<MotionSensor>(sensor);
    });
    addTearDown(() async {
      await getIt.unregister<MotionSensor>();
      getIt.registerLazySingleton<MotionSensor>(MotionSensorHost.new);
    });
    final take = await scene.open('/incidents/${_ringingId(story)}');
    scene.syncClocks(story);
    await take.real(() => CriticalAlarmCubit.current!.acknowledge());
    await take.settle();
    await take.record();
    await take.hold(0.8);
    await take.tap(find.text('At my desk'), what: 'At my desk', press: 0.12);
    await take.hold(1.1);
    take.mark('the phone is shaken, until 30');
    // Thirty swings of fifteen readings, five readings a frame: five
    // shakes a second.
    for (var shake = 0; shake < 30; shake++) {
      for (var step = 0; step < 15; step++) {
        sensor.swing(step);
        if (step % 5 == 4) await take.frame();
      }
    }
    take.mark('thirty shakes, the alarm closes');
    await take.hold(1.6);
  },
);

/// The scratch card challenge: a finger rubs the cover off the card.
_Clip _challengeScratch(_Story story) => (
  id: 'challenge.scratch-card',
  screen: 'Answered alarm screen, the Scratch card wake-up challenge',
  look: 'Standard',
  story: story.slug,
  theme: _theme,
  features: ['F-wake-up-challenges', 'F-ack-at-desk'],
  note:
      '"At my desk" is tapped at about 0.8 s and the Scratch card opens. '
      'A finger rubs across it until the code shows. The clip ends there: '
      'the code is typed on the system keyboard, which this method cannot '
      'draw.',
  run: (scene) async {
    scene
      ..seedHome()
      ..seedStoryTopic(story)
      ..ring(story, rungFor: const Duration(seconds: 41));
    await scene.holdPro();
    await scene.tester.runAsync(
      () => getIt<ChallengeChoices>().setChoice(
        story.topic,
        ChallengeKind.scratchCard,
      ),
    );
    final take = await scene.open('/incidents/${_ringingId(story)}');
    scene.syncClocks(story);
    await take.real(() => CriticalAlarmCubit.current!.acknowledge());
    await take.settle();
    await take.record();
    await take.hold(0.8);
    await take.tap(find.text('At my desk'), what: 'At my desk', press: 0.12);
    await take.hold(1.2);
    final code = find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^[0-9]{4}$').hasMatch(w.data ?? ''),
    );
    final middle = scene.tester.getCenter(code.first);
    for (final (dy, back) in const [
      (-22.0, false),
      (-6.0, true),
      (12.0, false),
      (26.0, true),
    ]) {
      final left = middle + Offset(-130, dy);
      final right = middle + Offset(130, dy);
      await take.drag(
        back ? right : left,
        back ? left : right,
        what: 'rub the scratch card',
        seconds: 0.32,
        curve: Curves.linear,
      );
      await take.hold(0.08);
    }
    await take.hold(1.6);
  },
);

/// "Will it wake me?": the screen opens with its wire, then the list is
/// scrolled.
_Clip _reliabilityScroll() => (
  id: 'will-it-wake-me.scroll',
  screen: 'Settings, Will it wake me?',
  look: '-',
  story: null,
  theme: _theme,
  features: ['F-reliability-screen'],
  note:
      'Opened from Settings by a tap on the phone checks card. The dot '
      'runs along the wire, then the list is scrolled down and back.',
  run: (scene) async {
    scene.seedHome();
    final take = await scene.open('/settings');
    await take.record();
    await take.hold(0.6);
    await take.tap(find.text('PHONE CHECKS'), what: 'Phone checks card');
    await take.hold(2.6);
    await take.drag(
      const Offset(210, 620),
      const Offset(210, 300),
      what: 'scroll the checks up',
      seconds: 0.7,
    );
    await take.hold(1.4);
  },
);

/// History: the week card, then the list of past alarms scrolled.
_Clip _historyWeek() => (
  id: 'history.week-card',
  screen: 'History',
  look: '-',
  story: null,
  theme: _theme,
  features: ['F-history-window', 'F-redesigned-screens'],
  note:
      'History is opened from the tab bar at 0.6 s. The week card leads, '
      'then the list of past alarms is scrolled and pulled to refresh.',
  run: (scene) async {
    scene.seedHome();
    final take = await scene.open('/');
    await take.record();
    await take.hold(0.6);
    await take.tap(find.text('HISTORY'), what: 'History tab');
    await take.hold(1.6);
    await take.drag(
      const Offset(210, 600),
      const Offset(210, 330),
      what: 'scroll the list up',
      seconds: 0.6,
    );
    await take.hold(1);
    await take.drag(
      const Offset(210, 330),
      const Offset(210, 610),
      what: 'scroll the list back',
      seconds: 0.6,
    );
    await take.hold(1);
  },
);

/// The Priorities page: what each priority does, scrolled.
_Clip _priorities() => (
  id: 'priorities.open',
  screen: 'Settings, Priorities',
  look: '-',
  story: null,
  theme: _theme,
  features: ['F-priorities-page'],
  note: 'Opened from Settings by a tap on its row at 0.7 s.',
  run: (scene) async {
    scene.seedHome();
    final take = await scene.open('/settings');
    await take.record();
    await take.hold(0.7);
    await take.tap(find.text('Priorities'), what: 'Priorities row');
    await take.hold(2.6);
  },
);

/// The sound picker, scrolled.
_Clip _sounds() => (
  id: 'sounds.scroll',
  screen: 'Personalize, Sound',
  look: '-',
  story: null,
  theme: _theme,
  features: ['F-builtin-sounds', 'F-personalize-passes'],
  note:
      'The Sound card is tapped on Personalize at 0.8 s and grows into '
      'the list of sounds, which is scrolled. Nothing is played.',
  run: (scene) async {
    scene.seedHome();
    final take = await scene.open('/settings/personalize');
    await take.record();
    await take.hold(0.8);
    await take.tap(find.text('SOUND'), what: 'Sound card');
    await take.hold(1.8);
    await take.drag(
      const Offset(210, 640),
      const Offset(210, 300),
      what: 'scroll the sounds up',
      seconds: 0.6,
      flick: true,
    );
    await take.hold(1.8);
  },
);

/// The widgets page of Personalize.
_Clip _widgets() => (
  id: 'personalize.widgets',
  screen: 'Personalize, Widgets',
  look: '-',
  story: null,
  theme: _theme,
  features: ['F-widgets', 'F-personalize-passes'],
  note: 'The Widgets card is tapped at 0.8 s and grows into its page.',
  run: (scene) async {
    scene.seedHome();
    await scene.holdPro();
    final take = await scene.open('/settings/personalize');
    await take.record();
    await take.hold(0.8);
    await take.tap(find.text('WIDGETS'), what: 'Widgets card');
    await take.hold(2.8);
  },
);

/// Which story each look is recorded with, so no two looks tell one story.
const List<(AlarmStyleId, _Story)> _lookStories = [
  (AlarmStyleId.standard, _db1),
  (AlarmStyleId.minimal, _sumpPump),
  (AlarmStyleId.terminal, _paymentWebhook),
  (AlarmStyleId.redAlert, _site),
  (AlarmStyleId.critPanic, _freezer),
];

List<_Clip> _allClips() => [
  for (final (look, story) in _lookStories) _alarmArrives(look, story),
  for (final (look, story) in _lookStories) _alarmAnswered(look, story),
  _alarmRings(_freezer),
  _alarmRings(_backupJob),
  _alarmSilenced(_backupJob),
  _alarmReadMessage(_db1),
  _alarmAtMyDesk(_db1),
  _homeCalm(),
  _homeAfterImUp(_db1),
  ..._db1Story(),
  _messageArrives(),
  _tabs(),
  _topicCriticalOn(_freezer),
  _topicScroll(),
  _personalizeOpensLook(),
  _lookDeck(),
  _challengeShelf(),
  _widgets(),
  _sounds(),
  _challengeShake(_backupJob),
  _challengeScratch(_paymentWebhook),
  _reliabilityScroll(),
  _historyWeek(),
  _priorities(),
];
