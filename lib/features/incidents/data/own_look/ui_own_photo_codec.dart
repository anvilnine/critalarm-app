import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';

/// [OwnPhotoCodec] on the engine's own image decoder. No package and no
/// native code: what Flutter can decode on this phone is what is
/// accepted.
///
/// It decodes a picked file exactly once ([open]). The decoder is asked
/// for the working size, which a JPEG is decoded at directly. For other
/// formats the engine may decode the whole picture first and scale it
/// after, which is why the cap on pixels is checked from the header
/// before this is ever called.
class UiOwnPhotoCodec implements OwnPhotoCodec {
  const UiOwnPhotoCodec();

  @override
  Future<OwnPhotoHeader?> describe(String path) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      final file = File(path);
      // The usecase checked the picker's number. This is the file's own.
      if (await file.length() > OwnPhotoLimits.maxSourceBytes) return null;
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      // Reads the header. Nothing is decoded until a frame is asked for,
      // and none is here: the codec is made for its frame count alone, at
      // one pixel wide so it could hold nothing if it did.
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec(targetWidth: 1);
      return OwnPhotoHeader(
        width: descriptor.width,
        height: descriptor.height,
        isAnimated: codec.frameCount > 1,
      );
    } on Object catch (_) {
      return null;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  Future<OwnPhotoWorkingCopy?> open(String path) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      if (width < 1 || height < 1) return null;
      if (width * height > OwnPhotoLimits.maxSourcePixels) return null;
      // Never larger than the file, and never over the working size. One
      // side is named and the other follows, so the shape is kept.
      final scale = math.min(
        1,
        OwnPhotoLimits.workingSide / math.max(width, height),
      );
      codec = width >= height
          ? await descriptor.instantiateCodec(
              targetWidth: math.max(1, (width * scale).floor()),
            )
          : await descriptor.instantiateCodec(
              targetHeight: math.max(1, (height * scale).floor()),
            );
      if (codec.frameCount > 1) return null;
      final decoded = (await codec.getNextFrame()).image;
      // A photo turned by its camera can come back with its sides
      // swapped, and then the side that was named is the short one.
      final longest = math.max(decoded.width, decoded.height);
      if (longest <= OwnPhotoLimits.workingSide) {
        return OwnPhotoWorkingCopy(decoded);
      }
      try {
        final fit = OwnPhotoLimits.workingSide / longest;
        return OwnPhotoWorkingCopy(
          await _draw(
            decoded,
            ui.Rect.fromLTWH(
              0,
              0,
              decoded.width.toDouble(),
              decoded.height.toDouble(),
            ),
            math.max(1, (decoded.width * fit).floor()),
            math.max(1, (decoded.height * fit).floor()),
          ),
        );
      } finally {
        decoded.dispose();
      }
    } on Object catch (_) {
      return null;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// The part [source] of [image], drawn [width] by [height] on black.
  Future<ui.Image> _draw(
    ui.Image image,
    ui.Rect source,
    int width,
    int height,
  ) async {
    final target = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder, target)
      // Black under it, so a see-through picture is kept solid.
      ..drawRect(target, ui.Paint()..color = const ui.Color(0xFF000000))
      ..drawImageRect(
        image,
        source,
        target,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  @override
  Future<OwnPhotoPixels?> render({
    required OwnPhotoWorkingCopy from,
    required OwnPhotoCrop crop,
    required int width,
    required int height,
  }) async {
    ui.Image? drawn;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? kept;
    try {
      drawn = await _draw(
        from.image,
        ui.Rect.fromLTRB(
          crop.left * from.width,
          crop.top * from.height,
          crop.right * from.width,
          crop.bottom * from.height,
        ),
        width,
        height,
      );
      // Read back as 8-bit sRGB, whatever the picture was drawn in: on a
      // wide-gamut phone it can be 16 bits a value. These bytes are what
      // is measured.
      final data = await drawn.toByteData();
      if (data == null) return null;
      final rgba = Uint8List.fromList(data.buffer.asUint8List());
      if (rgba.length != width * height * 4) return null;
      // Drawn on black, so every pixel is solid. Said outright, so the
      // file can hold nothing see-through either.
      for (var at = 3; at < rgba.length; at += 4) {
        rgba[at] = 255;
      }
      // The file is encoded from those same bytes, never from the
      // drawing: what is measured is what is kept, value for value.
      buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      kept = (await codec.getNextFrame()).image;
      final encoded = await kept.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) return null;
      return OwnPhotoPixels(
        width: width,
        height: height,
        rgba: rgba,
        encoded: encoded.buffer.asUint8List(),
      );
    } on Object catch (_) {
      return null;
    } finally {
      kept?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      drawn?.dispose();
    }
  }
}
