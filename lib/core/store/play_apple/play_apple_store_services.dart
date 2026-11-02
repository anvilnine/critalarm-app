import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/platform/store_kind.dart';
import 'package:critalarm/core/push/apns_push_token_provider.dart';
import 'package:critalarm/core/push/firebase_push_token_provider.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:critalarm/core/store/play_apple/in_app_review_store.dart';
import 'package:critalarm/core/store/play_apple/native_google_sign_in_sheet.dart';
import 'package:critalarm/core/store/play_apple/play_apple_sign_in_options.dart';
import 'package:critalarm/core/store/play_apple/revenuecat_billing.dart';
import 'package:critalarm/core/store/play_apple/revenuecat_customer_center.dart';
import 'package:critalarm/core/store/services/google_sign_in_sheet.dart';
import 'package:critalarm/core/store/services/manage_subscription.dart';
import 'package:critalarm/core/store/services/sign_in_options.dart';
import 'package:critalarm/core/store/services/sound_pack_source.dart';
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/store/services/store_links.dart';
import 'package:critalarm/core/store/services/store_review.dart';
import 'package:critalarm/core/store/services/store_services.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

/// The [StoreServices] of a Google Play or App Store build: RevenueCat for
/// billing, its Customer Center, `in_app_review`, the native Google sheet,
/// APNs on iOS and FCM elsewhere, and the sound pack channel.
///
/// Each part is made the first time it is asked for, so building the set
/// touches no plugin.
final class PlayAppleStoreServices implements StoreServices {
  PlayAppleStoreServices({
    required this.store,
    required this._capabilities,
    required this._pushHost,
    required this._appStoreId,
  });

  @override
  final StoreKind store;
  final PlatformCapabilities _capabilities;
  final PushHost Function() _pushHost;

  /// The App Store's numeric id for the app, for the listing link. Blank
  /// until the listing has one.
  final String _appStoreId;

  /// api.md §5.1 has the relay pushing to APNs itself, so iOS registers the
  /// raw APNs token. Android registers the FCM one (§5.2).
  @override
  late final PushTokenProvider pushTokens =
      _capabilities.platform == TargetPlatform.iOS
      ? ApnsPushTokenProvider(_pushHost())
      : FirebasePushTokenProvider();

  /// The same object as [billing], typed so `lib/app/di.dart` can set it up
  /// with the store key.
  late final RevenueCatBilling revenueCat = RevenueCatBilling();

  @override
  StoreBilling get billing => revenueCat;

  @override
  late final ManageSubscription manageSubscription =
      const RevenueCatCustomerCenter();

  @override
  late final SignInOptions signInOptions = PlayAppleSignInOptions(
    _capabilities,
  );

  @override
  late final GoogleSignInSheet googleSignIn = NativeGoogleSignInSheet(
    platform: _capabilities.platform,
  );

  @override
  late final StoreReview review = InAppStoreReview();

  @override
  late final StoreLinks links = InAppStoreLinks(appStoreId: _appStoreId);

  @override
  late final SoundPackSource soundPacks = SoundPackHost();
}
