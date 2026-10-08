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
/// It is also held only while a paid look may be drawn at all
/// (`mayHold`). With alarm looks locked the picture is let go and nothing
/// is decoded: a person's photo is not kept in memory for a look that
/// cannot ring. The file stays, and the picture is decoded again the
/// moment the plan is back. [hasPhoto] says a photo is saved either way,
/// so it can always be removed.
///
/// The picture stays held under memory pressure. It is at most
/// [OwnPhotoLimits.maxSide] pixels on its long side, about 5 MB, and
/// letting it go would turn the next alarm into the standard look.
class OwnAlarmLookKeeper {
  OwnAlarmLookKeeper(
    this._store, {
    this._decode = decodeOwnPhoto,
    this._mayHold,
    this._recheck = const [],
  });

  final OwnLookStore _store;
  final OwnPhotoDecoder _decode;

  /// Whether a paid look may be drawn right now. Left out, always. It
  /// must answer at once.
  final bool Function()? _mayHold;

  /// Each fires when [_mayHold] may answer differently.
  final List<Stream<Object?>> _recheck;

  final _changes = StreamController<void>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];

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

  /// Whether a photo is saved on this phone, held in memory or not.
  bool get hasPhoto {
    try {
      return _store.photo != null;
    } on Object catch (_) {
      return false;
    }
  }

  bool get _holds {
    try {
      return _mayHold?.call() ?? true;
    } on Object catch (_) {
      return false;
    }
  }

  /// The colour picked for "I'm up".
  OwnLookAccent get accent => ownLookAccentOf(_store.accentId);

  /// Fires after [style] or [accent] changed.
  Stream<void> get changes => _changes.stream;

  /// Loads what is saved, and follows the store and the plan from here
  /// on. Called once at launch, before any screen is drawn.
  ///
  /// It first clears what an earlier run left behind: a copy the system's
  /// picker made for a pick that never ended, and any file in the photo's
  /// folder that the record does not name.
  Future<void> start() async {
    if (_subscriptions.isEmpty) {
      _subscriptions.add(_store.changes.listen((_) => unawaited(refresh())));
      for (final stream in _recheck) {
        _subscriptions.add(stream.listen((_) => unawaited(refresh())));
      }
      await _quietly(_store.discardPending);
      await _quietly(_store.sweep);
    }
    await refresh();
  }

  Future<void> _quietly(Future<void> Function() work) async {
    try {
      await work();
    } on Object catch (_) {}
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
    // No photo, or a look that cannot ring: nothing is held, and a
    // decode that is running is not kept when it lands.
    if (record == null || !_holds) {
      _load++;
      _drop();
      return;
    }
    if (record.stamp == _record?.stamp && _photo?.image != null) {
      // The same photo: only the colour can have changed. The look is
      // rebuilt only when it has, so a check of the plan does not redraw
      // an alarm that is on screen.
      _load++;
      if (_style == null || _styledAccent != accent.id) _restyle();
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

  /// The accent [_style] was built with.
  String? _styledAccent;

  Future<void> _loadPhoto(OwnPhotoRecord record, int load) async {
    ui.Image? image;
    try {
      // A record this build would never have written is not decoded.
      if (record.width <= OwnPhotoLimits.maxSide &&
          record.height <= OwnPhotoLimits.maxSide) {
        // The file of this record, by name: never whatever is current.
        final bytes = await _store.readPhoto(record.stamp);
        if (bytes != null) {
          image = await _decode(bytes, record.width, record.height);
        }
      }
    } on Object catch (_) {
      image = null;
    }
    if (load != _load || !_holds) {
      // Something newer was saved, the photo was removed, or looks were
      // locked, meanwhile.
      image?.dispose();
      if (load == _load) _drop();
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
    _styledAccent = style == null ? null : accent.id;
    holdOwnAlarmStyle(style);
    if (!_changes.isClosed) _changes.add(null);
  }

  void _drop() {
    final photo = _photo;
    _photo = null;
    _record = null;
    _style = null;
    _styledAccent = null;
    // Cleared first, then freed: nothing is handed a picture that is
    // about to go.
    holdOwnAlarmStyle(null);
    photo?.release();
    // Always: with nothing held, whether a photo is saved can still have
    // changed, and the pickers draw from that.
    if (!_changes.isClosed) _changes.add(null);
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
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _load++;
    _drop();
    await _changes.close();
  }
}
