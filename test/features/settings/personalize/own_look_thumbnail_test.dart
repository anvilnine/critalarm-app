import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/settings/presentation/personalize/own_look_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStore extends Mock implements OwnLookStore {}

/// A plain picture [width] by [height], as a PNG file.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF2E7D32),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

OwnPhotoRecord _record(int width, int height) => OwnPhotoRecord(
  stamp: 'a',
  width: width,
  height: height,
  measure: const OwnPhotoMeasure(columns: 0, rows: 0, peaks: [], lows: []),
);

void main() {
  testWidgets('the saved photo is decoded small', (tester) async {
    final store = _MockStore();
    when(() => store.photo).thenReturn(_record(390, 844));
    final image = await tester.runAsync<ui.Image?>(() async {
      final bytes = await _png(390, 844);
      when(() => store.readPhoto('a')).thenAnswer((_) async => bytes);
      return loadOwnLookThumbnail(store, height: 192);
    });

    expect(image, isNotNull);
    expect(image!.height, 192);
    expect(image.width, lessThan(100));
    image.dispose();
  });

  testWidgets('no photo, a file that is gone, bytes that are no picture and '
      'a record too large all give nothing', (tester) async {
    final store = _MockStore();
    Future<ui.Image?> load() => tester.runAsync<ui.Image?>(
      () => loadOwnLookThumbnail(store, height: 192),
    );

    when(() => store.photo).thenReturn(null);
    expect(await load(), isNull);

    when(() => store.photo).thenReturn(_record(390, 844));
    when(() => store.readPhoto('a')).thenAnswer((_) async => null);
    expect(await load(), isNull);

    when(
      () => store.readPhoto('a'),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    expect(await load(), isNull);

    when(
      () => store.photo,
    ).thenReturn(_record(OwnPhotoLimits.maxSide + 1, 844));
    expect(await load(), isNull);
    verify(() => store.readPhoto('a')).called(2);
  });

  testWidgets('the tile shows the photo once it is ready, and the fallback '
      'until then', (tester) async {
    final store = _MockStore();
    when(() => store.changes).thenAnswer((_) => const Stream.empty());
    when(() => store.photo).thenReturn(_record(39, 84));
    final bytes = await tester.runAsync(() => _png(39, 84));
    when(() => store.readPhoto('a')).thenAnswer((_) async => bytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 44,
            height: 96,
            child: OwnLookThumbnail(
              store: store,
              height: 96,
              fallback: const SizedBox.expand(key: ValueKey('fallback')),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('fallback')), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byKey(const ValueKey('fallback')), findsNothing);
  });
}
