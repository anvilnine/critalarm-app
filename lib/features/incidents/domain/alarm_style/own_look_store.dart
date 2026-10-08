import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:flutter/foundation.dart';

/// What the phone holds about a saved own photo, beside the file: which
/// file it is, its size in pixels and how bright it is.
@immutable
class OwnPhotoRecord {
  const OwnPhotoRecord({
    required this.stamp,
    required this.width,
    required this.height,
    required this.measure,
  });

  /// Names the file this record was written for. A record never describes
  /// another file, so the measure and the pixels cannot disagree.
  final String stamp;

  final int width;
  final int height;
  final OwnPhotoMeasure measure;
}

/// A person's own alarm look, kept on this phone only: one photo, how
/// bright it is, and the colour picked for "I'm up".
///
/// The photo is private. Nothing here is sent to a server, written to a
/// log or handed to analytics, and no native code reads it.
///
/// Four things are kept:
///
/// - One image file in the app's own storage, which no other app can
///   read.
/// - `alarm_style_own_photo`: the [OwnPhotoRecord] for that file.
/// - `alarm_style_own_accent`: the id of the accent colour.
/// - `alarm_style_own_pending`: while a photo is being picked, where the
///   system's picker put its copy, so a copy left behind by an app that
///   was killed mid-pick is found and deleted.
abstract interface class OwnLookStore {
  static const String photoKey = 'alarm_style_own_photo';
  static const String accentKey = 'alarm_style_own_accent';
  static const String pendingKey = 'alarm_style_own_pending';

  /// The largest photo file this will read back, in bytes. The app writes
  /// far less (`OwnPhotoLimits`), so a larger file is not one it wrote.
  static const int maxStoredBytes = 24 * 1024 * 1024;

  /// The record of the saved photo, or null when none is saved or what is
  /// saved does not read back whole.
  OwnPhotoRecord? get photo;

  /// The bytes of the photo file written for the record with [stamp].
  /// Null when that file is gone, is larger than [maxStoredBytes] or
  /// cannot be read.
  ///
  /// By stamp, never "the current photo": a caller that read a record and
  /// then asks for its pixels gets those pixels or nothing, even if
  /// another photo was saved in between.
  Future<Uint8List?> readPhoto(String stamp);

  /// Saves [encoded] as the one photo, with what was measured on it. The
  /// photo saved before is deleted. Throws when the file cannot be
  /// written, and then the photo saved before is still the photo.
  Future<void> savePhoto(
    Uint8List encoded, {
    required int width,
    required int height,
    required OwnPhotoMeasure measure,
  });

  /// The id of the accent picked, or null for none.
  String? get accentId;

  Future<void> setAccent(String accentId);

  /// Deletes the photo and its record. The accent stays.
  Future<void> removePhoto();

  /// Deletes every file in the photo's folder that the record does not
  /// name: a photo whose delete failed, or one written by an app that was
  /// killed before its record was. Called at launch, never during a save.
  Future<void> sweep();

  /// Notes that the system's picker put a copy of a picked photo at
  /// [path], before anything else is done with it.
  Future<void> notePending(String path);

  /// Deletes the copy noted by [notePending], if one is noted and still
  /// there, and forgets the note. Called when a pick ends, however it
  /// ends, and at launch for a pick that never ended.
  Future<void> discardPending();

  /// The phone has left the account this look was made under: the photo,
  /// its record, the accent and any copy a pick left behind all go.
  Future<void> forgetAll();

  /// Fires after anything here changed.
  Stream<void> get changes;
}
