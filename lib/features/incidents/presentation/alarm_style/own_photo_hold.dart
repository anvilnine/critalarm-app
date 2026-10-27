import 'dart:ui' as ui;

import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:flutter/foundation.dart';

/// A photo the person framed and has not kept, held in memory for as long
/// as a page lives.
///
/// It is how a person with no plan for it sees their own photo as their
/// alarm before deciding. It writes nothing: no file, no record, no
/// preference, and it does not touch what the alarm screen reads
/// ([heldOwnAlarmStyle]), so an alarm that rings never draws it. It lives
/// only in the memory of whoever created it. Its owner must [dispose] it,
/// and the picture goes with it.
///
/// It holds one picture, already cut to the size it would be kept at and
/// in 8-bit sRGB, which is what the engine's own limits make of any photo
/// ([OwnPhotoLimits]). [encode] turns that same picture into the file
/// that [ImportOwnPhotoUsecase.keep] writes, so keeping it later needs no
/// second pick and no second decode of the picked file.
class OwnPhotoHold extends ChangeNotifier {
  OwnLookPhoto? _photo;
  OwnPhotoMeasure? _measure;
  AlarmStyle? _style;
  OwnLookAccent _accent = ownLookAccents.first;
  bool _isDisposed = false;

  /// Whether a photo is held.
  bool get hasPhoto => _style != null;

  /// The own look built from the held photo, or null when none is held.
  AlarmStyle? get style => _style;

  /// The colour of "I'm up" the person picked for the held photo.
  OwnLookAccent get accent => _accent;

  /// How bright the held photo was measured to be.
  OwnPhotoMeasure? get measure => _measure;

  /// The size of the held picture in pixels, or null when none is held.
  ({int width, int height})? get size {
    final image = _photo?.image;
    return image == null ? null : (width: image.width, height: image.height);
  }

  /// Holds the photo [prepared], in place of any held before. The colour the
  /// person picked stays. Returns false when it could not be made into a
  /// picture, and then what was held before is still held.
  Future<bool> hold(OwnPhotoPrepared prepared) async {
    if (_isDisposed) return false;
    final pixels = prepared.pixels;
    final image = await _imageOf(pixels);
    if (image == null) return false;
    if (_isDisposed) {
      image.dispose();
      return false;
    }
    final old = _photo;
    final photo = OwnLookPhoto(image);
    AlarmStyle style;
    try {
      style = buildOwnAlarmStyle(
        photo: photo,
        measure: prepared.measure,
        accent: _accent,
      );
    } on Object catch (_) {
      photo.release();
      return false;
    }
    _photo = photo;
    _measure = prepared.measure;
    _style = style;
    old?.release();
    notifyListeners();
    return true;
  }

  /// Changes the colour of "I'm up". The held look is rebuilt with it.
  void setAccent(OwnLookAccent accent) {
    if (_isDisposed || accent.id == _accent.id) return;
    _accent = accent;
    final photo = _photo;
    final measure = _measure;
    if (photo != null && measure != null) {
      _style = buildOwnAlarmStyle(
        photo: photo,
        measure: measure,
        accent: accent,
      );
    }
    notifyListeners();
  }

  /// The held photo as an image file, for [ImportOwnPhotoUsecase.keep].
  /// Null when none is held or it cannot be encoded.
  Future<Uint8List?> encode() async {
    final image = _photo?.image;
    if (image == null) return null;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } on Object catch (_) {
      return null;
    }
  }

  /// Lets the held photo go and frees its picture. The colour stays.
  void drop() {
    if (_photo == null) return;
    final photo = _photo;
    _photo = null;
    _measure = null;
    _style = null;
    photo?.release();
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    final photo = _photo;
    _isDisposed = true;
    _photo = null;
    _measure = null;
    _style = null;
    photo?.release();
    super.dispose();
  }

  /// The pixels as a picture. They are 8-bit RGBA already, so this is
  /// not a second decode of the picked file.
  static Future<ui.Image?> _imageOf(OwnPhotoPixels pixels) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(pixels.rgba);
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: pixels.width,
        height: pixels.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      return (await codec.getNextFrame()).image;
    } on Object catch (_) {
      return null;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
