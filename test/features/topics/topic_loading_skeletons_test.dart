import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/components/skeleton.dart';
import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/components/toasts.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/topic_messages_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/messages_page_row.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_message_row.dart';
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
      expect(find.byType(TopicMessageRow), findsNothing);
      await cubit.close();
    });

    testWidgets('shows a message row once messages have loaded', (
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
      expect(find.byType(TopicMessageRow), findsOneWidget);
      expect(find.text('High CPU load'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('shows dots for the numeral while loading', (tester) async {
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

      expect(find.text('···'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('replaces the dots with the real answer once loaded', (
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
      expect(find.text('···'), findsOneWidget);

      cubit.emit(
        const TopicDetailState(
          status: TopicDetailStatus.success,
          topicName: 'prod-db',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('···'), findsNothing);
      // A topic nobody switched on reads Off.
      expect(
        find.descendant(
          of: find.byType(AppStatusCard),
          matching: find.text('Off'),
        ),
        findsOneWidget,
      );
      expect(find.text('Nothing sent yet.'), findsOneWidget);
      await cubit.close();
    });

    testWidgets(
      'shows the newest messages as rows when there are several',
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

        expect(find.byType(TopicMessageRow), findsNWidgets(2));
        expect(find.text('High CPU load'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('messages_12:00_2')),
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
    testWidgets('shows four skeleton rows while loading', (
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

      expect(find.byType(MessagesPageRowSkeleton), findsNWidgets(4));
      await cubit.close();
    });
  });
}
