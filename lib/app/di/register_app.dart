import 'package:critalarm/app/challenge_flag_sync.dart';
import 'package:critalarm/app/held_account_scope.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/app/state/held_rows.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/repositories/held_archive.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/delete_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_glances.dart';
import 'package:get_it/get_it.dart';

/// The two app-level lists, the rows held at launch and the alarm focus.
void registerSharedLists(
  GetIt getIt, {
  required LocalStore? localStore,
  required HeldAccountScope heldScope,
}) {
  // The two app-level cubits. Singletons, not factories: every screen has
  // to read and listen to the same instance or there is no shared state.
  getIt
    ..registerLazySingleton(
      () => IncidentsCubit(
        getIt<GetIncidentsUsecase>(),
        badge: getIt<AppBadge>(),
        saveIncident: getIt<IncidentRepository>().saveIncident,
      ),
    )
    ..registerLazySingleton(
      () => TopicsCubit(
        getIt<GetTopicsUsecase>(),
        deleteTopic: getIt<DeleteTopicUsecase>(),
        incidents: getIt<IncidentsCubit>(),
        // A deleted topic takes its wake-up challenge and its flag along,
        // and the look it had picked for its alarm screen.
        onDeleted: (name) async {
          await getIt<ChallengeChoices>().forgetTopic(name);
          await getIt<ChallengeFlagSync>().check();
          await getIt<AlarmStyleChoices>().forgetTopic(name);
        },
        // The list is kept on the phone for the server and account it is on
        // now. Where the store is not open the list stays in memory only.
        held: localStore?.topics,
        heldScope: heldScope.call,
      ),
    )
    // The alarms and messages the phone held at launch, for the screens that
    // open before the server has answered. Read by `main` after the topic
    // list. Not the shared list: nothing that rings reads it.
    ..registerLazySingleton(
      () => HeldRows(
        getIt<HeldArchive>(),
        getIt<TopicsCubit>(),
        getIt<IncidentsCubit>(),
        glances: getIt<TopicGlances>(),
        // Answers from what is already read, and never waits on the plan: a
        // launch that does not know it yet draws no copy.
        readPlan: () => heldPlanFrom(
          access: getIt<FeatureAccess>(),
          identities: getIt<DeviceIdentityStore>(),
        ),
      ),
    )
    // "Is an alarm under way on this phone", read off the shared list. Every
    // guard that keeps sheets, notices and navigation away from an alarm
    // asks this one object.
    ..registerLazySingleton(
      () => AlarmFocus(
        incidents: getIt<IncidentsCubit>().stream.map((s) => s.incidents),
        current: () => getIt<IncidentsCubit>().state.incidents,
        maxRingSeconds: (topic) =>
            getIt<TopicsCubit>().state.named(topic)?.maxRingS,
        host: getIt<AlarmHost>(),
      ),
    );
}

/// The home and lock screen widget snapshot.
void registerWidgetSync(GetIt getIt) {
  // The home and lock screen widgets read a snapshot of the two lists
  // above. This writes it whenever either list changes.
  getIt.registerLazySingleton(() {
    final sync = WidgetSync(
      topics: getIt<TopicsCubit>(),
      incidents: getIt<IncidentsCubit>(),
      host: getIt<WidgetHost>(),
      isConnected: () async =>
          (await getIt<ConnectionRepository>().getConnection()).isSuccess(),
      // The lock is drawn by the widget itself, outside the app, and a
      // wrong one takes the widgets away. So this waits until the plan
      // and the saved server have been read before it answers.
      isLocked: () async =>
          !await getIt<FeatureAccess>().canOnceReady(AppFeature.widgets),
    );
    // The lock follows the widgets decision: a purchase, a plan that
    // ended, a server that became known. Neither list changes then, so
    // this is what writes the snapshot again.
    getIt<FeatureAccess>().changes
        .where((feature) => feature == AppFeature.widgets)
        .listen((_) => sync.rewrite());
    return sync;
  });
}

/// The shell cubit.
void registerShell(GetIt getIt) {
  getIt.registerFactory(
    () => ShellCubit(
      getIt<GetDevicePermissionsUsecase>(),
    ),
  );
}
