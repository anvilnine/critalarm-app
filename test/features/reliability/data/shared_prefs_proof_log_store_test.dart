import 'dart:convert';

import 'package:critalarm/features/reliability/data/shared_prefs_proof_log_store.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPrefsProofLogStore store;

  Future<void> start([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    store = SharedPrefsProofLogStore(prefs);
  }

  setUp(start);

  test('nothing kept reads as an empty log', () {
    expect(store.read(), isEmpty);
  });

  test('a round trip keeps weeks and both times', () async {
    final entries = [
      ProofEntry(
        weekStart: DateTime(2026, 9, 28),
        rangAt: DateTime.fromMillisecondsSinceEpoch(1790000000 * 1000),
      ),
      ProofEntry(
        weekStart: DateTime(2026, 10, 5),
        rangAt: DateTime.fromMillisecondsSinceEpoch(1790600000 * 1000),
        failedAt: DateTime.fromMillisecondsSinceEpoch(1790500000 * 1000),
      ),
      ProofEntry(
        weekStart: DateTime(2026, 10, 12),
        failedAt: DateTime.fromMillisecondsSinceEpoch(1791100000 * 1000),
      ),
    ];
    await store.write(entries);
    expect(SharedPrefsProofLogStore(prefs).read(), entries);
  });

  test('is written as the documented JSON under one key', () async {
    await store.write([
      ProofEntry(
        weekStart: DateTime(2026, 10, 5),
        rangAt: DateTime.fromMillisecondsSinceEpoch(1790600000 * 1000),
      ),
    ]);
    expect(prefs.getKeys(), {'proof_log'});
    expect(jsonDecode(prefs.getString('proof_log')!), [
      {'w': '2026-10-05', 'r': 1790600000},
    ]);
  });

  test('keeps only the newest 12 weeks on every write', () async {
    await store.write([
      for (var i = 0; i < 15; i++)
        ProofEntry(
          weekStart: DateTime(2026, 1, 5 + 7 * i),
          rangAt: DateTime(2026, 1, 6 + 7 * i),
        ),
    ]);
    final read = store.read();
    expect(read, hasLength(12));
    expect(read.first.key, '2026-01-26');
    expect(read.last.key, '2026-04-13');
  });

  for (final (name, raw) in [
    ('text that is not JSON', 'not json'),
    ('JSON that is not a list', '{"w":"2026-10-05","r":1}'),
    ('a number', '5'),
    ('a list of the wrong things', '[1,"a",null,[]]'),
    ('entries with a bad week', '[{"w":"2026-13-45","r":1},{"w":"x","r":1}]'),
    ('entries with no time', '[{"w":"2026-10-05"}]'),
    ('times of the wrong type', '[{"w":"2026-10-05","r":"a","f":true}]'),
  ]) {
    test('a malformed value reads as empty: $name', () async {
      await start({'proof_log': raw});
      expect(store.read(), isEmpty);
    });
  }

  test('a good entry next to a bad one is kept', () async {
    await start({
      'proof_log': '[{"w":"nope","r":1},{"w":"2026-10-05","r":1790600000}]',
    });
    expect(store.read().single.key, '2026-10-05');
  });

  test('two entries for one week read as one', () async {
    await start({
      'proof_log':
          '[{"w":"2026-10-05","r":1790000000},'
          '{"w":"2026-10-05","f":1790100000}]',
    });
    final read = store.read();
    expect(read, hasLength(1));
    expect(read.single.rangAt, isNotNull);
    expect(read.single.failedAt, isNotNull);
  });

  test('clear drops the key', () async {
    await store.write([
      ProofEntry(
        weekStart: DateTime(2026, 10, 5),
        rangAt: DateTime(2026, 10, 6),
      ),
    ]);
    await store.clear();
    expect(prefs.containsKey('proof_log'), isFalse);
    expect(store.read(), isEmpty);
  });
}
