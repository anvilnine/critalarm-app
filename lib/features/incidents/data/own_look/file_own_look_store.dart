import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// [OwnLookStore] as one file in the app's own storage and two keys in
/// its preferences.
///
/// The file is `alarm_look/own_<stamp>.png` under [_root], the app
/// support directory: private to the app, not in the person's photo
/// library, and not shown in the Files app. The record names the file it
/// was written for, and the record is written after the file, so a record
/// never describes pixels it was not measured on. The file saved before
/// is deleted only once the new record is in.
///
/// Nothing here logs: not a path, not a size, not a failure.
class FileOwnLookStore implements OwnLookStore {
  FileOwnLookStore(this._prefs, this._root);

  final SharedPreferences _prefs;

  /// The directory the photo's folder is made in.
  final Future<Directory> Function() _root;

  final _changes = StreamController<void>.broadcast();

  static const String _folder = 'alarm_look';
  static final RegExp _stampShape = RegExp(r'^[0-9a-z]{1,24}$');

  Future<Directory> _dir() async =>
      Directory(p.join((await _root()).path, _folder));

  Future<File> _fileFor(String stamp) async =>
      File(p.join((await _dir()).path, 'own_$stamp.png'));

  @override
  OwnPhotoRecord? get photo {
    try {
      final saved = _prefs.getString(OwnLookStore.photoKey);
      if (saved == null || saved.isEmpty) return null;
      final map = jsonDecode(saved);
      if (map is! Map<String, dynamic>) return null;
      final stamp = map['stamp'];
      final width = map['w'];
      final height = map['h'];
      final measure = OwnPhotoMeasure.decode(map['m']);
      if (stamp is! String || !_stampShape.hasMatch(stamp)) return null;
      if (width is! int || height is! int || width < 1 || height < 1) {
        return null;
      }
      if (measure == null) return null;
      return OwnPhotoRecord(
        stamp: stamp,
        width: width,
        height: height,
        measure: measure,
      );
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> readPhoto() async {
    final record = photo;
    if (record == null) return null;
    try {
      final file = await _fileFor(record.stamp);
      if (!file.existsSync()) return null;
      final length = await file.length();
      if (length <= 0 || length > OwnLookStore.maxStoredBytes) return null;
      return await file.readAsBytes();
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePhoto(
    Uint8List encoded, {
    required int width,
    required int height,
    required OwnPhotoMeasure measure,
  }) async {
    if (encoded.isEmpty || encoded.length > OwnLookStore.maxStoredBytes) {
      throw const FileSystemException('not a photo this store keeps');
    }
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final dir = await _dir();
    await dir.create(recursive: true);
    final file = await _fileFor(stamp);
    // Whole or not at all: written under another name, then moved.
    final part = File('${file.path}.part');
    try {
      await part.writeAsBytes(encoded, flush: true);
      await part.rename(file.path);
    } on Object catch (_) {
      await _delete(part);
      rethrow;
    }
    final saved = await _prefs.setString(
      OwnLookStore.photoKey,
      jsonEncode({
        'stamp': stamp,
        'w': width,
        'h': height,
        'm': jsonDecode(measure.encode()),
      }),
    );
    if (!saved) {
      await _delete(file);
      throw const FileSystemException('the record was not written');
    }
    await _deleteAllBut(stamp);
    _changes.add(null);
  }

  @override
  String? get accentId {
    try {
      final saved = _prefs.getString(OwnLookStore.accentKey);
      return saved == null || saved.isEmpty ? null : saved;
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> setAccent(String accentId) async {
    await _prefs.setString(OwnLookStore.accentKey, accentId);
    _changes.add(null);
  }

  @override
  Future<void> removePhoto() async {
    // The record first: with no record there is no photo, whatever a
    // delete that fails leaves on disk, and the next save or wipe sweeps
    // the folder.
    await _prefs.remove(OwnLookStore.photoKey);
    await _deleteAllBut(null);
    _changes.add(null);
  }

  @override
  Future<void> forgetAll() async {
    await _prefs.remove(OwnLookStore.photoKey);
    await _prefs.remove(OwnLookStore.accentKey);
    await _deleteAllBut(null);
    _changes.add(null);
  }

  /// Empties the photo's folder, keeping the file of [stamp] when one is
  /// named.
  Future<void> _deleteAllBut(String? stamp) async {
    try {
      final dir = await _dir();
      if (!dir.existsSync()) return;
      final keep = stamp == null ? null : (await _fileFor(stamp)).path;
      await for (final entry in dir.list()) {
        if (entry.path == keep) continue;
        await _delete(entry);
      }
    } on Object catch (_) {
      // What could not be listed is swept by the next save or wipe.
    }
  }

  Future<void> _delete(FileSystemEntity entry) async {
    try {
      await entry.delete(recursive: true);
    } on Object catch (_) {
      // Already gone, or held: the next sweep tries again.
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();
}
