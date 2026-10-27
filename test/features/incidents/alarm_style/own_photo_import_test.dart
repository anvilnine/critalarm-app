import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/data/own_look/file_own_look_store.dart';
import 'package:critalarm/features/incidents/data/own_look/ui_own_photo_codec.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A picture of one flat colour, made with no file.
Future<ui.Image> _flat(int width, int height, {int grey = 90}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = ui.Color.fromARGB(255, grey, grey, grey),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

/// A codec that reads no file: it answers what the test tells it to and
/// counts what it was asked.
class _FakeCodec implements OwnPhotoCodec {
  OwnPhotoHeader? header = const OwnPhotoHeader(
    width: 3000,
    height: 4000,
    isAnimated: false,
  );
  bool describeThrows = false;
  bool openFails = false;
  bool openThrows = false;
  bool renderFails = false;
  bool renderThrows = false;
  int describeCalls = 0;
  int openCalls = 0;
  int renderCalls = 0;
  ({OwnPhotoCrop crop, int width, int height})? rendered;
  final opened = <OwnPhotoWorkingCopy>[];

  @override
  Future<OwnPhotoHeader?> describe(String path) async {
    describeCalls++;
    if (describeThrows) throw const FileSystemException('gone');
    return header;
  }

  @override
  Future<OwnPhotoWorkingCopy?> open(String path) async {
    openCalls++;
    if (openThrows) throw StateError('out of memory');
    if (openFails) return null;
    // The working copy of a 3000 by 4000 photo, a tenth of the size.
    final copy = OwnPhotoWorkingCopy(await _flat(300, 400));
    opened.add(copy);
    return copy;
  }

  @override
  Future<OwnPhotoPixels?> render({
    required OwnPhotoWorkingCopy from,
    required OwnPhotoCrop crop,
    required int width,
    required int height,
  }) async {
    renderCalls++;
    rendered = (crop: crop, width: width, height: height);
    if (renderThrows) throw StateError('out of memory');
    if (renderFails) return null;
    return OwnPhotoPixels(
      width: width,
      height: height,
      rgba: Uint8List(width * height * 4)..fillRange(0, width * height * 4, 90),
      encoded: Uint8List.fromList([1, 2, 3, 4]),
    );
  }
}

String? _code<T extends Object>(AppResult<T> result) =>
    result.exceptionOrNull()?.message;

/// A real PNG, [width] by [height], drawn by [paint].
Future<Uint8List> _png(
  int width,
  int height,
  void Function(ui.Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// A GIF of one pixel that moves: two frames, black then white.
const List<int> _movingGif = [
  0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // GIF89a
  0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00, // 1 by 1, two colours
  0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, // black, white
  0x21, 0xFF, 0x0B, 0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, //
  0x32, 0x2E, 0x30, 0x03, 0x01, 0x00, 0x00, 0x00, // loops for ever
  0x21, 0xF9, 0x04, 0x00, 0x0A, 0x00, 0x00, 0x00, // frame 1
  0x2C, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, //
  0x02, 0x02, 0x44, 0x01, 0x00, //
  0x21, 0xF9, 0x04, 0x00, 0x0A, 0x00, 0x00, 0x00, // frame 2
  0x2C, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, //
  0x02, 0x02, 0x4C, 0x01, 0x00, //
  0x3B,
];

void main() {
  late Directory root;
  late SharedPreferences prefs;
  late FileOwnLookStore store;
  late _FakeCodec codec;
  var isLocked = false;

  ImportOwnPhotoUsecase usecase([OwnPhotoCodec? real]) => ImportOwnPhotoUsecase(
    real ?? codec,
    store,
    isLocked: () async => isLocked,
  );

  const picked = PickedOwnPhoto(
    path: '/picked/IMG_0001.JPG',
    name: 'IMG_0001.JPG',
    sizeBytes: 3 * 1024 * 1024,
  );

  /// The working copy of [picked], freed when the test ends.
  Future<OwnPhotoWorkingCopy> working() async {
    final copy = (await usecase().open(picked)).getOrThrow();
    addTearDown(copy.dispose);
    return copy;
  }

  setUp(() async {
    isLocked = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    root = await Directory.systemTemp.createTemp('own_photo_import_');
    store = FileOwnLookStore(prefs, () async => root);
    codec = _FakeCodec();
  });

  tearDown(() async {
    for (final copy in codec.opened) {
      copy.dispose();
    }
    await store.dispose();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  List<File> files() => [
    if (root.existsSync())
      for (final entry in root.listSync(recursive: true))
        if (entry is File) entry,
  ];

  group('the limits:', () {
    test('the caps are what the report says', () {
      expect(OwnPhotoLimits.maxSourceBytes, 25 * 1024 * 1024);
      expect(OwnPhotoLimits.maxSourcePixels, 25000000);
      expect(OwnPhotoLimits.workingSide, 3200);
      expect(OwnPhotoLimits.maxSide, 1600);
      expect(OwnLookStore.maxStoredBytes, 24 * 1024 * 1024);
    });

    test('a 24 megapixel phone photo is under the cap, and the 48 and 50 '
        'megapixel modes are over it', () {
      expect(5712 * 4284, lessThanOrEqualTo(OwnPhotoLimits.maxSourcePixels));
      expect(4032 * 3024, lessThanOrEqualTo(OwnPhotoLimits.maxSourcePixels));
      expect(8064 * 6048, greaterThan(OwnPhotoLimits.maxSourcePixels));
      expect(8160 * 6120, greaterThan(OwnPhotoLimits.maxSourcePixels));
      // The whole picture at once, at four bytes a pixel: 100 MB.
      expect(OwnPhotoLimits.maxSourcePixels * 4, 100 * 1000 * 1000);
      // The working copy the crop step holds: 41 MB at the very most.
      expect(
        OwnPhotoLimits.workingSide * OwnPhotoLimits.workingSide * 4,
        lessThan(41 * 1000 * 1000),
      );
    });

    test('only image types are accepted, whatever the case', () {
      for (final name in ['a.jpg', 'A.JPEG', 'b.png', 'c.WebP', 'd.heic']) {
        expect(OwnPhotoLimits.isAccepted(name), isTrue, reason: name);
      }
      for (final name in [
        'song.mp3',
        'clip.mov',
        'notes.pdf',
        'photo',
        'photo.',
        '.jpg.exe',
        'a.gif',
        'a.svg',
      ]) {
        expect(OwnPhotoLimits.isAccepted(name), isFalse, reason: name);
      }
    });

    test('the kept photo is never larger than the part, the screen or the '
        'cap', () {
      // A phone at 3x: 1170 by 2532. A large picture comes down to it,
      // then to the cap on the long side.
      final big = OwnPhotoLimits.keptSize(
        cropWidth: 2772,
        cropHeight: 6000,
        screenWidth: 1170,
        screenHeight: 2532,
      );
      expect(big.height, OwnPhotoLimits.maxSide);
      expect(big.width, 739);
      // A small picture is kept as it is, never blown up.
      final small = OwnPhotoLimits.keptSize(
        cropWidth: 300,
        cropHeight: 650,
        screenWidth: 1170,
        screenHeight: 2532,
      );
      expect(small, (width: 300, height: 650));
      // A small screen caps it.
      final se = OwnPhotoLimits.keptSize(
        cropWidth: 3000,
        cropHeight: 5336,
        screenWidth: 750,
        screenHeight: 1334,
      );
      expect(se, (width: 750, height: 1334));
      // Never nothing.
      final sliver = OwnPhotoLimits.keptSize(
        cropWidth: 0.2,
        cropHeight: 4000,
        screenWidth: 1170,
        screenHeight: 2532,
      );
      expect(sliver.width, 1);
    });
  });

  group('checking the picked file:', () {
    test('a wrong type is turned away before anything opens it', () async {
      final result = await usecase().open(
        const PickedOwnPhoto(
          path: '/picked/song.mp3',
          name: 'song.mp3',
          sizeBytes: 1000,
        ),
      );
      expect(_code(result), ImportOwnPhotoUsecase.wrongTypeCode);
      expect(codec.describeCalls, 0);
      expect(codec.openCalls, 0);
    });

    test('a file over the size cap is turned away before anything opens '
        'it', () async {
      final result = await usecase().open(
        const PickedOwnPhoto(
          path: '/picked/huge.png',
          name: 'huge.png',
          sizeBytes: OwnPhotoLimits.maxSourceBytes + 1,
        ),
      );
      expect(_code(result), ImportOwnPhotoUsecase.tooLargeCode);
      expect(codec.describeCalls, 0);
      expect(codec.openCalls, 0);
    });

    test('a file at the size cap is let through', () async {
      final result = await usecase().check(
        const PickedOwnPhoto(
          path: '/picked/big.png',
          name: 'big.png',
          sizeBytes: OwnPhotoLimits.maxSourceBytes,
        ),
      );
      expect(result.isSuccess(), isTrue);
    });

    test('a small file that would be huge in memory is turned away from '
        'its header, with nothing decoded', () async {
      // A 48 megapixel photo.
      codec.header = const OwnPhotoHeader(
        width: 8064,
        height: 6048,
        isAnimated: false,
      );
      final result = await usecase().open(picked);
      expect(_code(result), ImportOwnPhotoUsecase.tooLargeCode);
      expect(codec.describeCalls, 1);
      expect(codec.openCalls, 0);
      expect(codec.renderCalls, 0);
    });

    test('a picture at the cap is decoded, one pixel over is not', () async {
      codec.header = const OwnPhotoHeader(
        width: 5000,
        height: 5000,
        isAnimated: false,
      );
      expect((await usecase().check(picked)).isSuccess(), isTrue);
      codec.header = const OwnPhotoHeader(
        width: 5000,
        height: 5001,
        isAnimated: false,
      );
      expect(
        _code(await usecase().check(picked)),
        ImportOwnPhotoUsecase.tooLargeCode,
      );
    });

    test('a moving picture is the wrong type, with nothing decoded', () async {
      codec.header = const OwnPhotoHeader(
        width: 600,
        height: 800,
        isAnimated: true,
      );
      final result = await usecase().open(picked);
      expect(_code(result), ImportOwnPhotoUsecase.wrongTypeCode);
      expect(codec.openCalls, 0);
    });

    test('a file that is not an image, an empty one and one that cannot '
        'be opened are unreadable', () async {
      codec.header = null;
      expect(
        _code(await usecase().check(picked)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      codec.header = const OwnPhotoHeader(
        width: 0,
        height: 10,
        isAnimated: false,
      );
      expect(
        _code(await usecase().check(picked)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      codec.describeThrows = true;
      expect(
        _code(await usecase().check(picked)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      expect(
        _code(
          await usecase().check(
            const PickedOwnPhoto(path: '/p/a.png', name: 'a.png', sizeBytes: 0),
          ),
        ),
        ImportOwnPhotoUsecase.unreadableCode,
      );
    });

    test('a good file comes back with its size in pixels', () async {
      final result = await usecase().check(picked);
      final checked = result.getOrThrow();
      expect(checked.path, picked.path);
      expect((checked.width, checked.height), (3000, 4000));
      expect(codec.openCalls, 0);
      expect(codec.renderCalls, 0);
    });

    test('no failure names the file', () async {
      for (final code in [
        ImportOwnPhotoUsecase.wrongTypeCode,
        ImportOwnPhotoUsecase.tooLargeCode,
        ImportOwnPhotoUsecase.unreadableCode,
        ImportOwnPhotoUsecase.saveFailedCode,
        ImportOwnPhotoUsecase.lockedCode,
      ]) {
        expect(code, isNot(contains('/')));
        expect(code, isNot(contains('IMG')));
      }
      codec.header = null;
      final failure = (await usecase().check(picked)).exceptionOrNull()!;
      expect('$failure', isNot(contains('IMG_0001')));
      expect('$failure', isNot(contains('/picked')));
    });
  });

  group('the one decode:', () {
    test('a good file is decoded once, and keeping a part of it decodes '
        'nothing more', () async {
      final photo = await working();
      expect(codec.openCalls, 1);
      await usecase().save(
        photo: photo,
        crop: OwnPhotoCrop.whole,
        screenWidth: 750,
        screenHeight: 1334,
      );
      await usecase().save(
        photo: photo,
        crop: OwnPhotoCrop.whole,
        screenWidth: 750,
        screenHeight: 1334,
      );
      expect(codec.openCalls, 1);
      expect(codec.describeCalls, 1);
      expect(codec.renderCalls, 2);
    });

    test('a decode that fails, or runs out of memory, is unreadable', () async {
      codec.openFails = true;
      expect(
        _code(await usecase().open(picked)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      codec
        ..openFails = false
        ..openThrows = true;
      expect(
        _code(await usecase().open(picked)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      expect(store.photo, isNull);
    });

    test('a working copy can be freed more than once', () async {
      final photo = (await usecase().open(picked)).getOrThrow()
        ..dispose()
        ..dispose();
      expect(photo.width, 300);
    });
  });

  group('keeping the framed part:', () {
    // The middle of the picture, in the shape of a phone.
    const crop = OwnPhotoCrop(left: 0.25, top: 0.1, right: 0.75, bottom: 0.9);

    test('it is scaled to the screen, measured, written to one file and '
        'recorded', () async {
      final result = await usecase().save(
        photo: await working(),
        crop: crop,
        screenWidth: 100,
        screenHeight: 200,
      );
      final record = result.getOrThrow();
      // 150 by 320 pixels of the working copy, on a 100 by 200 screen.
      expect(codec.rendered!.width, 94);
      expect(codec.rendered!.height, 200);
      expect(codec.rendered!.crop, crop);
      expect((record.width, record.height), (94, 200));
      // Measured on the pixels that were kept.
      expect(record.measure.brightest, 90);
      expect(record.measure.darkest, 90);
      expect(record.measure.peaks, hasLength(128));
      expect(files(), hasLength(1));
      expect(files().single.readAsBytesSync(), [1, 2, 3, 4]);
      expect(await store.readPhoto(record.stamp), [1, 2, 3, 4]);
      expect(store.photo!.stamp, record.stamp);
    });

    test('it is never larger than the part of the working copy it is cut '
        'from', () async {
      final record = (await usecase().save(
        photo: await working(),
        crop: crop,
        screenWidth: 1170,
        screenHeight: 2532,
      )).getOrThrow();
      expect((record.width, record.height), (150, 320));
    });

    test('a part that cannot be drawn, or a draw that runs out of memory, '
        'saves nothing and keeps the photo that was there', () async {
      final photo = await working();
      await usecase().save(
        photo: photo,
        crop: crop,
        screenWidth: 750,
        screenHeight: 1334,
      );
      final before = store.photo!.stamp;

      codec.renderFails = true;
      expect(
        _code(
          await usecase().save(
            photo: photo,
            crop: crop,
            screenWidth: 750,
            screenHeight: 1334,
          ),
        ),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      codec
        ..renderFails = false
        ..renderThrows = true;
      expect(
        _code(
          await usecase().save(
            photo: photo,
            crop: crop,
            screenWidth: 750,
            screenHeight: 1334,
          ),
        ),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      expect(store.photo!.stamp, before);
      expect(files(), hasLength(1));
    });

    test('a crop that is not inside the picture is refused', () async {
      final photo = await working();
      for (final bad in const [
        OwnPhotoCrop(left: 0.5, top: 0, right: 0.5, bottom: 1),
        OwnPhotoCrop(left: -0.1, top: 0, right: 1, bottom: 1),
        OwnPhotoCrop(left: 0, top: 0, right: 1.2, bottom: 1),
        OwnPhotoCrop(left: 0.8, top: 0, right: 0.2, bottom: 1),
      ]) {
        expect(
          _code(
            await usecase().save(
              photo: photo,
              crop: bad,
              screenWidth: 750,
              screenHeight: 1334,
            ),
          ),
          ImportOwnPhotoUsecase.unreadableCode,
        );
      }
      expect(codec.renderCalls, 0);
      expect(files(), isEmpty);
    });

    test('with looks locked for certain, nothing is drawn or saved', () async {
      final photo = await working();
      isLocked = true;
      final result = await usecase().save(
        photo: photo,
        crop: crop,
        screenWidth: 750,
        screenHeight: 1334,
      );
      expect(_code(result), ImportOwnPhotoUsecase.lockedCode);
      expect(codec.renderCalls, 0);
      expect(files(), isEmpty);
    });

    test('a plan nobody can read turns nothing away', () async {
      final unsure = ImportOwnPhotoUsecase(
        codec,
        store,
        isLocked: () async => throw StateError('unread'),
      );
      final result = await unsure.save(
        photo: await working(),
        crop: crop,
        screenWidth: 750,
        screenHeight: 1334,
      );
      expect(result.isSuccess(), isTrue);
    });

    test('a folder that cannot be written is a failed save, and no record '
        'is left', () async {
      // A file where the photo's folder should be.
      File('${root.path}/alarm_look').writeAsStringSync('in the way');
      final result = await usecase().save(
        photo: await working(),
        crop: crop,
        screenWidth: 750,
        screenHeight: 1334,
      );
      expect(_code(result), ImportOwnPhotoUsecase.saveFailedCode);
      expect(store.photo, isNull);
      expect(prefs.getString(OwnLookStore.photoKey), isNull);
    });
  });

  group('with the real decoder:', () {
    const real = UiOwnPhotoCodec();

    Future<PickedOwnPhoto> pickedFile(String name, List<int> bytes) async {
      final file = File('${root.path}/$name');
      await file.writeAsBytes(bytes);
      return PickedOwnPhoto(
        path: file.path,
        name: name,
        sizeBytes: bytes.length,
      );
    }

    Future<OwnPhotoWorkingCopy> openReal(PickedOwnPhoto file) async {
      final copy = (await usecase(real).open(file)).getOrThrow();
      addTearDown(copy.dispose);
      return copy;
    }

    /// The saved file, decoded, as four bytes a pixel.
    Future<(int, int, Uint8List)> savedPixels(String stamp) async {
      final saved = (await store.readPhoto(stamp))!;
      final codec = await ui.instantiateImageCodec(saved);
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData())!.buffer.asUint8List();
      final answer = (image.width, image.height, Uint8List.fromList(pixels));
      image.dispose();
      codec.dispose();
      return answer;
    }

    test('a real picture is cropped, scaled, measured and read back as the '
        'same pixels', () async {
      // White on the left half, black on the right.
      final png = await _png(200, 400, (canvas) {
        canvas
          ..drawRect(
            const ui.Rect.fromLTWH(0, 0, 100, 400),
            ui.Paint()..color = const ui.Color(0xFFFFFFFF),
          )
          ..drawRect(
            const ui.Rect.fromLTWH(100, 0, 100, 400),
            ui.Paint()..color = const ui.Color(0xFF000000),
          );
      });
      final photo = await openReal(await pickedFile('split.png', png));
      expect((photo.width, photo.height), (200, 400));

      // The left half only: all white.
      final record = (await usecase(real).save(
        photo: photo,
        crop: const OwnPhotoCrop(left: 0, top: 0, right: 0.5, bottom: 1),
        screenWidth: 50,
        screenHeight: 200,
      )).getOrThrow();
      expect((record.width, record.height), (50, 200));
      expect(record.measure.darkest, 255);
      expect(record.measure.brightest, 255);

      // What is on disk is that picture.
      final (width, height, pixels) = await savedPixels(record.stamp);
      expect((width, height), (50, 200));
      expect(measureOwnPhoto(pixels, width, height), record.measure);
    });

    test('what is measured is what is kept, value for value, on a picture '
        'of many colours', () async {
      // A ramp of every strength of red, green and blue, with soft edges
      // where the scaling mixes them.
      final png = await _png(256, 512, (canvas) {
        for (var x = 0; x < 256; x++) {
          canvas
            ..drawRect(
              ui.Rect.fromLTWH(x.toDouble(), 0, 1, 170),
              ui.Paint()..color = ui.Color.fromARGB(255, x, 0, 255 - x),
            )
            ..drawRect(
              ui.Rect.fromLTWH(x.toDouble(), 170, 1, 170),
              ui.Paint()..color = ui.Color.fromARGB(255, 0, x, x ~/ 2),
            )
            ..drawRect(
              ui.Rect.fromLTWH(x.toDouble(), 340, 1, 172),
              ui.Paint()..color = ui.Color.fromARGB(255, 255 - x, x, 40),
            );
        }
      });
      final photo = await openReal(await pickedFile('ramp.png', png));
      final pixels = (await real.render(
        from: photo,
        crop: const OwnPhotoCrop(left: 0.1, top: 0.05, right: 0.9, bottom: 1),
        width: 90,
        height: 190,
      ))!;
      // The file, decoded again, is the measured bytes exactly.
      final codec = await ui.instantiateImageCodec(pixels.encoded);
      final image = (await codec.getNextFrame()).image;
      final decoded = (await image.toByteData())!.buffer.asUint8List();
      expect((image.width, image.height), (90, 190));
      expect(decoded, pixels.rgba);
      image.dispose();
      codec.dispose();
    });

    test('a see-through picture is kept solid, on black', () async {
      final png = await _png(40, 80, (canvas) {
        // Half see-through white over nothing.
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 40, 80),
          ui.Paint()..color = const ui.Color(0x80FFFFFF),
        );
      });
      final record = (await usecase(real).save(
        photo: await openReal(await pickedFile('ghost.png', png)),
        crop: OwnPhotoCrop.whole,
        screenWidth: 40,
        screenHeight: 80,
      )).getOrThrow();
      expect(record.measure.brightest, inInclusiveRange(126, 130));
      final (_, _, pixels) = await savedPixels(record.stamp);
      for (var at = 3; at < pixels.length; at += 4) {
        expect(pixels[at], 255);
      }
    });

    test('a picture larger than the working size is decoded down to it, '
        'in its own shape', () async {
      final wide = await _png(4000, 1000, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 4000, 1000),
          ui.Paint()..color = const ui.Color(0xFF336699),
        );
      });
      final photo = await openReal(await pickedFile('wide.png', wide));
      expect(photo.width, OwnPhotoLimits.workingSide);
      expect(photo.height, 800);
      final header = (await real.describe('${root.path}/wide.png'))!;
      expect((header.width, header.height), (4000, 1000));
      expect(header.isAnimated, isFalse);
    });

    test('a moving picture is turned away as the wrong type, whatever it '
        'is called', () async {
      final moving = await pickedFile('party.webp', _movingGif);
      final header = (await real.describe(moving.path))!;
      expect(header.isAnimated, isTrue);
      expect(
        _code(await usecase(real).open(moving)),
        ImportOwnPhotoUsecase.wrongTypeCode,
      );
      // And the decoder itself will not open one.
      expect(await real.open(moving.path), isNull);
    });

    test('bytes that are not an image are unreadable, whatever the file '
        'is called', () async {
      final text = await pickedFile(
        'holiday.jpg',
        'this is not a picture'.codeUnits,
      );
      expect(
        _code(await usecase(real).open(text)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      // The start of a PNG and nothing after it.
      final cut = await pickedFile('cut.png', [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0, //
      ]);
      expect(
        _code(await usecase(real).open(cut)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      expect(store.photo, isNull);
    });

    test('a file that is gone is unreadable', () async {
      expect(await real.describe('${root.path}/nothing.png'), isNull);
      expect(await real.open('${root.path}/nothing.png'), isNull);
    });
  });

  group('the store:', () {
    const measure = OwnPhotoMeasure(
      columns: 1,
      rows: 1,
      peaks: [200],
      lows: [10],
    );

    Future<void> save(List<int> bytes) => store.savePhoto(
      Uint8List.fromList(bytes),
      width: 2,
      height: 2,
      measure: measure,
    );

    test('one photo: saving another deletes the one before', () async {
      await save([1, 1, 1]);
      final first = files().single.path;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await save([2, 2, 2, 2]);
      expect(files(), hasLength(1));
      expect(files().single.path, isNot(first));
      expect(await store.readPhoto(store.photo!.stamp), [2, 2, 2, 2]);
    });

    test(
      "the file is in a folder of its own under the app's storage",
      () async {
        await save([1]);
        expect(files().single.path, startsWith('${root.path}/alarm_look/own_'));
        expect(files().single.path, endsWith('.png'));
      },
    );

    test('removing the photo deletes the file and its record, and keeps '
        'the accent', () async {
      await save([1]);
      final stamp = store.photo!.stamp;
      await store.setAccent('sky');
      await store.removePhoto();
      expect(files(), isEmpty);
      expect(store.photo, isNull);
      expect(await store.readPhoto(stamp), isNull);
      expect(store.accentId, 'sky');
    });

    test('the wipe takes the file, the record and the accent, and any '
        'stray file in the folder', () async {
      await save([1]);
      await store.setAccent('sky');
      File('${root.path}/alarm_look/own_old.png.part').writeAsBytesSync([9]);
      await store.forgetAll();
      expect(files(), isEmpty);
      expect(prefs.getKeys(), isEmpty);
    });

    test('a record with no file, a file too large and a record that does '
        'not read back all read as no photo', () async {
      await save([1]);
      final stamp = store.photo!.stamp;
      files().single.deleteSync();
      expect(store.photo, isNotNull);
      expect(await store.readPhoto(stamp), isNull);

      await prefs.setString(OwnLookStore.photoKey, 'not json');
      expect(store.photo, isNull);
      await prefs.setString(
        OwnLookStore.photoKey,
        '{"stamp":"../../etc","w":2,"h":2,"m":${measure.encode()}}',
      );
      expect(store.photo, isNull);
      await prefs.setString(
        OwnLookStore.photoKey,
        '{"stamp":"abc","w":2,"h":2,"m":{"v":1}}',
      );
      expect(store.photo, isNull);
      await prefs.setInt(OwnLookStore.photoKey, 3);
      expect(store.photo, isNull);
      // A stamp that is not one this store writes reads nothing, and
      // never reaches outside the photo's folder.
      expect(await store.readPhoto('../../etc/passwd'), isNull);
      expect(await store.readPhoto(''), isNull);
    });

    test('a photo is read by the stamp of its record: while another is '
        'being saved, the first record never gets the second file', () async {
      await save([1, 1, 1]);
      final first = store.photo!;
      expect(await store.readPhoto(first.stamp), [1, 1, 1]);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await save([2, 2, 2, 2]);
      // The first file is gone with its record: nothing, never the new
      // pixels under the old measure.
      expect(await store.readPhoto(first.stamp), isNull);
      expect(await store.readPhoto(store.photo!.stamp), [2, 2, 2, 2]);
    });

    test('the sweep deletes every file the record does not name, and '
        'keeps the one it does', () async {
      await save([1]);
      final kept = files().single.path;
      // A photo written by an app that was killed before its record
      // was, a half-written one, and one whose delete failed.
      File('${root.path}/alarm_look/own_zzz999.png').writeAsBytesSync([7]);
      File('${root.path}/alarm_look/own_abc.png.part').writeAsBytesSync([8]);
      File('${root.path}/alarm_look/own_old1.png').writeAsBytesSync([9]);
      expect(files(), hasLength(4));
      await store.sweep();
      expect(files().map((file) => file.path), [kept]);
      expect(await store.readPhoto(store.photo!.stamp), [1]);
    });

    test('with no record, the sweep empties the folder', () async {
      await save([1]);
      await prefs.remove(OwnLookStore.photoKey);
      await store.sweep();
      expect(files(), isEmpty);
      // And a folder that was never made is no error.
      await root.delete(recursive: true);
      await store.sweep();
    });

    test('a copy a pick left in the cache is noted, and deleted when the '
        'pick ends or at the next launch', () async {
      final copy = File('${root.path}/picker_cache_IMG_1.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      await store.notePending(copy.path);
      expect(prefs.getString(OwnLookStore.pendingKey), copy.path);
      await store.discardPending();
      expect(copy.existsSync(), isFalse);
      expect(prefs.getString(OwnLookStore.pendingKey), isNull);
      // Nothing noted, or a copy already gone: no error.
      await store.discardPending();
      await store.notePending('${root.path}/gone.jpg');
      await store.discardPending();
      expect(prefs.getString(OwnLookStore.pendingKey), isNull);
    });

    test('a note never deletes a folder', () async {
      final folder = Directory('${root.path}/a_folder')..createSync();
      File('${folder.path}/kept.txt').writeAsStringSync('kept');
      await store.notePending(folder.path);
      await store.discardPending();
      expect(File('${folder.path}/kept.txt').existsSync(), isTrue);
    });

    test(
      'the wipe deletes a copy a pick left behind, with the photo',
      () async {
        await save([1]);
        final copy = File('${root.path}/picker_cache_IMG_2.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        await store.notePending(copy.path);
        await store.forgetAll();
        expect(copy.existsSync(), isFalse);
        expect(files(), isEmpty);
        expect(prefs.getKeys(), isEmpty);
      },
    );

    test('a photo this store would never write is refused', () async {
      expect(() => save([]), throwsA(isA<FileSystemException>()));
      expect(store.photo, isNull);
    });

    test('every change fires', () async {
      var fired = 0;
      final subscription = store.changes.listen((_) => fired++);
      addTearDown(subscription.cancel);
      await save([1]);
      await store.setAccent('sky');
      await store.removePhoto();
      await store.forgetAll();
      await Future<void>.delayed(Duration.zero);
      expect(fired, 4);
    });
  });
}
