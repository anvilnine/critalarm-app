import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_tokens_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const note =
      'A topic keeps at least one token. To replace this one, make a new '
      'token first, then revoke this one.';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  setUp(() {
    getIt<MockServer>().seedCalm();
  });

  Widget buildTestApp() {
    return MaterialApp(
      theme: buildLightTheme(),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: TopicTokensSection(topicName: 'prod-db'),
        ),
      ),
    );
  }

  group('TopicTokensSection', () {
    testWidgets('one token says why there is nothing to revoke', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text(note), findsOneWidget);
      expect(find.bySemanticsLabel('Revoke this token'), findsNothing);
    });

    testWidgets('two tokens drop the note, the revoke control is there', (
      tester,
    ) async {
      getIt<MockServer>().createTopicToken('prod-db');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text(note), findsNothing);
      expect(find.bySemanticsLabel('Revoke this token'), findsNWidgets(2));
    });
  });
}
