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

/// A codec that decodes nothing: it answers what the test tells it to and
/// counts what it was asked.
class _FakeCodec implements OwnPhotoCodec {
  ({int width, int height})? size = (width: 3000, height: 4000);
  bool sizeThrows = false;
  bool renderFails = false;
  bool renderThrows = false;
  int sizeCalls = 0;
  int renderCalls = 0;
  ({OwnPhotoCrop crop, int width, int height})? rendered;

  @override
  Future<({int width, int height})?> sizeOf(String path) async {
    sizeCalls++;
    if (sizeThrows) throw const FileSystemException('gone');
    return size;
  }

  @override
  Future<OwnPhotoPixels?> render({
    required String path,
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
  const source = OwnPhotoSource(
    path: '/picked/IMG_0001.JPG',
    width: 3000,
    height: 4000,
  );

  setUp(() async {
    isLocked = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    root = await Directory.systemTemp.createTemp('own_photo_import_');
    store = FileOwnLookStore(prefs, () async => root);
    codec = _FakeCodec();
  });

  tearDown(() async {
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
      expect(OwnPhotoLimits.maxSourcePixels, 50000000);
      expect(OwnPhotoLimits.maxDecodedPixels, 16000000);
      expect(OwnPhotoLimits.maxSide, 1600);
      expect(OwnLookStore.maxStoredBytes, 24 * 1024 * 1024);
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
      final result = await usecase().check(
        const PickedOwnPhoto(
          path: '/picked/song.mp3',
          name: 'song.mp3',
          sizeBytes: 1000,
        ),
      );
      expect(_code(result), ImportOwnPhotoUsecase.wrongTypeCode);
      expect(codec.sizeCalls, 0);
    });

    test('a file over the size cap is turned away before anything opens '
        'it', () async {
      final result = await usecase().check(
        const PickedOwnPhoto(
          path: '/picked/huge.png',
          name: 'huge.png',
          sizeBytes: OwnPhotoLimits.maxSourceBytes + 1,
        ),
      );
      expect(_code(result), ImportOwnPhotoUsecase.tooLargeCode);
      expect(codec.sizeCalls, 0);
      expect(codec.renderCalls, 0);
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
      codec.size = (width: 10000, height: 5001);
      final result = await usecase().check(picked);
      expect(_code(result), ImportOwnPhotoUsecase.tooLargeCode);
      expect(codec.sizeCalls, 1);
      expect(codec.renderCalls, 0);
    });

    test('a file that is not an image, an empty one and one that cannot '
        'be opened are unreadable', () async {
      codec.size = null;
      expect(
        _code(await usecase().check(picked)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      codec
        ..size = (width: 0, height: 10)
        ..sizeThrows = false;
      expect(
        _code(await usecase().check(picked)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      codec.sizeThrows = true;
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
      codec.size = null;
      final failure = (await usecase().check(picked)).exceptionOrNull()!;
      expect('$failure', isNot(contains('IMG_0001')));
      expect('$failure', isNot(contains('/picked')));
    });
  });

  group('keeping the framed part:', () {
    // The middle of the picture, in the shape of a phone.
    const crop = OwnPhotoCrop(left: 0.25, top: 0.1, right: 0.75, bottom: 0.9);

    test('it is scaled to the screen, measured, written to one file and '
        'recorded', () async {
      final result = await usecase().save(
        source: source,
        crop: crop,
        screenWidth: 750,
        screenHeight: 1334,
      );
      final record = result.getOrThrow();
      // 1500 by 3200 pixels of the picture, on a 750 by 1334 screen.
      expect(codec.rendered!.width, 625);
      expect(codec.rendered!.height, 1334);
      expect(codec.rendered!.crop, crop);
      expect((record.width, record.height), (625, 1334));
      // Measured on the pixels that were kept.
      expect(record.measure.brightest, 90);
      expect(record.measure.darkest, 90);
      expect(record.measure.peaks, hasLength(128));
      expect(files(), hasLength(1));
      expect(files().single.readAsBytesSync(), [1, 2, 3, 4]);
      expect(await store.readPhoto(), [1, 2, 3, 4]);
      expect(store.photo!.stamp, record.stamp);
    });

    test('a picture that cannot be decoded, or a decode that runs out of '
        'memory, saves nothing and keeps the photo that was there', () async {
      await usecase().save(
        source: source,
        crop: crop,
        screenWidth: 750,
        screenHeight: 1334,
      );
      final before = store.photo!.stamp;

      codec.renderFails = true;
      expect(
        _code(
          await usecase().save(
            source: source,
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
            source: source,
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
      for (final bad in const [
        OwnPhotoCrop(left: 0.5, top: 0, right: 0.5, bottom: 1),
        OwnPhotoCrop(left: -0.1, top: 0, right: 1, bottom: 1),
        OwnPhotoCrop(left: 0, top: 0, right: 1.2, bottom: 1),
        OwnPhotoCrop(left: 0.8, top: 0, right: 0.2, bottom: 1),
      ]) {
        expect(
          _code(
            await usecase().save(
              source: source,
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

    test(
      'with looks locked for certain, nothing is decoded or saved',
      () async {
        isLocked = true;
        final result = await usecase().save(
          source: source,
          crop: crop,
          screenWidth: 750,
          screenHeight: 1334,
        );
        expect(_code(result), ImportOwnPhotoUsecase.lockedCode);
        expect(codec.renderCalls, 0);
        expect(files(), isEmpty);
      },
    );

    test('a plan nobody can read turns nothing away', () async {
      final unsure = ImportOwnPhotoUsecase(
        codec,
        store,
        isLocked: () async => throw StateError('unread'),
      );
      final result = await unsure.save(
        source: source,
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
        source: source,
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
      final file = await pickedFile('split.png', png);
      final checked = (await usecase(real).check(file)).getOrThrow();
      expect((checked.width, checked.height), (200, 400));

      // The left half only: all white.
      final record = (await usecase(real).save(
        source: checked,
        crop: const OwnPhotoCrop(left: 0, top: 0, right: 0.5, bottom: 1),
        screenWidth: 50,
        screenHeight: 200,
      )).getOrThrow();
      expect((record.width, record.height), (50, 200));
      expect(record.measure.darkest, 255);
      expect(record.measure.brightest, 255);

      // What is on disk is that picture.
      final saved = (await store.readPhoto())!;
      final codec = await ui.instantiateImageCodec(saved);
      final image = (await codec.getNextFrame()).image;
      expect((image.width, image.height), (50, 200));
      final pixels = (await image.toByteData())!.buffer.asUint8List();
      expect(
        measureOwnPhoto(pixels, image.width, image.height),
        record.measure,
      );
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
      final checked = (await usecase(
        real,
      ).check(await pickedFile('ghost.png', png))).getOrThrow();
      final record = (await usecase(real).save(
        source: checked,
        crop: OwnPhotoCrop.whole,
        screenWidth: 40,
        screenHeight: 80,
      )).getOrThrow();
      expect(record.measure.brightest, inInclusiveRange(126, 130));
      final saved = (await store.readPhoto())!;
      final codec = await ui.instantiateImageCodec(saved);
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData())!.buffer.asUint8List();
      for (var at = 3; at < pixels.length; at += 4) {
        expect(pixels[at], 255);
      }
      image.dispose();
      codec.dispose();
    });

    test('bytes that are not an image are unreadable, whatever the file '
        'is called', () async {
      final text = await pickedFile(
        'holiday.jpg',
        'this is not a picture'.codeUnits,
      );
      expect(
        _code(await usecase(real).check(text)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      // The start of a PNG and nothing after it.
      final cut = await pickedFile('cut.png', [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0, //
      ]);
      expect(
        _code(await usecase(real).check(cut)),
        ImportOwnPhotoUsecase.unreadableCode,
      );
      expect(store.photo, isNull);
    });

    test('a file that is gone is unreadable', () async {
      expect(await real.sizeOf('${root.path}/nothing.png'), isNull);
      expect(
        await real.render(
          path: '${root.path}/nothing.png',
          crop: OwnPhotoCrop.whole,
          width: 10,
          height: 10,
        ),
        isNull,
      );
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
      expect(await store.readPhoto(), [2, 2, 2, 2]);
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
      await store.setAccent('sky');
      await store.removePhoto();
      expect(files(), isEmpty);
      expect(store.photo, isNull);
      expect(await store.readPhoto(), isNull);
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
      files().single.deleteSync();
      expect(store.photo, isNotNull);
      expect(await store.readPhoto(), isNull);

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
      expect(await store.readPhoto(), isNull);
    });

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
