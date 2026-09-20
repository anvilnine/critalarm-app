import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/face_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FaceGalleryScreen renders title and expressions grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [AppColors.light],
        ),
        home: const FaceGalleryScreen(),
      ),
    );
    await tester.pump();

    // Verify top bar title
    expect(find.text('Face expressions'), findsOneWidget);

    // The first headers are on screen. The rest of the list is built as it
    // is scrolled, so those are reached by scrolling to them.
    expect(find.text('APP FACES'), findsOneWidget);
    expect(find.text('CORE'), findsOneWidget);

    for (final title in const [
      'THINKING',
      'TIRED AND RESTING',
      'BIG FEELINGS',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(title), findsOneWidget, reason: title);
    }

    // A face from the sheets, and one that has been in the app all along.
    for (final label in const ['Yawn', 'Dozing', 'Shocked']) {
      await tester.scrollUntilVisible(
        find.text(label),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsWidgets, reason: label);
    }

    // Tapping a card selects it, and the snippet up at the top follows.
    await tester.tap(find.text('Shocked').first);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('FaceWidget(state: FaceState.shocked)'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('FaceWidget(state: FaceState.shocked)'),
      findsOneWidget,
    );
  });
}
