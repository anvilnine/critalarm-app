import 'dart:convert';

import 'package:critalarm/core/alarm/alarm_signal_store.dart';
import 'package:critalarm/core/alarm/alarm_signals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late AlarmSignalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = AlarmSignalStore(prefs);
  });

  test('nothing saved means both are off for every topic', () {
    final signals = store.read();

    expect(signals, const AlarmSignals());
    expect(signals.flashFor('backups'), isFalse);
    expect(signals.vibrationFor('backups'), isFalse);
  });

  test('a switch is kept per topic', () async {
    await store.setFlash('backups', on: true);
    await store.setStrongVibration('deploys', on: true);

    final signals = store.read();
    expect(signals.flashFor('backups'), isTrue);
    expect(signals.vibrationFor('backups'), isFalse);
    expect(signals.flashFor('deploys'), isFalse);
    expect(signals.vibrationFor('deploys'), isTrue);
    expect(signals.flashFor('never-touched'), isFalse);
  });

  test('what was saved is there after a restart', () async {
    await store.setFlash('backups', on: true);
    await store.setStrongVibration('backups', on: true);

    // A second store over the same preferences is what a relaunch looks like.
    final afterRestart = AlarmSignalStore(prefs).read();
    expect(afterRestart.flashFor('backups'), isTrue);
    expect(afterRestart.vibrationFor('backups'), isTrue);
  });

  test('turning one off leaves the other and the other topics alone', () async {
    await store.setFlash('backups', on: true);
    await store.setFlash('deploys', on: true);
    await store.setStrongVibration('backups', on: true);

    await store.setFlash('backups', on: false);

    final signals = store.read();
    expect(signals.flashFor('backups'), isFalse);
    expect(signals.flashFor('deploys'), isTrue);
    expect(signals.vibrationFor('backups'), isTrue);
  });

  test('turning on twice keeps one entry', () async {
    await store.setFlash('backups', on: true);
    await store.setFlash('backups', on: true);

    expect(jsonDecode(prefs.getString('alarm_flash_topics')!), ['backups']);
  });

  test('the rows are the plain keys the native readers use', () async {
    await store.setFlash('b', on: true);
    await store.setFlash('a', on: true);
    await store.setStrongVibration('a', on: true);

    expect(AlarmSignalStore.flashKey, 'alarm_flash_topics');
    expect(AlarmSignalStore.vibrationKey, 'alarm_strong_vibration_topics');
    expect(prefs.getString('alarm_flash_topics'), '["a","b"]');
    expect(prefs.getString('alarm_strong_vibration_topics'), '["a"]');
  });

  test('a row that is not a list of names reads as off', () async {
    await prefs.setString('alarm_flash_topics', '{"backups":true}');
    await prefs.setString('alarm_strong_vibration_topics', 'not json');

    expect(store.read(), const AlarmSignals());
  });

  test('an empty topic name is never saved', () async {
    await store.setFlash('', on: true);

    expect(store.read().flashTopics, isEmpty);
  });
}
