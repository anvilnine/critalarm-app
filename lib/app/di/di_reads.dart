import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:get_it/get_it.dart';

/// Whether this install holds Hosted, asked once the sources are current.
/// For the readers that ask once and do not listen: the reminder inputs,
/// the onboarding offer, the Pro badge and the buy flow.
Future<bool> Function() holdsHostedReader(GetIt getIt) =>
    () => getIt<Holdings>().holdsOnceReady(Holding.hosted);

/// Whether the server's own tier says Hosted, leaving out the store and the
/// developer switch: the Hosted source's named read, for the two callers
/// that report what the server did.
Future<bool> Function() hostedByServerReader(GetIt getIt) => () {
  final hosted = getIt<HostedHoldingSource>();
  return hosted.readHeldByServer(); // access-ok: the named read, passed on
};

/// What the access layer says for the weekly check, in the words the
/// weekly check acts on.
WeeklyCheckAccess Function() weeklyCheckAccessReader(GetIt getIt) =>
    () => weeklyCheckAccessFor(
      getIt<FeatureAccess>().decide(AppFeature.weeklyCheck),
    );
