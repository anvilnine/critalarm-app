import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';

/// Decodes [bytes], an image file, to a picture [width] by [height]. Null
/// for anything else: bytes that are not an image, or an image of another
/// size.
typedef OwnPhotoDecoder =
    Future<ui.Image?> Function(Uint8List bytes, int width, int height);

/// The engine's decoder. It reads the header first and decodes only a
/// picture of the size the record names, so a file that grew on disk is
/// never decoded.
Future<ui.Image?> decodeOwnPhoto(Uint8List bytes, int width, int height) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width != width || descriptor.height != height) return null;
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

/// Keeps the own look ready in memory, so an alarm that rings has nothing
/// to load.
///
/// All the file and image work of the own look happens here, ahead of
/// time: at launch ([start]), and when the person changes the photo or
/// the colour. The result is one `AlarmStyle` handed to
/// [holdOwnAlarmStyle]. The alarm screen only ever reads that field.
///
/// The look is held only when everything is in order: a record that reads
/// back whole, the file it names, and a decode that gave a picture of the
/// recorded size. Anything else (no photo, a missing or broken file, a
/// decode that failed for want of memory, a decode still running) holds
/// nothing, and the alarm screen draws the standard look. Nothing here
/// throws, and nothing here deletes a photo because it failed to load.
///
/// The picture stays held under memory pressure. It is at most
/// [OwnPhotoLimits.maxSide] pixels on its long side, about 5 MB, and
/// letting it go would turn the next alarm into the standard look.
class OwnAlarmLookKeeper {
  OwnAlarmLookKeeper(this._store, {this._decode = decodeOwnPhoto});

  final OwnLookStore _store;
  final OwnPhotoDecoder _decode;
  final _changes = StreamController<void>.broadcast();
  StreamSubscription<void>? _storeChanges;

  OwnLookPhoto? _photo;
  OwnPhotoRecord? _record;
  AlarmStyle? _style;

  /// Goes up with every load, so the answer of an older one is dropped.
  int _load = 0;
  Future<void>? _loading;

  /// The own look, or null while it cannot be drawn.
  AlarmStyle? get style => _style;

  /// Whether the own look can be drawn right now.
  bool get isReady => _style != null;

  /// The colour picked for "I'm up".
  OwnLookAccent get accent => ownLookAccentOf(_store.accentId);

  /// Fires after [style] or [accent] changed.
  Stream<void> get changes => _changes.stream;

  /// Loads what is saved, and follows the store from here on. Called once
  /// at launch, before any screen is drawn.
  Future<void> start() {
    _storeChanges ??= _store.changes.listen((_) => unawaited(refresh()));
    return refresh();
  }

  /// Brings what is held in line with what is saved. It ends when the
  /// look is held or is known not to be.
  Future<void> refresh() async {
    OwnPhotoRecord? record;
    try {
      record = _store.photo;
    } on Object catch (_) {
      record = null;
    }
    if (record == null) {
      _load++;
      _drop();
      return;
    }
    if (record.stamp == _record?.stamp && _photo?.image != null) {
      // The same photo: only the colour can have changed.
      _load++;
      _restyle();
      return;
    }
    final waiting = _loading;
    if (waiting != null && record.stamp == _loadingStamp) return waiting;
    final load = ++_load;
    _loadingStamp = record.stamp;
    final work = _loadPhoto(record, load);
    _loading = work;
    try {
      await work;
    } finally {
      if (identical(_loading, work)) {
        _loading = null;
        _loadingStamp = null;
      }
    }
  }

  String? _loadingStamp;

  Future<void> _loadPhoto(OwnPhotoRecord record, int load) async {
    ui.Image? image;
    try {
      // A record this build would never have written is not decoded.
      if (record.width <= OwnPhotoLimits.maxSide &&
          record.height <= OwnPhotoLimits.maxSide) {
        final bytes = await _store.readPhoto();
        if (bytes != null) {
          image = await _decode(bytes, record.width, record.height);
        }
      }
    } on Object catch (_) {
      image = null;
    }
    if (load != _load) {
      // Something newer was saved, or the photo was removed, meanwhile.
      image?.dispose();
      return;
    }
    if (image == null) {
      _drop();
      return;
    }
    final old = _photo;
    _photo = OwnLookPhoto(image);
    _record = record;
    _restyle();
    old?.release();
  }

  void _restyle() {
    final photo = _photo;
    final record = _record;
    if (photo == null || record == null) return;
    AlarmStyle? style;
    try {
      style = buildOwnAlarmStyle(
        photo: photo,
        measure: record.measure,
        accent: accent,
      );
    } on Object catch (_) {
      style = null;
    }
    _style = style;
    holdOwnAlarmStyle(style);
    _changes.add(null);
  }

  void _drop() {
    final had = _style != null || _photo != null;
    final photo = _photo;
    _photo = null;
    _record = null;
    _style = null;
    // Cleared first, then freed: nothing is handed a picture that is
    // about to go.
    holdOwnAlarmStyle(null);
    photo?.release();
    if (had) _changes.add(null);
  }

  /// Saves the colour of "I'm up". The look is rebuilt at once.
  Future<void> setAccent(OwnLookAccent accent) async {
    await _store.setAccent(accent.id);
    await refresh();
  }

  /// Deletes the photo. The look is gone from memory before the file is.
  Future<void> removePhoto() async {
    _load++;
    _drop();
    await _store.removePhoto();
  }

  Future<void> dispose() async {
    await _storeChanges?.cancel();
    _storeChanges = null;
    _load++;
    _drop();
    await _changes.close();
  }
}
