import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/app/access/sure_lock.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/app_icon/app_icon_guard.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/paywall/presentation/cubits/pro_status_cubit.dart';
import 'package:critalarm/features/search/presentation/cubits/search_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two managers are lazy singletons, and the gates are the first code to
/// build them. This builds the app's real composition root and resolves
/// them and everything that reads them, so a cycle or a missing
/// registration fails here and not on a phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    await configureDependencies(useMockApi: true);
  });

  tearDown(() => getIt.reset());

  test('the managers and their sources build and answer', () async {
    final holdings = getIt<Holdings>();
    final access = getIt<FeatureAccess>();
    expect(getIt<HostedHoldingSource>(), isNotNull);
    expect(getIt<SureLock>(), isNotNull);

    await access.ready;
    // A fresh install: nothing held, connected to nothing.
    expect(holdings.held, isEmpty);
    expect(access.serverMode, isNull);
    for (final feature in AppFeature.values) {
      expect(access.decide(feature), isA<FeatureLocked>(), reason: '$feature');
    }
    expect(await holdings.holdsOnceReady(Holding.hosted), isFalse);
    // Connected to nothing, so nothing is taken away.
    expect(await getIt<SureLock>().isLocked(AppFeature.appIcons), isFalse);
  });

  test('everything that reads them resolves', () async {
    expect(getIt<AccountRepository>(), isNotNull);
    expect(await getIt<AccountRepository>().readHoldsHosted(), isFalse);
    expect(getIt<AppIconGuard>(), isNotNull);
    expect(getIt<WidgetSync>(), isNotNull);
    expect(getIt<ProEnding>(), isNotNull);

    final cubits = [
      getIt<SettingsCubit>(),
      getIt<HistoryCubit>(),
      getIt<SearchCubit>(),
      getIt<CreateTopicCubit>(),
      getIt<TopicDetailCubit>(),
      getIt<ProStatusCubit>(),
    ];
    for (final cubit in cubits) {
      await cubit.close();
    }
  });
}
