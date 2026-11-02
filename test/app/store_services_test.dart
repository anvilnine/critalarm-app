import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/platform/store_kind.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/store/play_apple/play_apple_sign_in_options.dart';
import 'package:critalarm/core/store/play_apple/play_apple_store_services.dart';
import 'package:critalarm/core/store/play_apple/revenuecat_billing.dart';
import 'package:critalarm/core/store/play_apple/revenuecat_customer_center.dart';
import 'package:critalarm/core/store/services/sign_in_options.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

PushHost _noPushHost() => throw StateError('no push host in this test');

void main() {
  const android = PlatformCapabilities(
    isWeb: false,
    platform: TargetPlatform.android,
  );
  const iphone = PlatformCapabilities(
    isWeb: false,
    platform: TargetPlatform.iOS,
  );

  group('storeServicesFor', () {
    test('Google Play gets the Play and App Store set', () {
      final services = storeServicesFor(
        StoreKind.play,
        capabilities: android,
        pushHost: _noPushHost,
      );
      expect(services, isA<PlayAppleStoreServices>());
      expect(services.store, StoreKind.play);
      expect(services.billing, isA<RevenueCatBilling>());
      expect(services.manageSubscription, isA<RevenueCatCustomerCenter>());
      expect(services.signInOptions, isA<PlayAppleSignInOptions>());
    });

    test('the App Store gets the Play and App Store set', () {
      final services = storeServicesFor(
        StoreKind.apple,
        capabilities: iphone,
        pushHost: _noPushHost,
      );
      expect(services, isA<PlayAppleStoreServices>());
      expect(services.store, StoreKind.apple);
      expect(services.billing, isA<RevenueCatBilling>());
      expect(services.manageSubscription, isA<RevenueCatCustomerCenter>());
    });

    // No store of their own yet: they run the code the Play build runs.
    for (final store in [StoreKind.galaxy, StoreKind.huawei]) {
      test('${store.name} runs the Play set until it has its own', () {
        final services = storeServicesFor(
          store,
          capabilities: android,
          pushHost: _noPushHost,
        );
        expect(services, isA<PlayAppleStoreServices>());
        expect(services.store, store);
      });
    }

    test('the billing part is the same object on every ask', () {
      final services = storeServicesFor(
        StoreKind.play,
        capabilities: android,
        pushHost: _noPushHost,
      );
      expect(identical(services.billing, services.billing), isTrue);
      expect(
        identical(
          services.billing,
          (services as PlayAppleStoreServices).revenueCat,
        ),
        isTrue,
      );
    });
  });

  group('sign-in providers on Play and the App Store', () {
    test('the iPhone app shows Apple, then Google', () {
      expect(const PlayAppleSignInOptions(iphone).providers, [
        SignInProvider.apple,
        SignInProvider.google,
      ]);
    });

    test('Android shows Google alone', () {
      expect(const PlayAppleSignInOptions(android).providers, [
        SignInProvider.google,
      ]);
    });

    test('the web build shows Google alone, on an iPhone too', () {
      const web = PlatformCapabilities(
        isWeb: true,
        platform: TargetPlatform.iOS,
      );
      expect(const PlayAppleSignInOptions(web).providers, [
        SignInProvider.google,
      ]);
    });

    test('the sign-in sheets offer what the options list', () {
      final sheets = NativeProviderSignIn(
        options: const FixedSignInOptions([SignInProvider.google]),
        google: storeServicesFor(
          StoreKind.play,
          capabilities: android,
          pushHost: _noPushHost,
        ).googleSignIn,
      );
      expect(sheets.supports(IdentityProvider.google), isTrue);
      expect(sheets.supports(IdentityProvider.apple), isFalse);
    });
  });
}
