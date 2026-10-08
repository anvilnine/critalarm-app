// Fixtures spell out defaults so each case reads on its own.

import 'dart:async';

import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_meaning.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart' show SeverityMode;
import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/topics/data/reader_missed_alarm_feed.dart';
import 'package:critalarm/features/topics/domain/home_card/handled_window.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/home_facts.dart';
import 'package:critalarm/features/topics/domain/home_card/readiness_pips.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_effect.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_in_app_notice_repository.dart';
import '../in_app_notices/in_app_notice_cubit_test.dart'
    show
        FakeAccountRepo,
        FakeGetConnectionUsecase,
        FakeIdentityRepo,
        FakeShellCubit;
import 'domain/home_card/home_card_fixtures.dart'
    show
        androidChecks,
        missedFact,
        now,
        setupAfterServer,
        setupFirstMessageOpen,
        withCheckAt;

class _FakeHome extends Cubit<HomeState> {
  _FakeHome([super.initial = const HomeState()]);

  void set(HomeState next) => emit(next);
}

class _FakeSetup extends Cubit<HomeSetupState> {
  _FakeSetup() : super(const HomeSetupState());

  void set(HomeSetupState next) => emit(next);
}

class _FakeFeed implements MissedAlarmFeed {
  MissedFact? fact;
  int reads = 0;
  final Set<String> dismissed = {};
  final StreamController<void> controller = StreamController.broadcast();

  @override
  Future<MissedFact?> read() async {
    reads++;
    return fact;
  }

  @override
  Stream<void> get changes => controller.stream;

  @override
  Future<void> dismiss(Iterable<String> incidentIds) async {
    dismissed.addAll(incidentIds);
    fact = null;
    controller.add(null);
  }
}

class _Source implements ReliabilityCheckSource {
  _Source(this.checks);

  List<ReliabilityCheck> checks;
  int reads = 0;

  /// Holds the read open until it completes.
  Completer<void>? gate;

  @override
  Future<List<ReliabilityCheck>> read() async {
    reads++;
    await gate?.future;
    return checks;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.after, this._run);

  final Duration after;
  final void Function() _run;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    fired = true;
    _run();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => 0;
}

const _topic = HomeTopicItem(
  name: 'prod-db',
  meta: '',
  priority: PriorityLevel.defaultPriority,
  ringsThroughSilent: true,
);

HomeState _loaded({
  HomeFacts facts = HomeFacts.none,
  List<HomeTopicItem> items = const [_topic],
}) => HomeState(
  status: HomeStatus.success,
  topicItems: items,
  lastKnownGoodAt: now,
  facts: facts,
);

DateTime _at(int seconds) => now.add(Duration(seconds: seconds));

class _Rig {
  _Rig({List<ReliabilityCheck>? checks, bool holdReliability = false})
    : source = _Source(checks ?? androidChecks(7)) {
    if (holdReliability) source.gate = Completer<void>();
    reliability = ReliabilityCubit([source]);
  }

  final _FakeHome home = _FakeHome();
  final _FakeSetup setup = _FakeSetup();
  final _FakeFeed feed = _FakeFeed();
  final _Source source;
  late final ReliabilityCubit reliability;
  final List<_FakeTimer> timers = [];
  DateTime clock = now;

  HomeCardCubit? _cubit;

  /// Starts on first use, so a test can build its own with other parts.
  HomeCardCubit get cubit => _cubit ??= HomeCardCubit(
    home: home,
    reliability: reliability,
    setup: setup,
    missed: feed,
    testRouteName: 'testRing',
    askPermissionsRouteName: 'askPermissions',
    clock: () => clock,
    timer: (after, run) {
      final timer = _FakeTimer(after, run);
      timers.add(timer);
      return timer;
    },
  );

  HomeCardModel get model => cubit.state.model;
  HomeCardKind get kind => model.kind;
  List<_FakeTimer> get liveTimers => [
    for (final t in timers)
      if (t.isActive) t,
  ];

  Future<void> settle() => pumpEventQueue();

  Future<void> dispose() async {
    await _cubit?.close();
    await reliability.close();
    await home.close();
    await setup.close();
    await feed.controller.close();
  }
}

