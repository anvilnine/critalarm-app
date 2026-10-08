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
/// Three things are kept:
///
/// - One image file in the app's own storage, which no other app can
///   read.
/// - `alarm_style_own_photo`: the [OwnPhotoRecord] for that file.
/// - `alarm_style_own_accent`: the id of the accent colour.
abstract interface class OwnLookStore {
  static const String photoKey = 'alarm_style_own_photo';
  static const String accentKey = 'alarm_style_own_accent';

  /// The largest photo file this will read back, in bytes. The app writes
  /// far less (`OwnPhotoLimits`), so a larger file is not one it wrote.
  static const int maxStoredBytes = 24 * 1024 * 1024;

  /// The record of the saved photo, or null when none is saved or what is
  /// saved does not read back whole.
  OwnPhotoRecord? get photo;

  /// The bytes of the saved photo. Null when no photo is saved, the file
  /// is gone, it is larger than [maxStoredBytes] or it cannot be read.
  Future<Uint8List?> readPhoto();

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

  /// The phone has left the account this look was made under: the photo,
  /// its record and the accent all go.
  Future<void> forgetAll();

  /// Fires after anything here changed.
  Stream<void> get changes;
}
