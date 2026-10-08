import 'dart:io';
import 'dart:typed_data';

import 'package:critalarm/features/incidents/data/own_look/file_own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// The own photo is in no backup: its folder is flagged when it is made
/// and at every launch, and a record that outlived its file is dropped.
void main() {
  late Directory root;
  late SharedPreferences prefs;

  /// What the folder held each time it was flagged.
  late List<({String path, List<String> files})> flagged;

  String folder() => p.join(root.path, 'alarm_look');

  List<String> filesIn(String path) => [
    if (Directory(path).existsSync())
      for (final entry in Directory(path).listSync()) p.basename(entry.path),
  ]..sort();

  FileOwnLookStore storeWith({
    Future<void> Function(String path)? excludeFromBackup,
  }) {
    final store = FileOwnLookStore(
      prefs,
      () async => root,
      excludeFromBackup: excludeFromBackup,
    );
    addTearDown(store.dispose);
    return store;
  }

  Future<void> note(String path) async =>
      flagged.add((path: path, files: filesIn(path)));

  Future<void> save(FileOwnLookStore store) => store.savePhoto(
    Uint8List.fromList(List<int>.generate(64, (i) => i)),
    width: 4,
    height: 4,
    measure: const OwnPhotoMeasure(
      columns: 1,
      rows: 1,
      peaks: [200],
      lows: [10],
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    root = await Directory.systemTemp.createTemp('own_look_backup_test_');
    flagged = [];
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  test('a save flags the folder before the photo is in it', () async {
    final store = storeWith(excludeFromBackup: note);

    await save(store);

    expect(flagged, hasLength(1));
    expect(flagged.single.path, folder());
    expect(flagged.single.files, isEmpty);
    expect(filesIn(folder()), hasLength(1));
  });

  test('every save flags the folder again', () async {
    final store = storeWith(excludeFromBackup: note);

    await save(store);
    await save(store);

    expect(flagged.map((flag) => flag.path), [folder(), folder()]);
  });

  test('the launch sweep flags a folder that was there already', () async {
    await save(storeWith());
    final store = storeWith(excludeFromBackup: note);

    await store.sweep();

    expect(flagged.single.path, folder());
    expect(store.photo, isNotNull);
    expect(filesIn(folder()), hasLength(1));
  });

  test('the launch sweep flags nothing when there is no folder', () async {
    final store = storeWith(excludeFromBackup: note);

    await store.sweep();

    expect(flagged, isEmpty);
    expect(Directory(folder()).existsSync(), isFalse);
  });

  test('a flag that fails does not fail the save or the sweep', () async {
    final store = storeWith(
      excludeFromBackup: (_) async => throw const FileSystemException('no'),
    );

    await save(store);
    await store.sweep();

    expect(store.photo, isNotNull);
    expect(filesIn(folder()), hasLength(1));
  });

  test('with nothing to flag the store works as before', () async {
    final store = storeWith();

    await save(store);
    await store.sweep();

    expect(store.photo, isNotNull);
  });

  group('after a restore', () {
    test('a record whose photo did not come along is dropped', () async {
      final store = storeWith(excludeFromBackup: note);
      await save(store);
      await store.setAccent('mint');
      // What a backup brings back: the preferences, and not the folder.
      await Directory(folder()).delete(recursive: true);
      expect(store.photo, isNotNull);
      final changes = <void>[];
      final sub = store.changes.listen(changes.add);
      addTearDown(sub.cancel);

      await store.sweep();
      await pumpEventQueue();

      expect(store.photo, isNull);
      expect(prefs.getString(OwnLookStore.photoKey), isNull);
      expect(changes, hasLength(1));
      // The colour is taste and holds nothing private.
      expect(store.accentId, 'mint');
    });

    test('a record whose photo is there is kept', () async {
      final store = storeWith();
      await save(store);
      final stamp = store.photo!.stamp;

      await store.sweep();

      expect(store.photo?.stamp, stamp);
      expect(await store.readPhoto(stamp), isNotNull);
    });
  });
}
