import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/features/incidents/data/own_look/file_own_look_store.dart';
import 'package:critalarm/features/incidents/data/own_look/ui_own_photo_codec.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_photo_hold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A real PNG, [width] by [height], with two flat halves.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height / 2),
      ui.Paint()..color = const ui.Color(0xFF204060),
    )
    ..drawRect(
      ui.Rect.fromLTWH(0, height / 2, width.toDouble(), height / 2),
      ui.Paint()..color = const ui.Color(0xFFE0C080),
    );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  late Directory storeRoot;
  late Directory pickedRoot;
  late SharedPreferences prefs;
  late FileOwnLookStore store;
  late OwnPhotoHold hold;
  var isLocked = true;
  final storeEvents = <void>[];
  StreamSubscription<void>? listening;

  ImportOwnPhotoUsecase usecase() => ImportOwnPhotoUsecase(
    const UiOwnPhotoCodec(),
    store,
    isLocked: () async => isLocked,
  );

  /// The picked file, framed and ready to hold, as the page would have it.
  Future<OwnPhotoPrepared> framed() async {
    final bytes = await _png(120, 240);
    final file = File('${pickedRoot.path}/picked.png');
    await file.writeAsBytes(bytes);
    final working = (await usecase().open(
      PickedOwnPhoto(
        path: file.path,
        name: 'picked.png',
        sizeBytes: bytes.length,
      ),
    )).getOrThrow();
    addTearDown(working.dispose);
    return (await usecase().prepare(
      photo: working,
      crop: const OwnPhotoCrop(left: 0, top: 0.25, right: 1, bottom: 0.75),
      screenWidth: 100,
      screenHeight: 100,
    )).getOrThrow();
  }

  /// Everything on disk under the store's folder, and every preference.
  List<FileSystemEntity> onDisk() => storeRoot.existsSync()
      ? storeRoot.listSync(recursive: true)
      : const <FileSystemEntity>[];

  setUp(() async {
    isLocked = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storeRoot = await Directory.systemTemp.createTemp('own_hold_store_');
    pickedRoot = await Directory.systemTemp.createTemp('own_hold_picked_');
    store = FileOwnLookStore(prefs, () async => storeRoot);
    storeEvents.clear();
    listening = store.changes.listen(storeEvents.add);
    hold = OwnPhotoHold();
    holdOwnAlarmStyle(null);
  });

  tearDown(() async {
    hold.dispose();
    await listening?.cancel();
    await store.dispose();
    holdOwnAlarmStyle(null);
    for (final dir in [storeRoot, pickedRoot]) {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  });

  group('a photo held with no plan writes nothing:', () {
    test('preparing and holding it leaves the store, the preferences and '
        'the alarm screen as they were', () async {
      final prepared = await framed();
      expect(await hold.hold(prepared), isTrue);

      expect(hold.hasPhoto, isTrue);
      expect(hold.style, isNotNull);
      expect(onDisk(), isEmpty, reason: 'no file and no folder was made');
      expect(prefs.getKeys(), isEmpty, reason: 'no record and no flag');
      expect(store.photo, isNull);
      expect(store.accentId, isNull);
      expect(storeEvents, isEmpty, reason: 'the store was not touched');
      // The alarm screen reads this field and never the held photo.
      expect(heldOwnAlarmStyle, isNull);
    });

    test(
      'picking the colour is held with the photo and writes nothing',
      () async {
        await hold.hold(await framed());
        final sky = ownLookAccents.firstWhere((accent) => accent.id == 'sky');
        final before = hold.style;
        hold.setAccent(sky);
        expect(hold.accent.id, 'sky');
        expect(identical(hold.style, before), isFalse, reason: 'rebuilt');

        expect(onDisk(), isEmpty);
        expect(prefs.getKeys(), isEmpty);
        expect(store.accentId, isNull);
        expect(storeEvents, isEmpty);
      },
    );

    test('holding a second photo replaces the first and keeps the colour '
        'and still writes nothing', () async {
      await hold.hold(await framed());
      hold.setAccent(ownLookAccents.last);
      await hold.hold(await framed());
      expect(hold.accent.id, ownLookAccents.last.id);
      expect(onDisk(), isEmpty);
      expect(prefs.getKeys(), isEmpty);
    });

    test('the write turns a held photo away while looks are locked', () async {
      await hold.hold(await framed());
      final encoded = (await hold.encode())!;
      final size = hold.size!;
      final result = await usecase().keep(
        encoded,
        width: size.width,
        height: size.height,
        measure: hold.measure!,
      );
      expect(
        result.exceptionOrNull()?.message,
        ImportOwnPhotoUsecase.lockedCode,
      );
      expect(onDisk(), isEmpty);
      expect(prefs.getKeys(), isEmpty);
    });

    test('letting it go, or closing the page, leaves nothing behind', () async {
      await hold.hold(await framed());
      hold.drop();
      expect(hold.hasPhoto, isFalse);
      expect(hold.style, isNull);
      expect(hold.size, isNull);
      expect(await hold.encode(), isNull);
      await hold.hold(await framed());
      hold.dispose();
      expect(hold.hasPhoto, isFalse);
      expect(hold.size, isNull);
      expect(onDisk(), isEmpty);
      expect(prefs.getKeys(), isEmpty);
    });

    test('a disposed hold takes no photo', () async {
      final prepared = await framed();
      hold.dispose();
      expect(await hold.hold(prepared), isFalse);
      expect(hold.hasPhoto, isFalse);
    });
  });

  group('the held picture:', () {
    test(
      'is one picture at the size the engine would keep, in 8 bits',
      () async {
        final prepared = await framed();
        await hold.hold(prepared);
        // 120 by 120 pixels of the middle half, under the screen's own size.
        expect(hold.size, (width: 100, height: 100));
        expect(prepared.pixels.rgba.length, 100 * 100 * 4);
        expect(
          hold.size!.width,
          lessThanOrEqualTo(OwnPhotoLimits.maxSide),
        );
      },
    );

    test('tells its owner when it changes', () async {
      var calls = 0;
      hold.addListener(() => calls++);
      await hold.hold(await framed());
      hold
        ..setAccent(ownLookAccents.last)
        ..drop();
      expect(calls, 3);
    });
  });

  group('keeping a held photo once the plan is held:', () {
    test('writes the photo that is in memory, with its colour, and nothing '
        'else', () async {
      await hold.hold(await framed());
      hold.setAccent(ownLookAccents[2]);
      final measure = hold.measure!;
      final size = hold.size!;

      isLocked = false;
      final encoded = (await hold.encode())!;
      final record = (await usecase().keep(
        encoded,
        width: size.width,
        height: size.height,
        measure: measure,
      )).getOrThrow();

      expect(record.width, size.width);
      expect(record.height, size.height);
      expect(record.measure.encode(), measure.encode());
      final files = onDisk().whereType<File>().toList();
      expect(files, hasLength(1));
      // The file is the held picture, and decodes at the recorded size.
      final bytes = await store.readPhoto(record.stamp);
      final image = await decodeOwnPhoto(bytes!, size.width, size.height);
      expect(image, isNotNull);
      image!.dispose();
      expect(storeEvents, isNotEmpty);
    });
  });
}
