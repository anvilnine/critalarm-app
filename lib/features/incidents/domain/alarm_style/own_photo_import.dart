import 'dart:math' as math;
import 'dart:ui' as ui;

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

  /// 25 million pixels, read from the file's header before anything
  /// decodes it. A file can be small on disk and huge in memory.
  ///
  /// The decoder may hold the whole picture at once before it scales it
  /// down (it does for PNG and HEIC), at four bytes a pixel, or eight for
  /// a wide-gamut picture on an iPhone: 100 MB, or 200 MB, for a moment.
  /// That is what a phone can spare with the rest of the app in memory.
  /// The number lets in a 24 megapixel photo, the largest a phone camera
  /// saves by default, and turns away the 48 and 50 megapixel modes.
  static const int maxSourcePixels = 25 * 1000 * 1000;

  /// The longest side of the working copy, in pixels: the one decode the
  /// import makes, which the crop step shows and the kept photo is cut
  /// from. At most 41 MB while the crop step is open, 31 MB for a photo
  /// in a camera's shape.
  static const int workingSide = 3200;

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
abstract interface class OwnPhotoPicker {
  /// The picked file, or null when the person backed out.
  Future<PickedOwnPhoto?> pickOne();

  /// Deletes the copy [pickOne] made in the app's cache. The platform
  /// copies every picked file there, and a person's photo must not sit in
  /// a cache once the import is over, kept or not.
  Future<void> discard(String path);
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

/// What the header of an image file says, with nothing decoded.
@immutable
class OwnPhotoHeader {
  const OwnPhotoHeader({
    required this.width,
    required this.height,
    required this.isAnimated,
  });

  final int width;
  final int height;

  /// More than one frame: an animated WebP, say. Not a photo.
  final bool isAnimated;
}

/// The picked photo, decoded once and held while the person frames it.
///
/// It is the only decode of the import. The crop step draws [image], and
/// the kept photo is cut from it, so nothing is decoded a second time.
/// Whoever opens one must [dispose] it.
class OwnPhotoWorkingCopy {
  OwnPhotoWorkingCopy(this.image);

  /// No longer than [OwnPhotoLimits.workingSide] on its long side, and
  /// the right way up.
  final ui.Image image;

  int get width => image.width;
  int get height => image.height;

  bool _isDisposed = false;

  /// Frees the picture. Safe to call more than once.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    image.dispose();
  }
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

/// A framed part of a photo, drawn at the size it would be kept at and
/// measured, with nothing written anywhere.
@immutable
class OwnPhotoPrepared {
  const OwnPhotoPrepared({required this.pixels, required this.measure});

  final OwnPhotoPixels pixels;

  /// Taken on [pixels], so it describes them and nothing else.
  final OwnPhotoMeasure measure;
}

/// Reads and redraws image files. The one thing in the import that
/// decodes anything.
abstract interface class OwnPhotoCodec {
  /// What the header of the image at [path] says, with nothing decoded.
  /// Null for a file that is not an image this phone can read.
  Future<OwnPhotoHeader?> describe(String path);

  /// The image at [path], decoded once, no longer than
  /// [OwnPhotoLimits.workingSide] on its long side. Null when it cannot
  /// be decoded, for any reason, running out of memory included, and for
  /// an animated image.
  Future<OwnPhotoWorkingCopy?> open(String path);

  /// The part [crop] of [from], drawn [width] by [height] with nothing
  /// see-through, as 8-bit sRGB. The pixels it answers with and the file
  /// it encodes are the same pixels, value for value. Null when it
  /// cannot be drawn.
  Future<OwnPhotoPixels?> render({
    required OwnPhotoWorkingCopy from,
    required OwnPhotoCrop crop,
    required int width,
    required int height,
  });
}

/// A picked file that passed the checks.
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

/// Brings a person's own photo in: checks the picked file, decodes it
/// once, then keeps the part they framed.
///
/// Nothing about the photo is logged or sent anywhere. The failure
/// messages are codes and never hold a file name or a path.
class ImportOwnPhotoUsecase {
  ImportOwnPhotoUsecase(
    this._codec,
    this._store, {
    required this._isLocked,
  });

  /// The file is not one of [OwnPhotoLimits.extensions], or it is an
  /// animated image.
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

