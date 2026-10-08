// Made-up photos for the captures of the own alarm look, and the calls
// that put one on the capture's phone the way the app does: through the
// import, into a store, held by the keeper. No image file is kept in the
// repo. Imported by `capture_alarm_screen.dart` and
// `capture_personalize.dart`. It is not a capture itself.
//
// Developer tool.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/features/incidents/data/own_look/file_own_look_store.dart';
import 'package:critalarm/features/incidents/data/own_look/ui_own_photo_codec.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The photos a capture can put behind the alarm screen.
enum CapturePhoto {
  /// A beach at noon: almost all of it near white.
  bright,

  /// A room at night: nothing in it brighter than a dim lamp.
  dark,

  /// Hard black and white blocks under stripes of pure colour.
  busy,
}

const int _width = 900;
const int _height = 1950;

void _paint(ui.Canvas canvas, CapturePhoto photo) {
  const size = ui.Size(900, 1950);
  final all = ui.Offset.zero & size;
  switch (photo) {
    case CapturePhoto.bright:
      canvas
        ..drawRect(
          all,
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset.zero,
              ui.Offset(0, size.height),
              const [
                ui.Color(0xFFBFE6FF),
                ui.Color(0xFFF4FBFF),
                ui.Color(0xFFFFF6DC),
                ui.Color(0xFFFFE9B8),
              ],
              const [0, 0.45, 0.62, 1],
            ),
        )
        // The sun, and its glare.
        ..drawCircle(
          const ui.Offset(640, 420),
          260,
          ui.Paint()..color = const ui.Color(0x80FFFFFF),
        )
        ..drawCircle(
          const ui.Offset(640, 420),
          150,
          ui.Paint()..color = const ui.Color(0xFFFFFFFF),
        )
        // The sea, a pale band with white surf.
        ..drawRect(
          const ui.Rect.fromLTWH(0, 1120, 900, 150),
          ui.Paint()..color = const ui.Color(0xFF9FE0EE),
        )
        ..drawRect(
          const ui.Rect.fromLTWH(0, 1255, 900, 26),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF),
        );
    case CapturePhoto.dark:
      canvas
        ..drawRect(
          all,
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset.zero,
              ui.Offset(0, size.height),
              const [ui.Color(0xFF05070D), ui.Color(0xFF131A2E)],
            ),
        )
        // A lamp, dim, and what it lights.
        ..drawCircle(
          const ui.Offset(250, 1250),
          420,
          ui.Paint()..color = const ui.Color(0x1F8A6A3A),
        )
        ..drawCircle(
          const ui.Offset(250, 1250),
          70,
          ui.Paint()..color = const ui.Color(0xFF96703C),
        )
        // A window, a shade lighter than the wall.
        ..drawRect(
          const ui.Rect.fromLTWH(520, 260, 260, 420),
          ui.Paint()..color = const ui.Color(0xFF1E2A48),
        );
    case CapturePhoto.busy:
      const block = 150.0;
      final ink = ui.Paint()..color = const ui.Color(0xFF000000);
      final paper = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
      for (var row = 0; row * block < size.height; row++) {
        for (var column = 0; column * block < size.width; column++) {
          canvas.drawRect(
            ui.Rect.fromLTWH(column * block, row * block, block, block),
            (row + column).isEven ? paper : ink,
          );
        }
      }
      const stripes = [
        ui.Color(0xFFFF0033),
        ui.Color(0xFF00E5FF),
        ui.Color(0xFFFFEE00),
        ui.Color(0xFF00FF66),
        ui.Color(0xFFFF00E6),
      ];
      canvas
        ..save()
        ..rotate(-math.pi / 7);
      for (var i = 0; i < 12; i++) {
        canvas.drawRect(
          ui.Rect.fromLTWH(-900, 260.0 + i * 190, 2400, 62),
          ui.Paint()..color = stripes[i % stripes.length],
        );
      }
      canvas.restore();
  }
}

/// [photo] as the bytes of a PNG file, 900 by 1950.
Future<Uint8List> capturePhotoPng(CapturePhoto photo) async {
  final recorder = ui.PictureRecorder();
  _paint(ui.Canvas(recorder), photo);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_width, _height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Directory? _root;

/// Points the app's own look store at a folder made for this run, in
/// place of the app support directory a capture has no plugin for. Call
/// it once, after `configureDependencies` and before anything reads the
/// store.
Future<void> useCaptureOwnLookStore() async {
  final root = await Directory.systemTemp.createTemp('own_look_capture_');
  _root = root;
  await getIt.unregister<OwnLookStore>();
  getIt.registerSingleton<OwnLookStore>(
    FileOwnLookStore(getIt<SharedPreferences>(), () async => root),
  );
}

/// Deletes the run's folder.
Future<void> dropCaptureOwnLookStore() async {
  final root = _root;
  if (root != null && root.existsSync()) await root.delete(recursive: true);
}

/// Puts [photo] on the phone as the own look, the way the app does: the
/// file is checked and kept by the import, at the size of a screen
/// [screen] pixels, then decoded and held by the keeper. Prints the scrim
/// it got.
Future<void> importCaptureOwnLook(
  CapturePhoto photo, {
  required ui.Size screen,
  String accent = 'yellow',
}) async {
  final file = File('${_root!.path}/picked_${photo.name}.png');
  await file.writeAsBytes(await capturePhotoPng(photo));
  // The app's own import, with its own decoder and store. Only the lock
  // is stood in for: it waits for the plan to be read, and in a capture
  // that read can belong to an earlier test's clock and never end. The
  // capture holds the plan itself.
  final usecase = ImportOwnPhotoUsecase(
    const UiOwnPhotoCodec(),
    getIt<OwnLookStore>(),
    isLocked: () async => false,
  );
  final checked = (await usecase.check(
    PickedOwnPhoto(
      path: file.path,
      name: 'picked_${photo.name}.png',
      sizeBytes: await file.length(),
    ),
  )).getOrThrow();
  final record = (await usecase.save(
    source: checked,
    crop: OwnPhotoCrop.whole,
    screenWidth: screen.width,
    screenHeight: screen.height,
  )).getOrThrow();
  await file.delete();
  final keeper = getIt<OwnAlarmLookKeeper>();
  await keeper.setAccent(ownLookAccentOf(accent));
  await keeper.start();
  if (!keeper.isReady) throw StateError('the own look is not held');
  print(
    '     own look: ${photo.name} photo kept at '
    '${record.width}x${record.height}, measured '
    '${record.measure.darkest} to ${record.measure.brightest} of 255, '
    '${ownLookScrimOf(record.measure)}, accent ${keeper.accent.id}',
  );
}

/// Deletes the saved photo's file and leaves its record, as a phone
/// whose storage lost the file would be, then loads what is left.
Future<void> loseCaptureOwnLookFile() async {
  final folder = Directory('${_root!.path}/alarm_look');
  for (final entry in folder.listSync()) {
    entry.deleteSync();
  }
  // What the app does at its next launch.
  final keeper = getIt<OwnAlarmLookKeeper>();
  await keeper.dispose();
  await getIt.unregister<OwnAlarmLookKeeper>();
  getIt.registerSingleton(OwnAlarmLookKeeper(getIt<OwnLookStore>()));
  await getIt<OwnAlarmLookKeeper>().start();
  print(
    '     own look: file deleted, record kept, held: '
    '${getIt<OwnAlarmLookKeeper>().isReady}',
  );
}
