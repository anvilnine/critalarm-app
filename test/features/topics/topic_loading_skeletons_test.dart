import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/components/message_cards.dart';
import 'package:critalarm/design/components/skeleton.dart';
import 'package:critalarm/design/components/toasts.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/topic_messages_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_tokens_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  setUp(() {
    getIt<MockServer>().seedCalm();
  });

  TopicDetailCubit makeDetailCubit() {
    return TopicDetailCubit(
      getIt<IncidentsCubit>(),
      getIt<TopicsCubit>(),
      getIt<UpdateTopicUsecase>(),
      getIt<IncidentRepository>(),
    );
  }

  group('TopicTokensSection loading state', () {
    testWidgets(
      'shows AppTokensSectionSkeleton when loading and tokens are empty',
      (
        tester,
      ) async {
        final cubit = getIt<TopicTokensCubit>()
          ..emit(const TopicTokensState(status: TopicTokensStatus.loading));

        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TopicTokensSection(
                  topicName: 'prod-db',
                  cubit: cubit,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AppTokensSectionSkeleton), findsOneWidget);
        expect(find.byType(AppTokenRowSkeleton), findsNWidgets(2));
        expect(find.byType(AppButtonSkeleton), findsOneWidget);
      },
    );

    testWidgets('swaps skeleton for token rows once tokens load', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: TopicTokensSection(topicName: 'prod-db'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(AppTokensSectionSkeleton), findsNothing);
      expect(find.text('Token 1'), findsOneWidget);
    });

    testWidgets('animates new token banner on creation and dismissal', (
      tester,
    ) async {
      final cubit = getIt<TopicTokensCubit>()
        ..emit(
          const TopicTokensState(
            status: TopicTokensStatus.ready,
            newToken: 'secret-token-xyz',
            newTokenName: 'api-key',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TopicTokensSection(
                topicName: 'prod-db',
                cubit: cubit,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('secret-token-xyz'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('new_token_secret-token-xyz')),
        findsOneWidget,
      );

      cubit.dismissNewToken();
      await tester.pumpAndSettle();

      expect(find.text('secret-token-xyz'), findsNothing);
    });
  });

  group('TopicDetailScreen messages loading skeleton', () {
    testWidgets('shows AppMessageCardSkeleton under MESSAGES when loading', (
      tester,
    ) async {
      final cubit = makeDetailCubit()
        ..emit(
          const TopicDetailState(
            status: TopicDetailStatus.loading,
            topicName: 'prod-db',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: TopicDetailScreen(
            topicName: 'prod-db',
            isPane: true,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppMessageCardSkeleton), findsOneWidget);
      expect(find.byType(AppMessageCard), findsNothing);
      await cubit.close();
    });

    testWidgets('shows AppMessageCard once messages have loaded', (
      tester,
    ) async {
      final cubit = makeDetailCubit()
        ..emit(
          const TopicDetailState(
            status: TopicDetailStatus.success,
            topicName: 'prod-db',
            messages: [
              TopicDetailMessageItem(
                title: 'High CPU load',
                timestamp: '12:00',
                body: 'CPU reached 98%',
                source: 'cpu',
              ),
            ],
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: TopicDetailScreen(
            topicName: 'prod-db',
            isPane: true,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppMessageCardSkeleton), findsNothing);
      expect(find.byType(AppMessageCard), findsOneWidget);
      expect(find.text('High CPU load'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('shows stage skeleton bones when loading', (tester) async {
      final cubit = makeDetailCubit()
        ..emit(
          const TopicDetailState(
            status: TopicDetailStatus.loading,
            topicName: 'prod-db',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: TopicDetailScreen(
            topicName: 'prod-db',
            isPane: true,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('stage_vertical_skeleton')),
        findsOneWidget,
      );
      await cubit.close();
    });

    testWidgets('transitions stage skeleton to loaded content', (tester) async {
      final cubit = makeDetailCubit()
        ..emit(
          const TopicDetailState(
            status: TopicDetailStatus.loading,
            topicName: 'prod-db',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: TopicDetailScreen(
            topicName: 'prod-db',
            isPane: true,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('stage_vertical_skeleton')),
        findsOneWidget,
      );

      cubit.emit(
        const TopicDetailState(
          status: TopicDetailStatus.success,
          topicName: 'prod-db',
          word: 'CLEAR',
          subText: '0 open incidents',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey('stage_vertical_skeleton')),
        findsNothing,
      );
      expect(find.text('CLEAR'), findsOneWidget);
      expect(find.text('0 open incidents'), findsOneWidget);
      await cubit.close();
    });

    testWidgets(
      'shows View all messages button alongside message card when multiple '
      'messages',
      (tester) async {
        final cubit = makeDetailCubit()
          ..emit(
            const TopicDetailState(
              status: TopicDetailStatus.success,
              topicName: 'prod-db',
              messages: [
                TopicDetailMessageItem(
                  title: 'High CPU load',
                  timestamp: '12:00',
                  body: 'CPU reached 98%',
                  source: 'cpu',
                ),
                TopicDetailMessageItem(
                  title: 'Disk space warning',
                  timestamp: '11:50',
                  body: 'Disk at 89%',
                  source: 'disk',
                ),
              ],
            ),
          );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            home: TopicDetailScreen(
              topicName: 'prod-db',
              isPane: true,
              cubit: cubit,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AppMessageCard), findsOneWidget);
        expect(find.text('High CPU load'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('messages_card_12:00_1')),
          findsOneWidget,
        );
        await cubit.close();
      },
    );

    testWidgets('animates error toast when errorMessage is set', (
      tester,
    ) async {
      final cubit = makeDetailCubit()
        ..emit(
          const TopicDetailState(
            status: TopicDetailStatus.failure,
            topicName: 'prod-db',
            errorMessage: 'Server not reachable',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: TopicDetailScreen(
            topicName: 'prod-db',
            isPane: true,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppToast), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sheet_error_Server not reachable')),
        findsOneWidget,
      );
      await cubit.close();
    });
  });

  group('TopicMessagesScreen loading skeleton', () {
    testWidgets('shows 3 AppMessageCardSkeleton cards while loading', (
      tester,
    ) async {
      final cubit = makeDetailCubit()
        ..emit(
          const TopicDetailState(
            status: TopicDetailStatus.loading,
            topicName: 'prod-db',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: TopicMessagesScreen(
            topicName: 'prod-db',
            cubit: cubit,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppMessageCardSkeleton), findsNWidgets(3));
      await cubit.close();
    });
  });
}
