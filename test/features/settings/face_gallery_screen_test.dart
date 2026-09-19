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

    // Verify section headers
    expect(find.text('NEW EXPRESSIONS'), findsOneWidget);
    expect(find.text('CLASSIC APP FACES'), findsOneWidget);

    // Verify expression labels
    expect(find.text('Shocked'), findsWidgets);
    expect(find.text('Laughing'), findsWidgets);
    expect(find.text('Surprised'), findsWidgets);
    expect(find.text('Skeptical'), findsWidgets);
    expect(find.text('Dizzy'), findsWidgets);
    expect(find.text('Determined'), findsWidgets);
    expect(find.text('Confused'), findsWidgets);
    expect(find.text('Sad'), findsWidgets);

    // Tap on a face card to select it
    await tester.tap(find.text('Shocked').first);
    await tester.pump();

    // Verify code snippet updates
    expect(
      find.text('FaceWidget(state: FaceState.shocked)'),
      findsOneWidget,
    );
  });
}
