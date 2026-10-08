import 'dart:async';
import 'dart:ui' as ui;

import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:flutter/widgets.dart';

/// Decodes the saved own photo to a small picture, [height] pixels tall.
/// Null when no photo is saved or it cannot be read.
///
/// The full picture is never decoded: the codec scales while it decodes,
/// so what is held in memory is a thumbnail of a few kilobytes and the
/// file's bytes are let go as soon as it is made.
Future<ui.Image?> loadOwnLookThumbnail(
  OwnLookStore store, {
  required int height,
}) async {
  ui.Codec? codec;
  try {
    final record = store.photo;
    if (record == null) return null;
    // A record this build would never have written is not decoded.
    if (record.width > OwnPhotoLimits.maxSide ||
        record.height > OwnPhotoLimits.maxSide) {
      return null;
    }
    final bytes = await store.readPhoto(record.stamp);
    if (bytes == null) return null;
    codec = await ui.instantiateImageCodec(bytes, targetHeight: height);
    return (await codec.getNextFrame()).image;
  } on Object catch (_) {
    return null;
  } finally {
    codec?.dispose();
  }
}

/// The saved own photo as a small picture that fills its box, for the
/// "Yours" tile while the look itself cannot be drawn. It shows [fallback]
/// until the picture is ready, and for good when there is none.
///
/// It reads the photo again when the store changes, and frees the picture
/// when it leaves the screen.
class OwnLookThumbnail extends StatefulWidget {
  const OwnLookThumbnail({
    required this.store,
    required this.height,
    required this.fallback,
    super.key,
  });

  final OwnLookStore store;

  /// How tall the box is, in points. The picture is decoded to that.
  final double height;
  final Widget fallback;

  @override
  State<OwnLookThumbnail> createState() => _OwnLookThumbnailState();
}

class _OwnLookThumbnailState extends State<OwnLookThumbnail> {
  ui.Image? _image;
  StreamSubscription<void>? _changes;
  int _load = 0;
  bool _hasRead = false;

  @override
  void initState() {
    super.initState();
    _changes = widget.store.changes.listen((_) => unawaited(_read()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasRead) unawaited(_read());
  }

  Future<void> _read() async {
    final load = ++_load;
    _hasRead = true;
    final height = (widget.height * MediaQuery.devicePixelRatioOf(context))
        .round();
    final image = await loadOwnLookThumbnail(widget.store, height: height);
    if (!mounted || load != _load) {
      image?.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = image);
    old?.dispose();
  }

  @override
  void dispose() {
    _load++;
    unawaited(_changes?.cancel());
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return widget.fallback;
    return RawImage(image: image, fit: BoxFit.cover);
  }
}
