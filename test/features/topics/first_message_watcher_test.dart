import 'dart:async';

import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
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

FirstMessagePage _page({List<String> candidates = const [], String? newest}) =>
    FirstMessagePage(candidates: candidates, newestId: newest);

/// A source the test scripts answer by answer. With nothing scripted it
/// answers an empty read.
class _Source implements FirstMessageSource {
  final List<Object> answers = [];
  final List<String> sinces = [];

  @override
  Future<FirstMessagePage> read(String topic, String since) async {
    sinces.add(since);
    if (answers.isEmpty) return const FirstMessagePage.empty();
    final next = answers.removeAt(0);
    if (next is FirstMessagePage) return next;
    throw next as Exception;
  }
}

void main() {
  late SharedPreferences prefs;
  late PrefsFirstMessageStore store;
  late _Source source;
  late List<_Timer> timers;
  late FirstMessageWatcher watcher;

  FirstMessageWatcher build() => FirstMessageWatcher(
    store: store,
    source: source,
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

  group('the baseline', () {
    test('is the newest message the topic already holds', () async {
      source.answers.add(_page(newest: 'm_test'));

      await watcher.start('nightly');

      expect(source.sinces, [FirstMessageSource.everything]);
      expect(store.cursorFor('nightly'), 'm_test');
      expect(store.isReceived, isFalse);
    });

    test('a message already there is the baseline, never the first', () async {
      // Something the user sent before the watch began.
      source.answers.add(_page(candidates: ['m_old'], newest: 'm_old'));

      await watcher.start('nightly');

      expect(store.isReceived, isFalse);
      expect(store.cursorFor('nightly'), 'm_old');
    });

    test('the next poll asks for what came after it', () async {
      source.answers.add(_page(newest: 'm_test'));

      await watcher.start('nightly');
      await fire();

      expect(source.sinces, [FirstMessageSource.everything, 'm_test']);
    });

    test('on an empty topic everything that arrives counts', () async {
      await watcher.start('nightly');

      expect(store.cursorFor('nightly'), FirstMessageSource.everything);
      expect(store.isReceived, isFalse);

      source.answers.add(_page(candidates: ['m_1'], newest: 'm_1'));
      await fire();

      expect(source.sinces, [
        FirstMessageSource.everything,
        FirstMessageSource.everything,
      ]);
      expect(store.isReceived, isTrue);
    });

    test('an empty topic is remembered across a restart', () async {
      await watcher.start('nightly');
      await watcher.dispose();

      // The message lands while nothing is watching. A new watch must not
      // take it for the baseline.
      source.answers.add(_page(candidates: ['m_1'], newest: 'm_1'));
      final second = build();
      addTearDown(second.dispose);
      await second.start('nightly');

      expect(store.isReceived, isTrue);
    });

    test('is read from the phone when one was saved before', () async {
      await store.saveCursor('nightly', 'm_saved');

      await watcher.start('nightly');

      expect(source.sinces, ['m_saved']);
    });

    test('is kept per topic', () async {
      await store.saveCursor('other', 'm_other');
      source.answers.add(_page(newest: 'm_test'));

      await watcher.start('nightly');

      expect(store.cursorFor('other'), 'm_other');
      expect(store.cursorFor('nightly'), 'm_test');
    });

    test('is not set while the server cannot be asked', () async {
      source.answers.add(Exception('offline'));

      await watcher.start('nightly');
      expect(store.cursorFor('nightly'), isNull);

      source.answers.add(_page(newest: 'm_test'));
      await fire();
      expect(store.cursorFor('nightly'), 'm_test');
    });

    test('the phone clock plays no part, fast or slow', () async {
      // The watcher takes no clock at all, and no cursor is ever a time:
      // what it saves and sends is a message id or "everything".
      source.answers.addAll([
        _page(newest: 'm_test'),
        const FirstMessagePage.empty(),
        _page(candidates: ['m_1'], newest: 'm_1'),
      ]);

      await watcher.start('nightly');
      await fire();
      await fire();

      expect(store.isReceived, isTrue);
      for (final since in source.sinces) {
        expect(int.tryParse(since), isNull, reason: '$since is a time');
      }
      expect(int.tryParse(store.cursorFor('nightly')!), isNull);
    });
  });

  group('the first message', () {
    setUp(() => source.answers.add(_page(newest: 'm_test')));

    test('sets the flag and tells the listener', () async {
      final seen = <bool>[];
      watcher.changes.listen(seen.add);
      source.answers.addAll([
        const FirstMessagePage.empty(),
        _page(candidates: ['m_1'], newest: 'm_1'),
      ]);

      await watcher.start('nightly');
      await fire();
      expect(store.isReceived, isFalse);
      expect(watcher.isReceived, isFalse);

      await fire();

      expect(store.isReceived, isTrue);
      expect(watcher.isReceived, isTrue);
      expect(seen, [true]);
    });

    test('stops the polling once it has landed', () async {
      source.answers.add(_page(candidates: ['m_1'], newest: 'm_1'));

      await watcher.start('nightly');
      await fire();

      expect(timers.where((timer) => !timer.cancelled), isEmpty);
      expect(source.sinces, hasLength(2));
    });

    test('a second test alarm does not tick, and is stepped past', () async {
      // A test sent again, from setup or from Settings: a newer message
      // with no candidate in it.
      source.answers.add(_page(newest: 'm_test_2'));

      await watcher.start('nightly');
      await fire();

      expect(store.isReceived, isFalse);
      expect(store.cursorFor('nightly'), 'm_test_2');

      await fire();
      expect(source.sinces.last, 'm_test_2');
    });

    test('the flag is written once', () async {
      source.answers.add(_page(candidates: ['m_1'], newest: 'm_1'));
      await watcher.start('nightly');
      await fire();
      expect(store.isReceived, isTrue);
      final reads = source.sinces.length;

      // A second watcher, say on Home, starts on a phone that has it.
      final second = build();
      addTearDown(second.dispose);
      final seen = <bool>[];
      second.changes.listen(seen.add);
      await second.start('nightly');

      expect(second.isReceived, isTrue);
      expect(source.sinces, hasLength(reads), reason: 'no poll once received');
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
      source.answers.add(_page(candidates: ['m_1'], newest: 'm_1'));
      await watcher.start('nightly');
      await fire();

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
        everyElement(const Duration(seconds: 5)),
      );
    });

    test('a failed poll keeps polling, further apart each time', () async {
      source.answers.addAll([
        Exception('offline'),
        Exception('offline'),
        _page(newest: 'm_test'),
        _page(candidates: ['m_1'], newest: 'm_1'),
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
      await store.saveCursor('nightly', 'm_test');
      final gate = Completer<FirstMessagePage>();
      final slowWatcher = FirstMessageWatcher(
        store: store,
        source: _SlowSource(gate),
        timer: _Timer.new,
      );

      final started = slowWatcher.start('nightly');
      await pumpEventQueue();
      await slowWatcher.dispose();
      gate.complete(_page(candidates: ['m_1'], newest: 'm_1'));
      await started;

      expect(store.isReceived, isFalse);
    });
  });

  group('against the api', () {
    late _Api api;
    late ApiFirstMessageSource apiSource;

    Message message(
      String id, {
      String title = 'db01',
      String event = 'message',
    }) => Message(
      id: id,
      topic: 'nightly',
      event: event,
      title: title,
      message: 'disk full',
    );

    Message testAlarm(String id) =>
        message(id, title: IncidentKinds.testAlarmTitle);

    void answers(List<Message> messages) => when(
      () => api.pollMessages('nightly', poll: 1, since: any(named: 'since')),
    ).thenAnswer((_) async => messages);

    setUp(() {
      api = _Api();
      apiSource = ApiFirstMessageSource(api: api);
    });

    test('a message comes back as its id and nothing else', () async {
      answers([message('m_1'), message('m_2')]);

      final page = await apiSource.read('nightly', 'm_0');

      // The type is the proof: ids have no room for a title or a body.
      expect(page.candidates, isA<List<String>>());
      expect(page.candidates, ['m_1', 'm_2']);
      expect(page.newestId, 'm_2');
      verify(() => api.pollMessages('nightly', poll: 1, since: 'm_0'));
    });

    test('a test alarm is never a candidate, but moves the newest', () async {
      answers([message('m_1'), testAlarm('m_test')]);

      final page = await apiSource.read('nightly', 'm_0');

      expect(page.candidates, ['m_1']);
      expect(page.newestId, 'm_test');
    });

    test('a read of only test alarms has no candidate', () async {
      answers([testAlarm('m_test'), testAlarm('m_test_2')]);

      final page = await apiSource.read('nightly', 'all');

      expect(page.candidates, isEmpty);
      expect(page.newestId, 'm_test_2');
    });

    test('a row that is not a message is not counted', () async {
      answers([message('m_1', event: 'keepalive')]);

      expect((await apiSource.read('nightly', 'm_0')).candidates, isEmpty);
    });

    test('an empty answer is an empty page', () async {
      answers([]);

      final page = await apiSource.read('nightly', 'all');

      expect(page.candidates, isEmpty);
      expect(page.newestId, isNull);
    });

    FirstMessageWatcher real() {
      final real = FirstMessageWatcher(
        store: store,
        source: apiSource,
        timer: (duration, onFire) {
          final timer = _Timer(duration, onFire);
          timers.add(timer);
          return timer;
        },
      );
      addTearDown(real.dispose);
      return real;
    }

    test('a second setup test alarm never ticks the row', () async {
      answers([testAlarm('m_test')]);
      final watch = real();
      await watch.start('nightly');

      answers([testAlarm('m_test_2')]);
      await fire();
      expect(store.isReceived, isFalse);

      answers([message('m_mine')]);
      await fire();
      expect(store.isReceived, isTrue);
    });

    test('the sync cursor of the topic is left alone', () async {
      final sync = MessageSyncService(prefs, api);
      answers([testAlarm('m_test')]);
      final watch = real();
      await watch.start('nightly');
      answers([message('m_1')]);
      await fire();

      expect(store.isReceived, isTrue);
      expect(sync.lastMessageId('nightly'), isNull);
    });

    test('nothing the phone saves holds a title or a body', () async {
      answers([message('m_0')]);
      final watch = real();
      await watch.start('nightly');
      answers([message('m_1')]);
      await fire();
      expect(store.isReceived, isTrue);

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

  final Completer<FirstMessagePage> gate;

  @override
  Future<FirstMessagePage> read(String topic, String since) => gate.future;
}
