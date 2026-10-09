import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/features/incidents/data/own_look/file_own_look_store.dart';
import 'package:critalarm/features/incidents/data/shared_prefs_alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_latch.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A real PNG of one flat grey, [width] by [height].
Future<Uint8List> _png(int width, int height, {int grey = 200}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = ui.Color.fromARGB(255, grey, grey, grey),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

const _measure = OwnPhotoMeasure(
  columns: 1,
  rows: 1,
  peaks: [200],
  lows: [200],
);

void main() {
  late Directory root;
  late SharedPreferences prefs;
  late FileOwnLookStore store;
  final keepers = <OwnAlarmLookKeeper>[];

  OwnAlarmLookKeeper keeper({
    OwnPhotoDecoder decode = decodeOwnPhoto,
    bool Function()? mayHold,
    List<Stream<Object?>> recheck = const [],
  }) {
    final made = OwnAlarmLookKeeper(
      store,
      decode: decode,
      mayHold: mayHold,
      recheck: recheck,
    );
    keepers.add(made);
    return made;
  }

  Future<void> savePhoto({int width = 30, int height = 60}) async =>
      store.savePhoto(
        await _png(width, height),
        width: width,
        height: height,
        measure: _measure,
      );

  File photoFile() => [
    for (final entry in root.listSync(recursive: true))
      if (entry is File) entry,
  ].single;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    root = await Directory.systemTemp.createTemp('own_look_keeper_');
    store = FileOwnLookStore(prefs, () async => root);
    holdOwnAlarmStyle(null);
  });

  tearDown(() async {
    for (final made in keepers) {
      await made.dispose();
    }
    keepers.clear();
    await store.dispose();
    holdOwnAlarmStyle(null);
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('at launch:', () {
    test('nothing saved: nothing is held, and the own look draws the '
        'standard one', () async {
      final own = keeper();
      await own.start();
      expect(own.isReady, isFalse);
      expect(heldOwnAlarmStyle, isNull);
      expect(alarmStyleOf(AlarmStyleId.own), standardAlarmStyle);
    });

    test('a saved photo is decoded and held, and the own look is that '
        'look', () async {
      await savePhoto();
      await store.setAccent('mint');
      final own = keeper();
      await own.start();
      expect(own.isReady, isTrue);
      expect(own.style!.id, AlarmStyleId.own);
      expect(identical(heldOwnAlarmStyle, own.style), isTrue);
      expect(identical(alarmStyleOf(AlarmStyleId.own), own.style), isTrue);
      expect(own.accent.id, 'mint');
      expect(pickableAlarmStyles.last, own.style);
    });
  });

  group('what cannot be drawn holds nothing, and deletes nothing:', () {
    test('the file is missing', () async {
      await savePhoto();
      photoFile().deleteSync();
      final own = keeper();
      await own.start();
      expect(own.isReady, isFalse);
      expect(alarmStyleOf(AlarmStyleId.own), standardAlarmStyle);
      // The record is left: picking a photo again replaces it.
      expect(store.photo, isNotNull);
    });

    test('the file is broken', () async {
      await savePhoto();
      final file = photoFile();
      file.writeAsBytesSync(file.readAsBytesSync().sublist(0, 20));
      final own = keeper();
      await own.start();
      expect(own.isReady, isFalse);
      expect(alarmStyleOf(AlarmStyleId.own), standardAlarmStyle);
      expect(photoFile().existsSync(), isTrue);
    });

    test('the file is not a picture at all', () async {
      await savePhoto();
      photoFile().writeAsStringSync('not a picture');
      final own = keeper();
      await own.start();
      expect(own.isReady, isFalse);
    });

    test(
      'the file is a picture of another size than the record says',
      () async {
        // The measure beside it was not made on these pixels.
        await store.savePhoto(
          await _png(30, 60),
          width: 31,
          height: 60,
          measure: _measure,
        );
        final own = keeper();
        await own.start();
        expect(own.isReady, isFalse);
      },
    );

    test('the record names a picture larger than the app ever keeps: it '
        'is not decoded', () async {
      await store.savePhoto(
        await _png(30, 60),
        width: 30000,
        height: 60000,
        measure: _measure,
      );
      var decodes = 0;
      final own = keeper(
        decode: (bytes, width, height) async {
          decodes++;
          return null;
        },
      );
      await own.start();
      expect(own.isReady, isFalse);
      expect(decodes, 0);
    });

    test('the decode fails for want of memory', () async {
      await savePhoto();
      final own = keeper(
        decode: (bytes, width, height) async => throw StateError('no memory'),
      );
      await own.start();
      expect(own.isReady, isFalse);
      expect(alarmStyleOf(AlarmStyleId.own), standardAlarmStyle);
      // The photo is still the person's. A later launch tries again.
      expect(photoFile().existsSync(), isTrue);
      expect(store.photo, isNotNull);
    });

    test('the record does not read back', () async {
      await savePhoto();
      await prefs.setString(OwnLookStore.photoKey, '{"stamp":"x"}');
      final own = keeper();
      await own.start();
      expect(own.isReady, isFalse);
    });
  });

  group('an alarm that rings before the decode is done:', () {
    test('draws the standard look, and keeps it for that incident when the '
        'photo is ready a moment later', () async {
      await savePhoto();
      final choices = SharedPrefsAlarmStyleChoices(prefs);
      addTearDown(choices.dispose);
      await choices.setDefault('own');
      final gate = Completer<void>();
      final own = keeper(
        decode: (bytes, width, height) async {
          await gate.future;
          return decodeOwnPhoto(bytes, width, height);
        },
      );
      final styles = AlarmStyleGate(
        choices: choices,
        decide: () => const FeatureDecision.open(),
        decideOnceReady: () async => const FeatureDecision.open(),
        readAccountId: () async => 'acc_1',
        planRead: Future<void>.value(),
        isOwnLookReady: () => own.isReady,
      );
      final latch = AlarmStyleLatch();
      AlarmStyleId drawn(String incident) =>
          latch.styleFor(incident, decide: () => styles.styleFor('prod-db'));

      final starting = own.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // The phone rings now. The photo is still decoding.
      expect(own.isReady, isFalse);
      expect(drawn('inc_1'), AlarmStyleId.standard);
      expect(alarmStyleOf(drawn('inc_1')), standardAlarmStyle);

      gate.complete();
      await starting;
      expect(own.isReady, isTrue);
      // The same incident does not change look under a reaching thumb.
      expect(drawn('inc_1'), AlarmStyleId.standard);
      // The next one is drawn in the own look.
      expect(drawn('inc_2'), AlarmStyleId.own);
      expect(identical(alarmStyleOf(drawn('inc_2')), own.style), isTrue);
    });

    test('a look that was held when the alarm rang and is gone a moment '
        'later draws the standard look', () async {
      await savePhoto();
      final own = keeper();
      await own.start();
      final latch = AlarmStyleLatch();
      expect(
        latch.styleFor('inc_1', decide: () => AlarmStyleId.own),
        AlarmStyleId.own,
      );
      final photo = own.style;
      expect(alarmStyleOf(AlarmStyleId.own), photo);

      // The account is left while the alarm is on screen.
      await store.forgetAll();
      await Future<void>.delayed(Duration.zero);
      expect(
        latch.styleFor('inc_1', decide: () => AlarmStyleId.own),
        AlarmStyleId.own,
      );
      expect(alarmStyleOf(AlarmStyleId.own), standardAlarmStyle);
    });
  });

  group('changes:', () {
    test('a new accent rebuilds the look from the picture already held, '
        'with nothing decoded again', () async {
      await savePhoto();
      var decodes = 0;
      final own = keeper(
        decode: (bytes, width, height) {
          decodes++;
          return decodeOwnPhoto(bytes, width, height);
        },
      );
      await own.start();
      final before = own.style;
      var fired = 0;
      final subscription = own.changes.listen((_) => fired++);
      addTearDown(subscription.cancel);

      await own.setAccent(ownLookAccentOf('sky'));
      await Future<void>.delayed(Duration.zero);

      expect(decodes, 1);
      expect(own.isReady, isTrue);
      expect(identical(own.style, before), isFalse);
      expect(identical(heldOwnAlarmStyle, own.style), isTrue);
      expect(store.accentId, 'sky');
      expect(fired, greaterThanOrEqualTo(1));
    });

    test('a new photo replaces the one held', () async {
      await savePhoto();
      final own = keeper();
      await own.start();
      final before = own.style;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await savePhoto(width: 40, height: 80);
      await own.refresh();
      expect(own.isReady, isTrue);
      expect(identical(own.style, before), isFalse);
    });

    test('a photo saved while an older one is still decoding wins', () async {
      await savePhoto();
      final slow = Completer<void>();
      var decodes = 0;
      final own = keeper(
        decode: (bytes, width, height) async {
          if (decodes++ == 0) await slow.future;
          return decodeOwnPhoto(bytes, width, height);
        },
      );
      final first = own.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await savePhoto(width: 40, height: 80);
      await own.refresh();
      expect(own.isReady, isTrue);
      final newer = own.style;
      slow.complete();
      await first;
      expect(identical(own.style, newer), isTrue);
      expect(store.photo!.width, 40);
    });

    test('removing the photo clears what is held, then deletes the '
        'file', () async {
      await savePhoto();
      final own = keeper();
      await own.start();
      await own.removePhoto();
      expect(own.isReady, isFalse);
      expect(heldOwnAlarmStyle, isNull);
      expect(alarmStyleOf(AlarmStyleId.own), standardAlarmStyle);
      expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
      expect(store.photo, isNull);
    });

    test('the account wipe clears what is held with no call from '
        'anyone', () async {
      await savePhoto();
      final own = keeper();
      await own.start();
      expect(own.isReady, isTrue);
      await store.forgetAll();
      await Future<void>.delayed(Duration.zero);
      expect(own.isReady, isFalse);
      expect(heldOwnAlarmStyle, isNull);
    });

    test('a photo removed while it is still decoding is never held', () async {
      await savePhoto();
      final slow = Completer<void>();
      final own = keeper(
        decode: (bytes, width, height) async {
          await slow.future;
          return decodeOwnPhoto(bytes, width, height);
        },
      );
      final starting = own.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await own.removePhoto();
      slow.complete();
      await starting;
      expect(own.isReady, isFalse);
      expect(heldOwnAlarmStyle, isNull);
    });
  });

  group('while alarm looks are locked:', () {
    test('nothing is decoded and nothing is held, and the photo is still '
        'known to be saved so it can be removed', () async {
      await savePhoto();
      var decodes = 0;
      final own = keeper(
        mayHold: () => false,
        decode: (bytes, width, height) {
          decodes++;
          return decodeOwnPhoto(bytes, width, height);
        },
      );
      await own.start();
      expect(decodes, 0);
      expect(own.isReady, isFalse);
      expect(heldOwnAlarmStyle, isNull);
      expect(own.hasPhoto, isTrue);
      expect(photoFile().existsSync(), isTrue);

      await own.removePhoto();
      expect(own.hasPhoto, isFalse);
      expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test('a plan that ends lets the picture go, and a plan that comes back '
        'decodes it again', () async {
      await savePhoto();
      var isOpen = true;
      var decodes = 0;
      final plan = StreamController<Object?>.broadcast();
      addTearDown(plan.close);
      final own = keeper(
        mayHold: () => isOpen,
        recheck: [plan.stream],
        decode: (bytes, width, height) {
          decodes++;
          return decodeOwnPhoto(bytes, width, height);
        },
      );
      await own.start();
      expect(own.isReady, isTrue);
      final held = own.style;

      isOpen = false;
      plan.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(own.isReady, isFalse);
      expect(heldOwnAlarmStyle, isNull);
      expect(alarmStyleOf(AlarmStyleId.own), standardAlarmStyle);
      expect(own.hasPhoto, isTrue);
      expect(photoFile().existsSync(), isTrue);

      isOpen = true;
      plan.add(null);
      await own.refresh();
      expect(own.isReady, isTrue);
      expect(identical(own.style, held), isFalse);
      expect(decodes, 2);
    });

    test('a lock that lands while the photo is decoding: the picture is '
        'not kept', () async {
      await savePhoto();
      var isOpen = true;
      final slow = Completer<void>();
      final own = keeper(
        mayHold: () => isOpen,
        decode: (bytes, width, height) async {
          await slow.future;
          return decodeOwnPhoto(bytes, width, height);
        },
      );
      final starting = own.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      isOpen = false;
      slow.complete();
      await starting;
      expect(own.isReady, isFalse);
      expect(heldOwnAlarmStyle, isNull);
    });

    test('a check of the plan that changes nothing does not rebuild the '
        'look an alarm may be drawn in', () async {
      await savePhoto();
      final plan = StreamController<Object?>.broadcast();
      addTearDown(plan.close);
      var decodes = 0;
      final own = keeper(
        mayHold: () => true,
        recheck: [plan.stream],
        decode: (bytes, width, height) {
          decodes++;
          return decodeOwnPhoto(bytes, width, height);
        },
      );
      await own.start();
      final held = own.style;
      plan
        ..add(null)
        ..add(null);
      await Future<void>.delayed(Duration.zero);
      await own.refresh();
      expect(identical(own.style, held), isTrue);
      expect(decodes, 1);
    });

    test('an answer that throws holds nothing', () async {
      await savePhoto();
      final own = keeper(mayHold: () => throw StateError('no gate'));
      await own.start();
      expect(own.isReady, isFalse);
    });
  });

  group('what an earlier run left behind is cleared at launch:', () {
    test('a photo file with no record: the app was killed between the '
        'file and its record', () async {
      await savePhoto();
      final kept = photoFile().path;
      File('${root.path}/alarm_look/own_orphan1.png').writeAsBytesSync([1]);
      File('${root.path}/alarm_look/own_x.png.part').writeAsBytesSync([2]);
      final own = keeper();
      await own.start();
      expect(
        root.listSync(recursive: true).whereType<File>().map((f) => f.path),
        [kept],
      );
      expect(own.isReady, isTrue);
    });

    test('a photo file and no record at all', () async {
      await Directory('${root.path}/alarm_look').create();
      File('${root.path}/alarm_look/own_orphan2.png').writeAsBytesSync([1]);
      final own = keeper();
      await own.start();
      expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
      expect(own.hasPhoto, isFalse);
    });

    test("the copy the system's picker made for a pick that never "
        'ended', () async {
      final copy = File('${root.path}/picker_IMG_9.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      await store.notePending(copy.path);
      final own = keeper();
      await own.start();
      expect(copy.existsSync(), isFalse);
      expect(prefs.getString(OwnLookStore.pendingKey), isNull);
    });

    test('locked or not: the sweep does not wait for a plan', () async {
      await Directory('${root.path}/alarm_look').create();
      File('${root.path}/alarm_look/own_orphan3.png').writeAsBytesSync([1]);
      final own = keeper(mayHold: () => false);
      await own.start();
      expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
    });
  });
}
