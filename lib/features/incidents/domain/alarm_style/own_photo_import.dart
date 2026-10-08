import 'dart:math' as math;

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:flutter/foundation.dart';

/// The caps on a person's own photo. Pure, so each is tested with no
/// picker and no device.
abstract final class OwnPhotoLimits {
  /// 25 MB, checked on the picked file before anything opens it.
  static const int maxSourceBytes = 25 * 1024 * 1024;

  /// 50 million pixels, read from the file's header before anything
  /// decodes it. A file can be small on disk and huge in memory.
  static const int maxSourcePixels = 50 * 1000 * 1000;

  /// The most pixels the import ever decodes at once: 16 million, about
  /// 64 MB while it works. A larger picture is decoded smaller.
  static const int maxDecodedPixels = 16 * 1000 * 1000;

  /// The longest side of the photo that is kept, in pixels. With the
  /// screen's own size this caps what the alarm screen holds in memory at
  /// about 5 MB.
  static const int maxSide = 1600;

  /// The file types the picker offers and the import accepts.
  static const Set<String> extensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  /// The extension of [name], lower case, or null when it has none.
  static String? extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  static bool isAccepted(String name) => extensions.contains(extensionOf(name));

  /// The size the cropped part is kept at, for a part [cropWidth] by
  /// [cropHeight] pixels of the picked file on a screen [screenWidth] by
  /// [screenHeight] pixels: never larger than the part itself, the screen
  /// or [maxSide].
  static ({int width, int height}) keptSize({
    required double cropWidth,
    required double cropHeight,
    required double screenWidth,
    required double screenHeight,
  }) {
    final scale = [
      1.0,
      screenWidth / cropWidth,
      screenHeight / cropHeight,
      maxSide / math.max(cropWidth, cropHeight),
    ].reduce(math.min);
    return (
      width: math.max(1, (cropWidth * scale).round()),
      height: math.max(1, (cropHeight * scale).round()),
    );
  }
}