  /// Checks a picked file: its type, its size on disk, then its size in
  /// pixels and whether it moves, from the header. Nothing is decoded
  /// here, so a huge picture is turned away before it can use memory.
  Future<AppResult<OwnPhotoSource>> check(PickedOwnPhoto file) async {
    if (!OwnPhotoLimits.isAccepted(file.name)) {
      return _fail(wrongTypeCode);
    }
    if (file.sizeBytes > OwnPhotoLimits.maxSourceBytes) {
      return _fail(tooLargeCode);
    }
    if (file.sizeBytes <= 0) return _fail(unreadableCode);
    OwnPhotoHeader? header;
    try {
      header = await _codec.describe(file.path);
    } on Object catch (_) {
      header = null;
    }
    if (header == null || header.width < 1 || header.height < 1) {
      return _fail(unreadableCode);
    }
    if (header.width * header.height > OwnPhotoLimits.maxSourcePixels) {
      return _fail(tooLargeCode);
    }
    // A moving picture is not a photo, and only its first frame would be
    // kept.
    if (header.isAnimated) return _fail(wrongTypeCode);
    return OwnPhotoSource(
      path: file.path,
      width: header.width,
      height: header.height,
    ).toSuccess();
  }

  /// [check], then the one decode of the import. The caller shows the
  /// working copy in the crop step, hands it to [save], and disposes it.
  /// Once this has answered, the picked file is not read again.
  Future<AppResult<OwnPhotoWorkingCopy>> open(PickedOwnPhoto file) async {
    final checked = await check(file);
    final source = checked.getOrNull();
    if (source == null) {
      return checked.exceptionOrNull()!.toFailure<OwnPhotoWorkingCopy>();
    }
    OwnPhotoWorkingCopy? copy;
    try {
      copy = await _codec.open(source.path);
    } on Object catch (_) {
      copy = null;
    }
    if (copy == null) return _fail(unreadableCode);
    if (copy.width < 1 ||
        copy.height < 1 ||
        // A decoder that ignored the size it was asked for.
        copy.width * copy.height > OwnPhotoLimits.maxSourcePixels) {
      copy.dispose();
      return _fail(unreadableCode);
    }
    return copy.toSuccess();
  }

  /// Keeps the part [crop] of [photo] as the one photo: scaled down to
  /// the screen ([screenWidth] by [screenHeight] pixels) or smaller,
  /// measured, and written to the app's storage.
  ///
  /// The photo saved before stays the photo until this one is written.
  Future<AppResult<OwnPhotoRecord>> save({
    required OwnPhotoWorkingCopy photo,
    required OwnPhotoCrop crop,
    required double screenWidth,
    required double screenHeight,
  }) async {
    if (await _lockedNow()) return _fail(lockedCode);
    final prepared = await prepare(
      photo: photo,
      crop: crop,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    final kept = prepared.getOrNull();
    if (kept == null) {
      return prepared.exceptionOrNull()!.toFailure<OwnPhotoRecord>();
    }
    return _write(
      kept.pixels.encoded,
      width: kept.pixels.width,
      height: kept.pixels.height,
      measure: kept.measure,
    );
  }

  /// The part [crop] of [photo], scaled and measured exactly as [save]
  /// would keep it, and written nowhere. The caller holds the answer in
  /// memory, to show it, and keeps it later with [keep] or lets it go.
  ///
  /// It never reads the plan and never touches the store, so a person who
  /// cannot keep a photo can still see it.
  Future<AppResult<OwnPhotoPrepared>> prepare({
    required OwnPhotoWorkingCopy photo,
    required OwnPhotoCrop crop,
    required double screenWidth,
    required double screenHeight,
  }) async {
    if (!crop.isSane || screenWidth < 1 || screenHeight < 1) {
      return _fail(unreadableCode);
    }
    final kept = OwnPhotoLimits.keptSize(
      cropWidth: crop.width * photo.width,
      cropHeight: crop.height * photo.height,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    OwnPhotoPixels? pixels;
    try {
      pixels = await _codec.render(
        from: photo,
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
    return OwnPhotoPrepared(
      pixels: pixels,
      measure: measureOwnPhoto(pixels.rgba, pixels.width, pixels.height),
    ).toSuccess();
  }

  /// Writes a photo that [prepare] made, or that was held in memory since,
  /// as the one photo. [encoded] is an image file of [width] by [height]
  /// pixels and [measure] was taken on those pixels.
  ///
  /// Turns the photo away while alarm looks are locked, as [save] does.
  Future<AppResult<OwnPhotoRecord>> keep(
    Uint8List encoded, {
    required int width,
    required int height,
    required OwnPhotoMeasure measure,
  }) async {
    if (await _lockedNow()) return _fail(lockedCode);
    if (encoded.isEmpty || width < 1 || height < 1) {
      return _fail(unreadableCode);
    }
    return _write(encoded, width: width, height: height, measure: measure);
  }

  Future<bool> _lockedNow() async {
    try {
      return await _isLocked();
    } on Object catch (_) {
      // Nobody knows, so nothing is turned away.
      return false;
    }
  }

  Future<AppResult<OwnPhotoRecord>> _write(
    Uint8List encoded, {
    required int width,
    required int height,
    required OwnPhotoMeasure measure,
  }) async {
    try {
      await _store.savePhoto(
        encoded,
        width: width,
        height: height,
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
