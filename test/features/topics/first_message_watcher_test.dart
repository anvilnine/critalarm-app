import 'dart:async';

import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/topics/data/api_first_message_source.dart';
import 'package:critalarm/features/topics/data/prefs_first_message_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_source.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends Mock implements ApiClient {}

/// A timer the test fires by hand.
class _Timer implements Timer {
  _Timer(this.duration, this.onFire);

  final Duration duration;
  final void Function() onFire;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

/// A source the test scripts answer by answer.
class _Source implements FirstMessageSource {
  FirstMessageBaseline baseline = const FirstMessageBaseline.noTest();
  Object? baselineError;
  final List<Object> answers = [];
  final List<String> sinces = [];
  int baselineReads = 0;

  @override
  Future<List<String>> newerThan(String topic, String since) async {
    sinces.add(since);
    if (answers.isEmpty) return const [];
    final next = answers.removeAt(0);
    if (next is List<String>) return next;
    throw next as Exception;
  }

  @override
  Future<FirstMessageBaseline> testBaseline() async {
    baselineReads++;
    final error = baselineError;
    if (error != null) throw error as Exception;
    return baseline;
  }
}

void main() {
  late SharedPreferences prefs;
  late PrefsFirstMessageStore store;
  late _Source source;
  late List<_Timer> timers;
  late FirstMessageWatcher watcher;
  final openedAt = DateTime.fromMillisecondsSinceEpoch(1790000000 * 1000);

  FirstMessageWatcher build() => FirstMessageWatcher(
    store: store,
    source: source,
    now: () => openedAt,
    timer: (duration, onFire) {
      final timer = _Timer(duration, onFire);
      timers.add(timer);
      return timer;
    },
  );

  /// Fires the newest timer and lets the poll it starts finish.
  Future<void> fire() async {
    final timer = timers.last;
    expect(timer.cancelled, isFalse, reason: 'the timer was cancelled');
    timer.onFire();
    await pumpEventQueue();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PrefsFirstMessageStore(prefs);
    source = _Source();
    timers = [];
    watcher = build();
    addTearDown(() => watcher.dispose());
  });

  group('the cursor', () {
    test('is the test message id after a server-sent test', () async {
      source.baseline = const FirstMessageBaseline.after('m_test');

      await watcher.start('nightly');

      expect(source.sinces, ['m_test']);
      expect(store.cursorFor('nightly'), 'm_test');
    });

    test('is the unix second the watch began when no test was sent', () async {
      await watcher.start('nightly');

      expect(source.sinces, ['1790000000']);
      expect(store.cursorFor('nightly'), '1790000000');
    });

    test('is read from the phone when one was saved before', () async {
      await store.saveCursor('nightly', 'm_saved');
      source.baseline = const FirstMessageBaseline.after('m_test');

      await watcher.start('nightly');

      expect(source.sinces, ['m_saved']);
      expect(source.baselineReads, 0);
    });

    test('is kept per topic', () async {
      await store.saveCursor('other', 'm_other');

      await watcher.start('nightly');

      expect(store.cursorFor('other'), 'm_other');
      expect(store.cursorFor('nightly'), '1790000000');
    });

    test('waits for the test message when it cannot be read yet', () async {
      source.baselineError = Exception('offline');

      await watcher.start('nightly');
      expect(source.sinces, isEmpty, reason: 'no poll without a cursor');
      expect(store.cursorFor('nightly'), isNull);

      source
        ..baselineError = null
        ..baseline = const FirstMessageBaseline.after('m_test');
      await fire();

      expect(source.sinces, ['m_test']);
    });

    test(
      'falls back to the time the watch began when the test stays unreadable',
      () async {
        source.baselineError = Exception('offline');

        await watcher.start('nightly');
        for (var i = 1; i < FirstMessageWatcher.baselineTries; i++) {
          await fire();
        }

        expect(source.baselineReads, FirstMessageWatcher.baselineTries);
        expect(source.sinces, ['1790000000']);
      },
    );
  });