/// A file the person picked, before anything has been checked.
@immutable
class PickedOwnPhoto {
  const PickedOwnPhoto({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}

/// Opens the system's file picker for one image.
// One method on purpose: it is the port a test replaces.
// ignore: one_member_abstracts
abstract interface class OwnPhotoPicker {
  /// The picked file, or null when the person backed out.
  Future<PickedOwnPhoto?> pickOne();
}

/// The part of a picture to keep, as fractions of its width and height,
/// each 0 to 1.
@immutable
class OwnPhotoCrop {
  const OwnPhotoCrop({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// The whole picture.
  static const OwnPhotoCrop whole = OwnPhotoCrop(
    left: 0,
    top: 0,
    right: 1,
    bottom: 1,
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  bool get isSane =>
      left >= 0 &&
      top >= 0 &&
      right <= 1 &&
      bottom <= 1 &&
      width > 0 &&
      height > 0;
}

/// A part of a picture, decoded: its pixels, and the same picture encoded
/// for the file.
@immutable
class OwnPhotoPixels {
  const OwnPhotoPixels({
    required this.width,
    required this.height,
    required this.rgba,
    required this.encoded,
  });

  final int width;
  final int height;

  /// Four bytes a pixel, with nothing see-through.
  final Uint8List rgba;

  /// The picture as an image file.
  final Uint8List encoded;
}

/// Reads and redraws image files. The one thing in the import that
/// decodes anything.
abstract interface class OwnPhotoCodec {
  /// The size of the image at [path] in pixels, read from its header with
  /// nothing decoded. Null for a file that is not an image this phone can
  /// read.
  Future<({int width, int height})?> sizeOf(String path);

  /// The part [crop] of the image at [path], drawn [width] by [height]
  /// with nothing see-through. Null when it cannot be decoded, for any
  /// reason, running out of memory included.
  Future<OwnPhotoPixels?> render({
    required String path,
    required OwnPhotoCrop crop,
    required int width,
    required int height,
  });
}

/// A picked file that passed the checks, ready for the crop step.
@immutable
class OwnPhotoSource {
  const OwnPhotoSource({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

/// Brings a person's own photo in: checks the picked file, then keeps the
/// part they framed.
///
/// Nothing about the photo is logged or sent anywhere. The failure
/// messages are codes and never hold a file name or a path.
class ImportOwnPhotoUsecase {
  ImportOwnPhotoUsecase(
    this._codec,
    this._store, {
    required this._isLocked,
  });

  /// The file is not one of [OwnPhotoLimits.extensions].
  static const wrongTypeCode = 'ownPhotoWrongType';

  /// The file is over [OwnPhotoLimits.maxSourceBytes], or the picture
  /// over [OwnPhotoLimits.maxSourcePixels].
  static const tooLargeCode = 'ownPhotoTooLarge';

  /// The file is not a picture this phone can decode.
  static const unreadableCode = 'ownPhotoUnreadable';

  /// The photo could not be written.
  static const saveFailedCode = 'ownPhotoSaveFailed';

  /// Alarm looks are locked. The caller opens the paywall for it.
  static const lockedCode = 'alarmLooksLocked';

  final OwnPhotoCodec _codec;
  final OwnLookStore _store;

  /// Whether alarm looks are locked for certain. False while a purchase
  /// is being confirmed and while the plan could not be read.
  final Future<bool> Function() _isLocked;

  /// Checks a picked file before the crop step opens: its type, its size
  /// on disk, then its size in pixels from the header. Nothing is decoded
  /// here, so a huge picture is turned away before it can use memory.
  Future<AppResult<OwnPhotoSource>> check(PickedOwnPhoto file) async {
    if (!OwnPhotoLimits.isAccepted(file.name)) {
      return _fail(wrongTypeCode);
    }
    if (file.sizeBytes > OwnPhotoLimits.maxSourceBytes) {
      return _fail(tooLargeCode);
    }
    if (file.sizeBytes <= 0) return _fail(unreadableCode);
    ({int width, int height})? size;
    try {
      size = await _codec.sizeOf(file.path);
    } on Object catch (_) {
      size = null;
    }
    if (size == null || size.width < 1 || size.height < 1) {
      return _fail(unreadableCode);
    }
    if (size.width * size.height > OwnPhotoLimits.maxSourcePixels) {
      return _fail(tooLargeCode);
    }
    return OwnPhotoSource(
      path: file.path,
      width: size.width,
      height: size.height,
    ).toSuccess();
  }

  /// Keeps the part [crop] of [source] as the one photo: scaled down to
  /// the screen ([screenWidth] by [screenHeight] pixels) or smaller,
  /// measured, and written to the app's storage.
  ///
  /// The photo saved before stays the photo until this one is written.
  Future<AppResult<OwnPhotoRecord>> save({
    required OwnPhotoSource source,
    required OwnPhotoCrop crop,
    required double screenWidth,
    required double screenHeight,
  }) async {
    var locked = false;
    try {
      locked = await _isLocked();
    } on Object catch (_) {
      // Nobody knows, so nothing is turned away.
    }
    if (locked) return _fail(lockedCode);
    if (!crop.isSane || screenWidth < 1 || screenHeight < 1) {
      return _fail(unreadableCode);
    }
    final kept = OwnPhotoLimits.keptSize(
      cropWidth: crop.width * source.width,
      cropHeight: crop.height * source.height,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    OwnPhotoPixels? pixels;
    try {
      pixels = await _codec.render(
        path: source.path,
        crop: crop,
        width: kept.width,
        height: kept.height,
      );
    } on Object catch (_) {
      pixels = null;
    }
    if (pixels == null ||
        pixels.width < 1 ||
        pixels.height < 1 ||
        pixels.rgba.length != pixels.width * pixels.height * 4 ||
        pixels.encoded.isEmpty) {
      return _fail(unreadableCode);
    }
    // Measured on the pixels that are kept, so the numbers beside the
    // file are the numbers of the file.
    final measure = measureOwnPhoto(pixels.rgba, pixels.width, pixels.height);
    try {
      await _store.savePhoto(
        pixels.encoded,
        width: pixels.width,
        height: pixels.height,
        measure: measure,
      );
    } on Object catch (_) {
      return _fail(saveFailedCode);
    }
    final record = _store.photo;
    if (record == null) return _fail(saveFailedCode);
    return record.toSuccess();
  }

  static AppResult<T> _fail<T extends Object>(String code) =>
      UnexpectedFailure(message: code).toFailure<T>();
}
