import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/feedback/presentation/help_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_translations.dart';

void main() {
  setUpAll(loadTestTranslations);

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<PlatformCapabilities>(
      const PlatformCapabilities(isWeb: false, platform: TargetPlatform.iOS),
    );
  });
  tearDown(getIt.reset);

  testWidgets('Docs is the first row under Help', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const Scaffold(body: SingleChildScrollView(child: HelpSection())),
      ),
    );

    final docs = find.text('Docs');
    expect(docs, findsOneWidget);
    expect(find.text('How to set up and send alerts'), findsOneWidget);
    final report = find.text('Report a problem');
    expect(
      tester.getTopLeft(docs).dy,
      lessThan(tester.getTopLeft(report).dy),
    );
    // Nothing sits between the header and Docs.
    expect(
      tester.getTopLeft(find.text('Help')).dy,
      lessThan(tester.getTopLeft(docs).dy),
    );
  });
}
