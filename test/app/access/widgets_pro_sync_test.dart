import 'dart:convert';

import 'package:critalarm/app/access/pro_holding_source.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/access/access_fakes.dart';
import '../../features/pro_pack/pro_pack_fakes.dart';

class _Topics implements TopicRepository {
  @override
  Future<AppResult<List<Topic>>> getTopics() async =>
      const [Topic(name: 'prod')].toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Incidents implements IncidentRepository {
  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async => <Incident>[].toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Widgets follow the Pro pack alone. This wires `WidgetSync` the way
/// `di.dart` does (the lock from the widgets decision, a rewrite on every
/// change of it) over the real Pro source, and moves the pack with the
/// developer switch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WidgetHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Map<String, dynamic>> writes;
  late ValueNotifier<bool> devSwitch;
  late FakeHoldingSource hosted;
  late FeatureAccess access;
  late WidgetSync sync;
  late TopicsCubit topics;
  late IncidentsCubit incidents;

  Future<void> build({required ServerMode mode}) async {
    writes = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'write') {
        final args = call.arguments as Map<Object?, Object?>;
        writes.add(
          jsonDecode(args['json']! as String) as Map<String, dynamic>,
        );
      }
      return null;
    });
    devSwitch = ValueNotifier(false);
    final packs = ProPackAccess(
      api: FakePacksApi(),
      store: MemoryProPackStore(),
      readAccountId: () async => 'acc_1',
      override: DevProPackOverride()..watch(devSwitch),
      now: () => DateTime.utc(2026, 10, 8, 9),
    );
    addTearDown(packs.dispose);
    await packs.ready;
    hosted = FakeHoldingSource(Holding.hosted);
    final holdings = Holdings([hosted, ProHoldingSource(packs)]);
    addTearDown(holdings.dispose);
    access = FeatureAccess(holdings: holdings, serverMode: mode);
    addTearDown(access.dispose);

    final identity = AccountIdentityChanges();
    topics = TopicsCubit(
      GetTopicsUsecase(_Topics()),
      identityChanges: identity,
    );
    incidents = IncidentsCubit(
      GetIncidentsUsecase(_Incidents()),
      identityChanges: identity,
    );
    sync = WidgetSync(
      topics: topics,
      incidents: incidents,
      host: WidgetHost(),
      isConnected: () async => true,
      isLocked: () async => !await access.canOnceReady(AppFeature.widgets),
      debounce: Duration.zero,
    )..start();
    access.changes
        .where((feature) => feature == AppFeature.widgets)
        .listen((_) => sync.rewrite());
    await topics.refresh();
    await incidents.refresh();
    await _settle();
  }

  tearDown(() async {
    await sync.dispose();
    await topics.close();
    await incidents.close();
    messenger.setMockMethodCallHandler(channel, null);
  });

  for (final mode in [ServerMode.hosted, ServerMode.selfhosted]) {
    group('on ${mode.name}', () {
      test('widgets start locked with nothing held', () async {
        await build(mode: mode);
        expect(writes.last['locked'], isTrue);
        expect(writes.last['topics'], isEmpty);
      });

      test('Pro on fills them in without another app launch, Pro off '
          'locks them again', () async {
        await build(mode: mode);
        expect(writes.last['locked'], isTrue);

        devSwitch.value = true;
        await _settle();
        expect(writes.last['locked'], isNot(true));
        final shown = (writes.last['topics'] as List)
            .cast<Map<String, dynamic>>();
        expect(shown.single['name'], 'prod');

        devSwitch.value = false;
        await _settle();
        expect(writes.last['locked'], isTrue);
        expect(writes.last['topics'], isEmpty);
      });

      test('Hosted alone leaves them locked', () async {
        await build(mode: mode);
        hosted.set(HoldingState.held);
        await _settle();
        expect(writes.last['locked'], isTrue);
        expect(sync.lastWrittenLocked, isTrue);
      });
    });
  }
}
