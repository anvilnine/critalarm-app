import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's own Hosted source over a test's identity store, wired the way
/// `di.dart` wires it: the tier is read from [identity], and read again on
/// every write to it and every plan change.
///
/// For a test that moves the stored tier, the store flag or the developer
/// switch and checks what a screen does. Starts on Crit Alarm Cloud. Torn
/// down with the test.
({Holdings holdings, FeatureAccess features}) accessOver(
  DeviceIdentityStore identity, {
  PlanChanges? planChanges,
  ProOverride? proOverride,
  ServerMode? serverMode = ServerMode.hosted,
}) {
  final source = HostedHoldingSource(
    readIdentity: identity.readOrCreate,
    planChanges: planChanges ?? PlanChanges(),
    proOverride: proOverride ?? const NoProOverride(),
    identityChanges: [identity.changes],
  );
  final holdings = Holdings([source]);
  final features = FeatureAccess(holdings: holdings, serverMode: serverMode);
  addTearDown(() async {
    await features.dispose();
    await holdings.dispose();
    source.dispose();
  });
  return (holdings: holdings, features: features);
}
