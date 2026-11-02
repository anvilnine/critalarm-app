import 'package:critalarm/app/state/held_rows.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:get_it/get_it.dart';

/// The history cubit.
void registerHistory(GetIt getIt, {required LocalStore? localStore}) {
  getIt.registerFactory(
    () => HistoryCubit(
      getIt<IncidentsCubit>(),
      identityStore: getIt<DeviceIdentityStore>(),
      featureAccess: getIt<FeatureAccess>(),
      store: localStore,
      held: getIt<HeldRows>(),
    ),
  );
}