  group('the first message', () {
    test('sets the flag and tells the listener', () async {
      final seen = <bool>[];
      watcher.changes.listen(seen.add);
      source.answers.addAll([
        <String>[],
        ['m_1'],
      ]);

      await watcher.start('nightly');
      expect(store.isReceived, isFalse);
      expect(watcher.isReceived, isFalse);

      await fire();

      expect(store.isReceived, isTrue);
      expect(watcher.isReceived, isTrue);
      expect(seen, [true]);
    });

    test('stops the polling once it has landed', () async {
      source.answers.add(['m_1']);

      await watcher.start('nightly');

      expect(timers.where((timer) => !timer.cancelled), isEmpty);
      expect(source.sinces, hasLength(1));
    });

    test('the setup test is never counted: it is the cursor', () async {
      // The server answers nothing newer than the test message.
      source.baseline = const FirstMessageBaseline.after('m_test');

      await watcher.start('nightly');
      await fire();

      expect(store.isReceived, isFalse);
      expect(source.sinces, everyElement('m_test'));
    });

    test('the flag is written once', () async {
      source.answers.add(['m_1']);
      await watcher.start('nightly');
      expect(store.isReceived, isTrue);

      // A second watcher, say on Home, starts on a phone that has it.
      final second = build();
      addTearDown(second.dispose);
      final seen = <bool>[];
      second.changes.listen(seen.add);
      await second.start('nightly');

      expect(second.isReceived, isTrue);
      expect(source.sinces, hasLength(1), reason: 'no poll once received');
      expect(seen, isEmpty);
    });

    test('an arrival known from an alarm sets the flag with no poll', () async {
      final seen = <bool>[];
      watcher.changes.listen(seen.add);
      await watcher.start('nightly');
      final waiting = timers.last;

      await watcher.arrived();
      await watcher.arrived();
      await pumpEventQueue();

      expect(store.isReceived, isTrue);
      expect(seen, [true]);
      expect(waiting.cancelled, isTrue);
      expect(source.sinces, hasLength(1));
    });

    test('the flag stays set when the topic is deleted', () async {
      source.answers.add(['m_1']);
      await watcher.start('nightly');

      await store.forgetTopic('nightly');

      expect(store.cursorFor('nightly'), isNull);
      expect(store.isReceived, isTrue);
    });
  });

  group('polling', () {
    test('runs every five seconds', () async {
      await watcher.start('nightly');
      await fire();
      await fire();

      expect(source.sinces, hasLength(3));
      expect(
        timers.map((timer) => timer.duration),
        everyElement(
          const Duration(seconds: 5),
        ),
      );
    });

    test('a failed poll keeps polling, further apart each time', () async {
      source.answers.addAll([
        Exception('offline'),
        Exception('offline'),
        <String>[],
        ['m_1'],
      ]);

      await watcher.start('nightly');
      expect(timers.last.duration, const Duration(seconds: 10));
      await fire();
      expect(timers.last.duration, const Duration(seconds: 20));
      await fire();
      // One good answer and the pace is back.
      expect(timers.last.duration, const Duration(seconds: 5));
      await fire();

      expect(store.isReceived, isTrue);
    });

    test('the wait between failed polls stops growing at a minute', () async {
      source.answers.addAll(List.filled(8, Exception('offline')));

      await watcher.start('nightly');
      for (var i = 0; i < 7; i++) {
        await fire();
      }

      expect(timers.last.duration, const Duration(minutes: 1));
    });

    test('stops in the background and polls at once on the way back', () async {
      await watcher.start('nightly');
      final waiting = timers.last;

      watcher.pause();
      expect(waiting.cancelled, isTrue);
      expect(source.sinces, hasLength(1));

      watcher.resume();
      await pumpEventQueue();
      expect(source.sinces, hasLength(2));
      expect(timers.last.cancelled, isFalse);
    });

    test('resume does nothing before the watch has started', () async {
      watcher.resume();
      await pumpEventQueue();

      expect(source.sinces, isEmpty);
      expect(timers, isEmpty);
    });

    test('stops when disposed', () async {
      await watcher.start('nightly');
      final waiting = timers.last;

      await watcher.dispose();

      expect(waiting.cancelled, isTrue);
      watcher.resume();
      await pumpEventQueue();
      expect(source.sinces, hasLength(1));
    });

    test('an answer that lands after dispose sets nothing', () async {
      final gate = Completer<List<String>>();
      final slow = _SlowSource(gate);
      final slowWatcher = FirstMessageWatcher(
        store: store,
        source: slow,
        now: () => openedAt,
        timer: _Timer.new,
      );

      final started = slowWatcher.start('nightly');
      await pumpEventQueue();
      await slowWatcher.dispose();
      gate.complete(['m_1']);
      await started;

      expect(store.isReceived, isFalse);
    });
  });

