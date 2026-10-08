import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';

/// [OwnPhotoCodec] on the engine's own image decoder. No package and no
/// native code: what Flutter can decode on this phone is what is
/// accepted.
class UiOwnPhotoCodec implements OwnPhotoCodec {
  const UiOwnPhotoCodec();

  @override
  Future<({int width, int height})?> sizeOf(String path) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      final file = File(path);
      // The usecase checked the picker's number. This is the file's own.
      if (await file.length() > OwnPhotoLimits.maxSourceBytes) return null;
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      // Reads the header. Nothing is decoded until a codec is asked for.
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (width: descriptor.width, height: descriptor.height);
    } on Object catch (_) {
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  Future<OwnPhotoPixels?> render({
    required String path,
    required OwnPhotoCrop crop,
    required int width,
    required int height,
  }) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    ui.Picture? picture;
    ui.Image? kept;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // Decoded no larger than the kept part needs, and never over the
      // cap: a picture cropped hard is decoded smaller and scaled up.
      final sourcePixels = descriptor.width * descriptor.height;
      final scale = [
        1.0,
        width / (crop.width * descriptor.width),
        height / (crop.height * descriptor.height),
      ].reduce(math.max);
      final capped = math.min(
        math.min(1, scale),
        math.sqrt(OwnPhotoLimits.maxDecodedPixels / sourcePixels),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * capped).floor()),
      );
      decoded = (await codec.getNextFrame()).image;
      // The frame's own size, which is the picture the right way up.
      final source = ui.Rect.fromLTRB(
        crop.left * decoded.width,
        crop.top * decoded.height,
        crop.right * decoded.width,
        crop.bottom * decoded.height,
      );
      final target = ui.Rect.fromLTWH(
        0,
        0,
        width.toDouble(),
        height.toDouble(),
      );
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder, target)
        // Black under it, so a see-through picture is kept solid.
        ..drawRect(target, ui.Paint()..color = const ui.Color(0xFF000000))
        ..drawImageRect(
          decoded,
          source,
          target,
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
      picture = recorder.endRecording();
      kept = await picture.toImage(width, height);
      final rgba = await kept.toByteData();
      final encoded = await kept.toByteData(format: ui.ImageByteFormat.png);
      if (rgba == null || encoded == null) return null;
      return OwnPhotoPixels(
        width: width,
        height: height,
        // Drawn on black, so every pixel is already solid.
        rgba: rgba.buffer.asUint8List(),
        encoded: encoded.buffer.asUint8List(),
      );
    } on Object catch (_) {
      return null;
    } finally {
      kept?.dispose();
      picture?.dispose();
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
