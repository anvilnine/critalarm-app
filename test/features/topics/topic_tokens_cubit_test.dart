import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A topic with no tokens yet, whose every create attempt is refused. Models
/// the "Get curl line" sheet's first token failing before the server ever
/// hands one back, so the tokens list stays empty.
class _EmptyTopicRefusingCreate implements TopicRepository {
  @override
  Future<AppResult<List<TopicTokenInfo>>> getTopicTokens(String name) async =>
      const <TopicTokenInfo>[].toSuccess();

  @override
  Future<AppResult<TopicToken>> createTopicToken(
    String name, {
    String? tokenName,
  }) async => const Failure.api(statusCode: 500).toFailure();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockServer server;
  late TopicRepository repository;
  late TopicTokensCubit cubit;

  setUp(() {
    server = MockServer()..seedCalm();
    repository = InMemoryTopicRepository(MockApiClient(server));
    cubit = TopicTokensCubit(
      GetTopicTokensUsecase(repository),
      CreateTopicTokenUsecase(repository),
      RevokeTopicTokenUsecase(repository),
      RenameTopicTokenUsecase(repository),
    );
    addTearDown(cubit.close);
  });

  group('TopicTokensCubit', () {
    test('lists the topic it was asked for, ids only', () async {
      await cubit.load('prod-db');

      expect(cubit.state.status, TopicTokensStatus.ready);
      expect(cubit.state.tokens, hasLength(1));
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.newToken, isNull);
      expect(cubit.topicName, 'prod-db');
    });

    test('a topic the server does not have reads as a failure', () async {
      await cubit.load('never-made');

      expect(cubit.state.status, TopicTokensStatus.failure);
      expect(cubit.state.tokens, isEmpty);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('a new token lands in the list and shows its value once', () async {
      await cubit.load('prod-db');
      await cubit.createToken();

      expect(cubit.state.tokens, hasLength(2));
      expect(cubit.state.newToken, startsWith('tk_'));
      expect(cubit.state.isWorking, isFalse);

      cubit.dismissNewToken();
      expect(cubit.state.newToken, isNull);
    });

    test('the last token cannot be revoked', () async {
      await cubit.load('prod-db');

      expect(cubit.state.canRevoke, isFalse);

      await cubit.createToken();
      expect(cubit.state.canRevoke, isTrue);
    });

    test('revoking takes the token off the list', () async {
      await cubit.load('prod-db');
      await cubit.createToken();
      final target = cubit.state.tokens.last.tokenId;

      await cubit.revoke(target);

      expect(cubit.state.tokens.map((t) => t.tokenId), isNot(contains(target)));
      expect(cubit.state.errorMessage, isNull);

      // What the server holds agrees with what is on screen.
      await cubit.load('prod-db');
      expect(cubit.state.tokens.map((t) => t.tokenId), isNot(contains(target)));
    });

    test('a refused revoke puts the token back where it was', () async {
      await cubit.load('prod-db');
      await cubit.createToken();
      final before = cubit.state.tokens.map((t) => t.tokenId).toList();
      expect(before, hasLength(2));

      // Another device revoked the first one. This screen has not heard, so
      // it still shows two and still offers to revoke the second.
      server.deleteTopicToken('prod-db', before[0]);

      // The server refuses: that is its last token now.
      await cubit.revoke(before[1]);

      expect(cubit.state.tokens.map((t) => t.tokenId), before);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.isWorking, isFalse);
    });

    test('a refused revoke says what to do next and keeps the order', () async {
      await cubit.load('prod-db');
      await cubit.createToken();
      await cubit.createToken();
      final before = cubit.state.tokens.map((t) => t.tokenId).toList();
      expect(before, hasLength(3));

      // Another device revoked the two newer ones. This screen still shows
      // three, so it still offers to revoke the first.
      server
        ..deleteTopicToken('prod-db', before[1])
        ..deleteTopicToken('prod-db', before[2]);

      // The server answers 409 topic must retain a token.
      await cubit.revoke(before[0]);

      // Back at the front of the list, not appended to the end.
      expect(cubit.state.tokens.map((t) => t.tokenId), before);
      expect(
        cubit.state.errorMessage,
        'A topic keeps at least one token. '
        'Make a new token first, then revoke this one.',
      );
      expect(cubit.state.isWorking, isFalse);
    });

    test('renaming puts the new name on the list', () async {
      await cubit.load('prod-db');
      final target = cubit.state.tokens.first.tokenId;

      await cubit.rename(target, 'CI server');

      expect(cubit.state.tokens.first.name, 'CI server');
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isWorking, isFalse);

      // What the server holds agrees with what is on screen.
      await cubit.load('prod-db');
      expect(cubit.state.tokens.first.name, 'CI server');
    });

    test('a refused rename keeps the old name and says why', () async {
      await cubit.load('prod-db');
      final target = cubit.state.tokens.first.tokenId;
      final before = cubit.state.tokens.first.name;

      // Another device revoked it. This screen has not heard, so it still
      // offers to rename a token the server no longer has.
      server
        ..createTopicToken('prod-db')
        ..deleteTopicToken('prod-db', target);

      await cubit.rename(target, 'CI server');

      expect(cubit.state.tokens.first.name, before);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.isWorking, isFalse);
    });

    test('renaming a token the list never held does nothing', () async {
      await cubit.load('prod-db');
      final before = cubit.state;

      await cubit.rename('tok_not_here', 'CI server');

      expect(cubit.state, before);
    });

    test('revoking a token the list never held does nothing', () async {
      await cubit.load('prod-db');
      final before = cubit.state;

      await cubit.revoke('tok_not_here');

      expect(cubit.state, before);
    });

    test(
      'a refused first token sets an error without reading as a load '
      'failure, so a widget keyed on errorMessage alone still shows it',
      () async {
        final refusing = TopicTokensCubit(
          GetTopicTokensUsecase(_EmptyTopicRefusingCreate()),
          CreateTopicTokenUsecase(_EmptyTopicRefusingCreate()),
          RevokeTopicTokenUsecase(_EmptyTopicRefusingCreate()),
          RenameTopicTokenUsecase(_EmptyTopicRefusingCreate()),
        );
        addTearDown(refusing.close);

        await refusing.load('new-topic');
        expect(refusing.state.status, TopicTokensStatus.ready);
        expect(refusing.state.tokens, isEmpty);

        await refusing.createToken(name: 'Script');

        expect(refusing.state.tokens, isEmpty);
        expect(refusing.state.errorMessage, isNotNull);
        // The load-failure branch is the only other place the section widget
        // checks status: this must stay something else, or the widget's
        // separate `status == failure && tokens.isEmpty` branch would need
        // its own fix too.
        expect(refusing.state.status, isNot(TopicTokensStatus.failure));
      },
    );

    test('createNamedToken hands back null on a refusal', () async {
      final refusing = TopicTokensCubit(
        GetTopicTokensUsecase(_EmptyTopicRefusingCreate()),
        CreateTopicTokenUsecase(_EmptyTopicRefusingCreate()),
        RevokeTopicTokenUsecase(_EmptyTopicRefusingCreate()),
        RenameTopicTokenUsecase(_EmptyTopicRefusingCreate()),
      );
      addTearDown(refusing.close);

      await refusing.load('new-topic');
      final made = await refusing.createNamedToken('Script');

      expect(made, isNull);
    });
  });
}