Future<_Rig> _open({
  List<ReliabilityCheck>? checks,
  bool holdReliability = false,
}) async {
  final rig = _Rig(checks: checks, holdReliability: holdReliability);
  addTearDown(rig.dispose);
  // Touch the cubit so it starts.
  expect(rig.cubit.state, isA<HomeCardState>());
  await rig.settle();
  return rig;
}

void main() {
  group('the card follows the phone', () {
    test('loading, ringing, acknowledged, handled, idle', () async {
      final rig = await _open();
      final kinds = <HomeCardKind>[];
      final sub = rig.cubit.stream.listen((s) => kinds.add(s.model.kind));
      addTearDown(sub.cancel);

      expect(rig.kind, HomeCardKind.loading);
      expect(rig.model.numeral, const Dots());

      rig.home.set(_loaded());
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);
      expect(rig.model.numeral, const Count(7, 7));

      rig.home.set(
        _loaded(
          facts: HomeFacts(
            ringing: RingingFact(
              incidentId: 'inc-1',
              topic: 'prod-db',
              openedAt: _at(-137),
            ),
          ),
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.ringing);
      expect(rig.model.numeral, Elapsed(_at(-137)));
      expect(rig.model.action, const OpenAlarm('inc-1'));
      expect(rig.model.severity, SeverityMode.crit);
      expect(rig.model.face, FaceState.alarmed);

      final deadline = _at(9 * 60);
      rig.home.set(
        _loaded(
          facts: HomeFacts(
            acknowledged: AcknowledgedFact(
              incidentId: 'inc-1',
              topic: 'prod-db',
              deadline: deadline,
            ),
          ),
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.acknowledged);
      expect(rig.model.numeral, Remaining(deadline));
      expect(rig.model.severity, SeverityMode.ack);

      rig.home.set(
        _loaded(
          facts: HomeFacts(
            handled: HandledFact(
              topic: 'prod-db',
              closedAt: _at(-5),
              answeredAfter: const Duration(seconds: 11),
            ),
          ),
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.handled);
      expect(rig.model.numeral, const Seconds(11));

      // The window closes by itself.
      expect(rig.liveTimers, hasLength(1));
      expect(
        rig.liveTimers.single.after,
        handledCardWindow - const Duration(seconds: 5),
      );
      rig.clock = _at(-5).add(handledCardWindow);
      rig.liveTimers.single.fire();
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);
      expect(rig.liveTimers, isEmpty);

      expect(kinds, [
        HomeCardKind.idle,
        HomeCardKind.ringing,
        HomeCardKind.acknowledged,
        HomeCardKind.handled,
        HomeCardKind.idle,
      ]);
    });

    test('an acknowledgement ends at its deadline', () async {
      final rig = await _open();
      final deadline = _at(120);
      rig.home.set(
        _loaded(
          facts: HomeFacts(
            acknowledged: AcknowledgedFact(
              incidentId: 'inc-1',
              topic: 'prod-db',
              deadline: deadline,
            ),
          ),
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.acknowledged);
      expect(rig.liveTimers.single.after, const Duration(seconds: 120));

      rig.clock = deadline;
      rig.liveTimers.single.fire();
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);
    });

    test('emits only when the card changes', () async {
      final rig = await _open();
      rig.home.set(_loaded());
      await rig.settle();
      final emitted = <HomeCardState>[];
      final sub = rig.cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      // Things the card does not draw.
      rig.home.set(_loaded().copyWith(word: 'Clear', subText: 'No alarm'));
      rig.setup.set(const HomeSetupState());
      await rig.settle();
      expect(emitted, isEmpty);

      rig.home.set(_loaded(facts: const HomeFacts(warningCount: 1)));
      await rig.settle();
      expect(emitted, hasLength(1));
      expect(emitted.single.model.kind, HomeCardKind.warning);
    });

    test('warnings: the count, the orange canvas', () async {
      final rig = await _open();
      rig.home.set(_loaded(facts: const HomeFacts(warningCount: 2)));
      await rig.settle();
      expect(rig.kind, HomeCardKind.warning);
      expect(rig.model.numeral, const Number(2));
      expect(rig.model.severity, SeverityMode.high);
    });

    test('quiet: days since the newest message, a test only with a '
        'critical topic', () async {
      final rig = await _open();
      final facts = HomeFacts(
        newestMessageAt: now.subtract(const Duration(days: 23)),
        lastAlarmAt: now.subtract(const Duration(days: 30)),
      );
      rig.home.set(_loaded(facts: facts));
      await rig.settle();
      expect(rig.kind, HomeCardKind.quiet);
      expect(rig.model.numeral, const Days(23));
      expect(rig.model.action, const SendTest());

      rig.home.set(
        _loaded(
          facts: facts,
          items: const [
            HomeTopicItem(
              name: 'plain',
              meta: '',
              priority: PriorityLevel.defaultPriority,
            ),
          ],
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.quiet);
      expect(rig.model.action, isNull);
    });

    test('idle names the last alarm', () async {
      final rig = await _open();
      final last = now.subtract(const Duration(hours: 9));
      rig.home.set(_loaded(facts: HomeFacts(lastAlarmAt: last)));
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);
      expect(
        rig.model.foot,
        HomeCardFoot(HomeCardFootSlot.lastAlarm, time: last),
      );
    });
  });

  group('readiness', () {
    test('not loaded yet draws dots and no pips', () async {
      final rig = await _open(holdReliability: true);
      rig.home.set(_loaded());
      await rig.settle();

      expect(rig.kind, HomeCardKind.idle);
      expect(rig.model.numeral, const Dots());
      expect(rig.model.pips, isEmpty);
      expect(rig.cubit.state.readinessLoaded, isFalse);

      rig.source.gate!.complete();
      await rig.settle();
      expect(rig.model.numeral, const Count(7, 7));
      expect(rig.model.pips, hasLength(7));
      expect(rig.cubit.state.readinessLoaded, isTrue);
    });

    test('fine to look and back', () async {
      final rig = await _open();
      rig.home.set(_loaded());
      await rig.settle();
      expect(rig.model.numeral, const Count(7, 7));

      const fix = OpenRouteFix('settingsBattery');
      rig.source.checks = withCheckAt(
        androidChecks(7),
        2,
        ReliabilityState.needsLook,
        reason: 'denied',
        fix: fix,
      );
      await rig.cubit.refreshReadiness();
      await rig.settle();
      expect(rig.kind, HomeCardKind.issueLook);
      expect(rig.model.numeral, const Count(6, 7));
      expect(rig.model.face, needsLookFace);
      expect(rig.model.action, const Fix(fix));
      expect(rig.model.pips[2], PipTone.look);
      expect(rig.model.tapsReliability, isTrue);

      rig.source.checks = androidChecks(7);
      await rig.cubit.refreshReadiness();
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);
      expect(rig.model.numeral, const Count(7, 7));
    });

    test('a broken check uses the broken face and a red numeral', () async {
      final rig = await _open(
        checks: withCheckAt(
          androidChecks(7),
          1,
          ReliabilityState.broken,
          reason: 'denied',
        ),
      );
      rig.home.set(_loaded());
      await rig.settle();
      expect(rig.kind, HomeCardKind.issueBroken);
      expect(rig.model.numeral, const Count(6, 7));
      expect(rig.model.face, brokenFace);
      expect(rig.model.numeralTone, HomeCardNumeralTone.redAlt);
    });

    test('a source that failed to answer is a look, not a fine', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      // A second source that throws.
      final failing = ReliabilityCubit([rig.source, _Throwing()]);
      addTearDown(failing.close);
      final cubit = HomeCardCubit(
        home: rig.home,
        reliability: failing,
        setup: rig.setup,
        missed: rig.feed,
        testRouteName: 'testRing',
        askPermissionsRouteName: 'askPermissions',
        clock: () => now,
      );
      addTearDown(cubit.close);
      rig.home.set(_loaded());
      await rig.settle();
      expect(cubit.state.model.kind, HomeCardKind.issueLook);
      expect(
        cubit.state.model.foot.slot,
        HomeCardFootSlot.checkCouldNotRun,
      );
    });

    test('is asked for on open', () async {
      final rig = await _open();
      expect(rig.source.reads, 1);
      expect(rig.feed.reads, greaterThanOrEqualTo(1));
    });

    test(
      'refreshReadiness asks the checks and the missed entry again',
      () async {
        final rig = await _open();
        final reads = rig.source.reads;
        final feedReads = rig.feed.reads;
        await rig.cubit.refreshReadiness();
        expect(rig.source.reads, reads + 1);
        expect(rig.feed.reads, feedReads + 1);
      },
    );

    test('a newer message asks again, the first list does not', () async {
      final rig = await _open();
      expect(rig.source.reads, 1);

      rig.home.set(_loaded(facts: HomeFacts(newestMessageAt: _at(-600))));
      await rig.settle();
      expect(rig.source.reads, 1, reason: 'the first list');

      rig.home.set(_loaded(facts: HomeFacts(newestMessageAt: _at(-600))));
      await rig.settle();
      expect(rig.source.reads, 1, reason: 'nothing new');

      rig.home.set(_loaded(facts: HomeFacts(newestMessageAt: _at(-60))));
      await rig.settle();
      expect(rig.source.reads, 2, reason: 'a message came in');

      rig.home.set(_loaded(facts: HomeFacts(newestMessageAt: _at(-300))));
      await rig.settle();
      expect(rig.source.reads, 2, reason: 'an older one');
    });

    test('the first message on a quiet phone asks again', () async {
      final rig = await _open();
      rig.home.set(_loaded());
      await rig.settle();
      expect(rig.source.reads, 1);

      rig.home.set(_loaded(facts: HomeFacts(newestMessageAt: _at(-5))));
      await rig.settle();
      expect(rig.source.reads, 2);
    });
  });

  group('the server', () {
    test('no server saved', () async {
      final rig = await _open();
      rig.home.set(
        const HomeState(status: HomeStatus.failure, hasServer: false),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.noServer);
      expect(rig.model.numeral, const No());
      expect(rig.model.action, const ConnectServer());
    });

    test('stale: an old copy and the time it was true', () async {
      final rig = await _open();
      rig.home.set(_loaded());
      await rig.settle();
      rig.home.set(
        HomeState(
          status: HomeStatus.failure,
          isStale: true,
          lastKnownGoodAt: now,
          topicItems: const [_topic],
          // A sounding alarm from before the server went quiet.
          facts: HomeFacts(
            ringing: RingingFact(
              incidentId: 'inc-1',
              topic: 'prod-db',
              openedAt: _at(-60),
            ),
          ).withoutLive(),
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.stale);
      expect(rig.model.numeral, At(now));
      expect(rig.model.action, const RetryLoad());
    });

    test('load failed with no old copy', () async {
      final rig = await _open();
      rig.home.set(const HomeState(status: HomeStatus.failure));
      await rig.settle();
      expect(rig.kind, HomeCardKind.loadFailed);
      expect(rig.model.numeral, const Unknown());
      expect(rig.model.action, const RetryLoad());
    });

    test('recovers when the list loads', () async {
      final rig = await _open();
      rig.home.set(const HomeState(status: HomeStatus.failure));
      await rig.settle();
      rig.home.set(_loaded());
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);
    });

    test('a server with no topics', () async {
      final rig = await _open();
      rig.home.set(_loaded(items: const []));
      await rig.settle();
      expect(rig.kind, HomeCardKind.noTopics);
      expect(rig.model.numeral, const Number(0));
    });

    test('still loading while the list has not answered', () async {
      final rig = await _open();
      rig.home.set(const HomeState(status: HomeStatus.loading));
      await rig.settle();
      expect(rig.kind, HomeCardKind.loading);
    });
  });

  group('setup', () {
    test('progress, then waiting for the first message, then done', () async {
      final rig = await _open();
      rig.home.set(_loaded());
      await rig.settle();

      rig.setup.set(
        const HomeSetupState(
          phase: HomeSetupPhase.checklist,
          checklist: setupAfterServer,
          firstTopic: 'prod-db',
          watchedTopic: 'prod-db',
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.setup);
      expect(rig.model.numeral, const Count(1, 3));
      expect(rig.model.pips, [PipTone.fine, PipTone.open, PipTone.open]);
      expect(rig.model.action, const ContinueSetup('/topics/prod-db'));

      rig.setup.set(
        const HomeSetupState(
          phase: HomeSetupPhase.checklist,
          checklist: setupFirstMessageOpen,
          firstTopic: 'prod-db',
          watchedTopic: 'prod-db',
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.waiting);
      expect(rig.model.numeral, const NotYet());
      expect(rig.model.action, const GetFirstLine('prod-db'));

      rig.setup.set(const HomeSetupState());
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);
    });

    test('a health issue outranks setup progress', () async {
      final rig = await _open(
        checks: withCheckAt(
          androidChecks(7),
          2,
          ReliabilityState.needsLook,
          reason: 'denied',
        ),
      );
      rig.home.set(_loaded());
      rig.setup.set(
        const HomeSetupState(
          phase: HomeSetupPhase.checklist,
          checklist: setupAfterServer,
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.issueLook);
    });
  });

  group('the missed alarm', () {
    test('shows from the feed and goes when the feed is cleared', () async {
      final rig = await _open();
      rig.home.set(_loaded());
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);

      rig.feed.fact = missedFact(count: 2);
      rig.feed.controller.add(null);
      await rig.settle();
      expect(rig.kind, HomeCardKind.missed);
      expect(rig.model.numeral, const Number(2));
      expect(rig.model.action, const SeeMissed());

      await rig.feed.dismiss(['m0', 'm1']);
      await rig.settle();
      expect(rig.kind, HomeCardKind.idle);
    });

    test('sits above a health issue, below a live alarm', () async {
      final rig = await _open(
        checks: withCheckAt(
          androidChecks(7),
          2,
          ReliabilityState.needsLook,
          reason: 'denied',
        ),
      );
      rig.feed.fact = missedFact();
      rig.home.set(_loaded());
      await rig.cubit.refreshReadiness();
      await rig.settle();
      expect(rig.kind, HomeCardKind.missed);

      rig.home.set(
        _loaded(
          facts: HomeFacts(
            ringing: RingingFact(
              incidentId: 'inc-1',
              topic: 'prod-db',
              openedAt: _at(-10),
            ),
          ),
        ),
      );
      await rig.settle();
      expect(rig.kind, HomeCardKind.ringing);
    });

    test('a failing feed leaves the card as it was', () async {
      final rig = await _open();
      rig.home.set(_loaded());
      await rig.settle();
      // A feed that throws.
      final cubit = HomeCardCubit(
        home: rig.home,
        reliability: rig.reliability,
        setup: rig.setup,
        missed: _ThrowingFeed(),
        testRouteName: 'testRing',
        askPermissionsRouteName: 'askPermissions',
        clock: () => now,
      );
      addTearDown(cubit.close);
      await rig.settle();
      expect(cubit.state.model.kind, HomeCardKind.idle);
    });

    test(
      'reaches the card while the notice slot shows a different notice',
      () async {
        final missed = [
          MissedAlarm(
            incidentId: 'm1',
            topic: 'prod-db',
            at: now.subtract(const Duration(hours: 1)),
            reason: MissedReason.rangUnanswered,
          ),
        ];
        final dismissed = <String>{};
        final incidents = <Incident>[
          Incident(
            id: 'm1',
            topic: 'prod-db',
            state: IncidentStates.expired,
            openedAt: now.subtract(const Duration(hours: 1, minutes: 10)),
            closedAt: now.subtract(const Duration(hours: 1)),
          ),
        ];
        final feed = ReaderMissedAlarmFeed(
          readMissed: () async => missed,
          readDismissed: () => dismissed,
          writeDismissed: (ids) async => dismissed.addAll(ids),
          readIncidents: () => incidents,
          isSetupDone: () async => true,
          clock: () => now,
        );
        addTearDown(feed.close);

        // The notice cubit, with a permission that blocks alarms. That
        // notice outranks the missed alarm, so the slot shows it.
        final shell = FakeShellCubit()
          ..setHealth(
            const ShellHealth(
              missing: [
                DevicePermissionItem(
                  type: DevicePermissionType.notifications,
                  status: DevicePermissionStatus.denied,
                  title: 'Notifications',
                  description: 'No page reaches you',
                  canFix: true,
                ),
              ],
            ),
          );
        final getConnection = FakeGetConnectionUsecase()
          ..result = const ServerConnection(
            serverUrl: 'https://api.critalarm.app',
            adminToken: 'token123',
          ).toSuccess();
        final identityChanges = AccountIdentityChanges();
        final notices = InAppNoticeCubit(
          getConnectionUsecase: getConnection,
          shellCubit: shell,
          identityRepository: FakeIdentityRepo(identityChanges),
          accountRepository: FakeAccountRepo(),
          noticeRepository: FakeInAppNoticeRepository()..now = (() => now),
          readTopics: () async => const [
            Topic(name: 'prod-db', critical: true),
          ],
          clock: () => now,
          identityChanges: identityChanges,
          isSetupDone: () async => true,
          readMissedAlarms: () async => missed,
          readDismissedMissedAlarms: () => dismissed,
          dismissMissedAlarms: feed.dismiss,
          missedAlarmChanges: feed.changes,
        );
        addTearDown(notices.close);
        await notices.load();
        expect(notices.state.noticeType, InAppNoticeType.criticalHealth);

        final rig = _Rig();
        addTearDown(rig.dispose);
        final cubit = HomeCardCubit(
          home: rig.home,
          reliability: rig.reliability,
          setup: rig.setup,
          missed: feed,
          testRouteName: 'testRing',
          askPermissionsRouteName: 'askPermissions',
          clock: () => now,
        );
        addTearDown(cubit.close);
        rig.home.set(_loaded());
        await rig.settle();

        expect(cubit.state.model.kind, HomeCardKind.missed);
        expect(cubit.state.model.numeral, const Number(1));
        expect(
          cubit.state.model.foot,
          HomeCardFoot(
            HomeCardFootSlot.missedRang,
            duration: const Duration(minutes: 10),
            time: now.subtract(const Duration(hours: 1)),
          ),
        );
        // Still the health notice in the slot.
        expect(notices.state.noticeType, InAppNoticeType.criticalHealth);

        // Closing it from the card writes the record the notice reads.
        await feed.dismiss(['m1']);
        await rig.settle();
        expect(dismissed, {'m1'});
        expect(cubit.state.model.kind, HomeCardKind.idle);
      },
    );
  });

  test(
    'closing the entry from the card closes the notice too',
    () async {
      final missed = [
        MissedAlarm(
          incidentId: 'm1',
          topic: 'prod-db',
          at: now.subtract(const Duration(hours: 1)),
          reason: MissedReason.rangUnanswered,
        ),
      ];
      final dismissed = <String>{};
      final feed = ReaderMissedAlarmFeed(
        readMissed: () async => missed,
        readDismissed: () => dismissed,
        writeDismissed: (ids) async => dismissed.addAll(ids),
        readIncidents: () => const [],
        isSetupDone: () async => true,
        clock: () => now,
      );
      addTearDown(feed.close);
      final getConnection = FakeGetConnectionUsecase()
        ..result = const ServerConnection(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'token123',
        ).toSuccess();
      final identityChanges = AccountIdentityChanges();
      final notices = InAppNoticeCubit(
        getConnectionUsecase: getConnection,
        shellCubit: FakeShellCubit(),
        identityRepository: FakeIdentityRepo(identityChanges),
        accountRepository: FakeAccountRepo(),
        noticeRepository: FakeInAppNoticeRepository()..now = (() => now),
        readTopics: () async => const [Topic(name: 'prod-db', critical: true)],
        clock: () => now,
        identityChanges: identityChanges,
        isSetupDone: () async => true,
        readMissedAlarms: () async => missed,
        readDismissedMissedAlarms: () => dismissed,
        dismissMissedAlarms: feed.dismiss,
        missedAlarmChanges: feed.changes,
      );
      addTearDown(notices.close);
      await notices.load();
      expect(notices.state.noticeType, InAppNoticeType.missedAlarm);

      // The card closes it. The notice hears of it through the feed.
      await feed.dismiss(['m1']);
      await pumpEventQueue();
      expect(notices.state.noticeType, InAppNoticeType.none);
    },
  );

  group('actionFor', () {
    test('a ringing alarm opens its incident', () async {
      final rig = await _open();
      expect(
        rig.cubit.actionFor(const OpenAlarm('inc 1')),
        const OpenPath('/incidents/inc%201'),
      );
      expect(
        rig.cubit.actionFor(const OpenIncident('inc-2')),
        const OpenPath('/incidents/inc-2'),
      );
    });

    test('the missed alarm goes by its reason', () async {
      final rig = await _open();
      rig.home.set(_loaded());
      rig.feed.fact = MissedFact(
        notice: missedFact().notice,
        ringDuration: const Duration(minutes: 10),
      );
      await rig.cubit.refreshReadiness();
      await rig.settle();
      // The fixture's reason is "rang, nobody answered": look at the alarm.
      expect(
        rig.cubit.actionFor(const SeeMissed()),
        const OpenPath('/incidents/m0'),
      );

      rig.feed.fact = MissedFact(
        notice: MissedAlarmNotice(
          incidentIds: const ['m9'],
          topic: 'prod-db',
          at: now,
          reason: MissedReason.noPushReached,
        ),
      );
      await rig.cubit.refreshReadiness();
      await rig.settle();
      expect(
        rig.cubit.actionFor(const SeeMissed()),
        const OpenRoute('testRing'),
      );
    });

    test('see missed does nothing once the entry is gone', () async {
      final rig = await _open();
      expect(rig.cubit.actionFor(const SeeMissed()), const NoEffect());
    });

    test('the rest', () async {
      final rig = await _open();
      expect(
        rig.cubit.actionFor(const ConnectServer()),
        const OpenPath('/onboarding/connect'),
      );
      expect(rig.cubit.actionFor(const RetryLoad()), const RefreshHome());
      expect(
        rig.cubit.actionFor(const SendTest()),
        const OpenRoute('testRing'),
      );
      expect(
        rig.cubit.actionFor(const ContinueSetup('/topics/new')),
        const OpenPath('/topics/new'),
      );
      expect(
        rig.cubit.actionFor(const GetFirstLine('prod db')),
        const OpenPath('/topics/prod%20db?curl=1'),
      );
    });

    test('a fix that opens a screen is a route, the others run', () async {
      final rig = await _open();
      expect(
        rig.cubit.actionFor(const Fix(OpenRouteFix('makerGuide'))),
        const OpenRoute('makerGuide'),
      );
      expect(
        rig.cubit.actionFor(
          Fix(
            MissedAlarmFix(
              testRouteName: 'otherTest',
              topic: 'prod-db',
              at: now,
              incidentIds: const ['m0'],
            ),
          ),
        ),
        const OpenRoute('otherTest'),
      );
      expect(
        rig.cubit.actionFor(
          const Fix(AskPermissionFix(DevicePermissionType.notifications)),
        ),
        const OpenRoute('askPermissions'),
      );
      const settings = OpenSystemSettingsFix(
        DevicePermissionType.notifications,
      );
      expect(
        rig.cubit.actionFor(const Fix(settings)),
        const RunReliabilityFix(settings),
      );
      const rerun = RunFix(ReliabilityFixAction.reRegisterPushToken);
      expect(
        rig.cubit.actionFor(const Fix(rerun)),
        const RunReliabilityFix(rerun),
      );
    });
  });

  test('closing stops listening and cancels the timer', () async {
    final rig = await _open();
    rig.home.set(
      _loaded(
        facts: HomeFacts(
          handled: HandledFact(topic: 'prod-db', closedAt: _at(-5)),
        ),
      ),
    );
    await rig.settle();
    expect(rig.liveTimers, hasLength(1));

    await rig.cubit.close();
    expect(rig.liveTimers, isEmpty);
    rig.home.set(_loaded(facts: const HomeFacts(warningCount: 3)));
    rig.feed.controller.add(null);
    await rig.settle();
    expect(rig.cubit.isClosed, isTrue);
  });
}

class _Throwing implements ReliabilityCheckSource {
  @override
  Future<List<ReliabilityCheck>> read() async => throw StateError('no');
}

class _ThrowingFeed implements MissedAlarmFeed {
  @override
  Future<MissedFact?> read() async => throw StateError('disk');

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> dismiss(Iterable<String> incidentIds) async {}
}