  group('against the api', () {
    late _Api api;
    late ApiFirstMessageSource apiSource;
    var testIncidents = <String>{};

    Message message(String id, {int time = 0, String event = 'message'}) =>
        Message(
          id: id,
          topic: 'nightly',
          time: time,
          event: event,
          title: 'db01',
          message: 'disk full',
        );

    setUp(() {
      api = _Api();
      testIncidents = {};
      apiSource = ApiFirstMessageSource(
        api: api,
        testIncidentIds: () => testIncidents,
      );
    });

    test('a message comes back as its id and nothing else', () async {
      when(
        () => api.pollMessages('nightly', poll: 1, since: 'm_0'),
      ).thenAnswer((_) async => [message('m_1'), message('m_2')]);

      final ids = await apiSource.newerThan('nightly', 'm_0');

      // The type is the proof: a list of ids has no room for a title or a
      // body.
      expect(ids, isA<List<String>>());
      expect(ids, ['m_1', 'm_2']);
    });

    test('a row that is not a message is not counted', () async {
      when(
        () => api.pollMessages('nightly', poll: 1, since: 'm_0'),
      ).thenAnswer((_) async => [message('m_1', event: 'keepalive')]);

      expect(await apiSource.newerThan('nightly', 'm_0'), isEmpty);
    });

    test('no test sent: there is no test message to start after', () async {
      expect(
        await apiSource.testBaseline(),
        const FirstMessageBaseline.noTest(),
      );
      verifyNever(() => api.getIncident(any()));
    });

    test('the baseline is the newest message of the setup tests', () async {
      testIncidents = {'inc_1', 'inc_2'};
      when(() => api.getIncident('inc_1')).thenAnswer(
        (_) async => Incident(
          id: 'inc_1',
          topic: 'nightly',
          messages: [message('m_a', time: 100)],
        ),
      );
      when(() => api.getIncident('inc_2')).thenAnswer(
        (_) async => Incident(
          id: 'inc_2',
          topic: 'nightly',
          messages: [message('m_b', time: 300), message('m_c', time: 200)],
        ),
      );

      expect(
        await apiSource.testBaseline(),
        const FirstMessageBaseline.after('m_b'),
      );
    });

    test('a test incident the server no longer has is passed over', () async {
      testIncidents = {'inc_gone'};
      when(
        () => api.getIncident('inc_gone'),
      ).thenThrow(const ApiException(statusCode: 404, message: 'not found'));

      expect(
        await apiSource.testBaseline(),
        const FirstMessageBaseline.noTest(),
      );
    });

    test('a test incident that cannot be read is an error, not a guess', () {
      testIncidents = {'inc_1'};
      when(() => api.getIncident('inc_1')).thenThrow(Exception('offline'));

      expect(apiSource.testBaseline(), throwsException);
    });

    test('the sync cursor of the topic is left alone', () async {
      final sync = MessageSyncService(prefs, api);
      when(
        () => api.pollMessages('nightly', poll: 1, since: any(named: 'since')),
      ).thenAnswer((_) async => [message('m_1')]);
      final real = FirstMessageWatcher(
        store: store,
        source: apiSource,
        now: () => openedAt,
        timer: _Timer.new,
      );
      addTearDown(real.dispose);

      await real.start('nightly');

      expect(store.isReceived, isTrue);
      expect(sync.lastMessageId('nightly'), isNull);
    });

    test('nothing the phone saves holds a title or a body', () async {
      when(
        () => api.pollMessages('nightly', poll: 1, since: any(named: 'since')),
      ).thenAnswer((_) async => [message('m_1')]);
      final real = FirstMessageWatcher(
        store: store,
        source: apiSource,
        now: () => openedAt,
        timer: _Timer.new,
      );
      addTearDown(real.dispose);

      await real.start('nightly');

      for (final key in prefs.getKeys()) {
        final value = prefs.get(key).toString();
        expect(value.contains('db01'), isFalse, reason: key);
        expect(value.contains('disk full'), isFalse, reason: key);
      }
    });
  });
}

class _SlowSource implements FirstMessageSource {
  _SlowSource(this.gate);

  final Completer<List<String>> gate;

  @override
  Future<List<String>> newerThan(String topic, String since) => gate.future;

  @override
  Future<FirstMessageBaseline> testBaseline() async =>
      const FirstMessageBaseline.noTest();
}
