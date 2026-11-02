import 'dart:async';
import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/app/di/di_reads.dart';
import 'package:critalarm/app/state/critical_topic_count.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/env/env.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/telemetry/paywall_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/ui_sound/interface_sounds_setting.dart';
import 'package:critalarm/core/ui_sound/intro_sound_flavour.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/core/ui_sound/playing_paywall_cues.dart';
import 'package:critalarm/core/ui_sound/ui_sound_host.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/paywall/data/asset_price_book.dart';
import 'package:critalarm/features/paywall/data/history_own_reader.dart';
import 'package:critalarm/features/paywall/data/leaving_facts_reader.dart';
import 'package:critalarm/features/paywall/data/repositories/dev_subscription_repository.dart';
import 'package:critalarm/features/paywall/data/repositories/revenuecat_subscription_repository.dart';
import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_customer_info_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/pro_status_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hosted_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/pro_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_it/get_it.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show CustomerInfo;
import 'package:shared_preferences/shared_preferences.dart';

/// The developer paywall layout switches.
void registerDevPaywallLayoutSwitches(
  GetIt getIt, {
  required SharedPreferences prefs,
}) {
  if (buildHasPaywallLayoutSwitch) {
    // What each product's paywall opens, set in Developer options. A store
    // build compiles appPaywallLayoutOverride as a NoPaywallLayoutOverride,
    // registers nothing here and opens the coded defaults.
    if (!getIt.isRegistered<DevPaywallLayoutSwitches>()) {
      getIt.registerSingleton<DevPaywallLayoutSwitches>(
        DevPaywallLayoutSwitches(
          hosted: DevPaywallLayoutSwitch(
            prefs,
            DevPaywallLayoutSwitch.hostedKey,
          ),
          pro: DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.proKey),
          hostedIntro: DevPaywallIntroSwitch(
            prefs,
            DevPaywallIntroSwitch.hostedKey,
          ),
          proIntro: DevPaywallIntroSwitch(prefs, DevPaywallIntroSwitch.proKey),
          hostedThanks: DevPaywallThanksSwitch(
            prefs,
            DevPaywallThanksSwitch.hostedKey,
          ),
          proThanks: DevPaywallThanksSwitch(
            prefs,
            DevPaywallThanksSwitch.proKey,
          ),
          hostedOutro: DevPaywallOutroSwitch(
            prefs,
            DevPaywallOutroSwitch.hostedKey,
          ),
          proOutro: DevPaywallOutroSwitch(prefs, DevPaywallOutroSwitch.proKey),
        ),
      );
    }
    // Which flavour the intro scores play in. A store build has no switch
    // and plays the first.
    if (!getIt.isRegistered<DevIntroSoundSwitch>()) {
      getIt.registerSingleton<DevIntroSoundSwitch>(DevIntroSoundSwitch(prefs));
    }
    final layoutSwitches = getIt<DevPaywallLayoutSwitches>();
    appPaywallLayoutOverride.watch(
      hosted: layoutSwitches.hosted,
      pro: layoutSwitches.pro,
      hostedIntro: layoutSwitches.hostedIntro,
      proIntro: layoutSwitches.proIntro,
      hostedThanks: layoutSwitches.hostedThanks,
      proThanks: layoutSwitches.proThanks,
      hostedOutro: layoutSwitches.hostedOutro,
      proOutro: layoutSwitches.proOutro,
    );
  }
}

/// The RevenueCat service, started with the saved account.
Future<void> registerRevenueCat(
  GetIt getIt, {
  required DeviceIdentityStore identityStore,
}) async {
  if (!getIt.isRegistered<RevenueCatService>()) {
    final revenueCatService = RevenueCatService();
    // RevenueCat issues a public SDK key per store and the SDK rejects the
    // other store's key, so the platform picks which one is passed.
    final sellsThroughAppStore =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final revenueCatKey = sellsThroughAppStore
        ? Env.revenueCatIosApiKey
        : Env.revenueCatAndroidApiKey;
    // Thrown above the catch below on purpose. A build that cannot sell has to
    // stop here, not be swallowed and look like a build nobody bought from.
    if (releaseBuildCannotSell(
      isRelease: kReleaseMode,
      skipsPaywall: buildSkipsPaywall,
      apiKey: revenueCatKey,
    )) {
      final varName = sellsThroughAppStore
          ? 'REVENUECAT_IOS_API_KEY'
          : 'REVENUECAT_ANDROID_API_KEY';
      throw StateError(
        'This release build has no RevenueCat key, so it cannot sell '
        'anything. Put $varName in .env. The key comes from RevenueCat, '
        'Project settings > API keys. Build with '
        '--dart-define=SKIP_PAYWALL=true if you meant to leave the paywall '
        'out.',
      );
    }
    try {
      if (!buildSkipsPaywall && revenueCatKey.isNotEmpty) {
        await revenueCatService.initialize(
          apiKey: revenueCatKey,
          appUserId: (await identityStore.readOrCreate()).accountId,
        );
        // The store knows about a purchase before our server does. Mirror its
        // Pro entitlement so the app turns Pro the moment the buyer pays.
        revenueCatService.customerInfoStream.listen(_mirrorStorePro);
        unawaited(
          revenueCatService.getCustomerInfo().then(
            _mirrorStorePro,
            onError: (Object _) {},
          ),
        );
      }
    } on Object catch (_) {
      // Ignored for tests or unsupported environments
    }
    getIt.registerSingleton<RevenueCatService>(revenueCatService);
  }
}

/// The prices a paywall shows when the store sends none.
Future<void> registerPriceBook(GetIt getIt) async {
  if (!getIt.isRegistered<PriceBook>()) {
    final priceBook = await AssetPriceBook.load(rootBundle);
    PriceBookInUse.current = priceBook;
    getIt.registerSingleton<PriceBook>(priceBook);
  }
}

/// The subscription repository.
void registerSubscriptionRepository(GetIt getIt) {
  getIt.registerLazySingleton<SubscriptionRepository>(
    () => buildSkipsPaywall
        ? DevSubscriptionRepository(getIt<DevProSwitch>())
        : RevenueCatSubscriptionRepository(getIt<RevenueCatService>()),
  );
}

/// The purchase usecases.
void registerPaywallUsecases(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => GetOfferingsUsecase(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => PurchasePackageUsecase(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => RestorePurchasesUsecase(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => GetCustomerInfoUsecase(getIt<SubscriptionRepository>()),
    );
}

/// The paywall cubit, the door, the cues and the buy cubits.
void registerPaywall(GetIt getIt, {required LocalStore? localStore}) {
  getIt
    ..registerFactory(
      () => PaywallCubit(
        identityStore: getIt<DeviceIdentityStore>(),
        getOfferingsUsecase: getIt<GetOfferingsUsecase>(),
        purchasePackageUsecase: getIt<PurchasePackageUsecase>(),
        restorePurchasesUsecase: getIt<RestorePurchasesUsecase>(),
        getCustomerInfoUsecase: getIt<GetCustomerInfoUsecase>(),
        subscriptionRepository: getIt<SubscriptionRepository>(),
        analytics: getIt.isRegistered<TelemetryGate>()
            ? PaywallAnalytics(getIt<TelemetryGate>())
            : null,
        refreshRegistration: () async {
          if (!buildSkipsPaywall) {
            await getIt<RevenueCatService>().invalidateCustomerInfoCache();
          }
          await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
          getIt<WidgetSync>().rewrite();
        },
      ),
    )
    // The one way into either paywall. It always answers with a layout:
    // the coded defaults, or what Developer options set in their place.
    ..registerLazySingleton<PaywallDoor>(
      () => PaywallDoor(
        developer: (product) => switch (product) {
          PaywallProduct.hosted => appPaywallLayoutOverride.hosted,
          PaywallProduct.pro => appPaywallLayoutOverride.pro,
        },
        developerIntro: (product) => switch (product) {
          PaywallProduct.hosted => appPaywallLayoutOverride.hostedIntro,
          PaywallProduct.pro => appPaywallLayoutOverride.proIntro,
        },
        developerThanks: (product) => switch (product) {
          PaywallProduct.hosted => appPaywallLayoutOverride.hostedThanks,
          PaywallProduct.pro => appPaywallLayoutOverride.proThanks,
        },
        developerOutro: (product) => switch (product) {
          PaywallProduct.hosted => appPaywallLayoutOverride.hostedOutro,
          PaywallProduct.pro => appPaywallLayoutOverride.proOutro,
        },
        widgetsDecision: () =>
            getIt<FeatureAccess>().decide(AppFeature.widgets),
        hasSeenFalseAlarm: () =>
            getIt<SharedPreferences>().getBool(
              PaywallDoor.falseAlarmShownKey,
            ) ??
            false,
        markFalseAlarmSeen: () => getIt<SharedPreferences>().setBool(
          PaywallDoor.falseAlarmShownKey,
          true,
        ),
        readHistoryOwn: () =>
            HistoryOwnReader(incidents: localStore?.incidents).read(),
        readLeavingFacts: () => LeavingFactsReader(
          incidents: localStore?.incidents,
          // The app's one topic list: see `readCriticalTopicCount`.
          readCriticalTopics: () =>
              readCriticalTopicCount(getIt<TopicsCubit>()),
          setupIncidentIds: () => getIt<SetupTestRing>().setupIncidentIds,
        ).read(),
        leavingShownFor: () =>
            getIt<SharedPreferences>().getString(PaywallDoor.leavingShownKey),
        markLeavingShown: (value) => getIt<SharedPreferences>().setString(
          PaywallDoor.leavingShownKey,
          value,
        ),
      ),
    )
    // The Interface sounds switch in Settings. On until the user turns it off.
    ..registerLazySingleton<InterfaceSoundsSetting>(
      () => InterfaceSoundsSetting(getIt<SharedPreferences>()),
    )
    // The sounds a paywall layout asks for. They play where the platform has
    // a player for interface sounds, and stay silent on the web and anywhere
    // else. Nothing here touches the alarm: it only asks whether one is up.
    ..registerLazySingleton<PaywallCues>(
      () => paywallCuesFor(
        getIt<PlatformCapabilities>(),
        playing: () => PlayingPaywallCues(
          player: UiSoundHost(),
          isSwitchOn: () => getIt<InterfaceSoundsSetting>().isOn,
          isAlarmUp: () =>
              getIt<AlarmFocus>().on ||
              getIt<IncidentAlarmController>().alarmingIncidentIds.isNotEmpty,
          alarmStarts: [
            getIt<AlarmArrivals>().incidentIds,
            getIt<AlarmFocus>().stream.where((isOn) => isOn),
          ],
          haptic: getIt<PlatformCapabilities>().hasHaptics
              ? AppHaptics.play
              : null,
          cancelHaptic: AppHaptics.cancelPattern,
          introFlavour: () => getIt.isRegistered<DevIntroSoundSwitch>()
              ? getIt<DevIntroSoundSwitch>().value
              : IntroSoundFlavour.piano,
        ),
      ),
    )
    // What every paywall layout buys through. A build that skips the store
    // gets made-up options, so a layout still has something to draw.
    ..registerFactoryParam<PaywallBuyCubit, PaywallProduct, PaywallBuyStatus?>(
      (product, demoStatus) {
        if (buildSkipsPaywall) {
          return DemoPaywallBuyCubit(
            product,
            startAs: demoStatus,
            priceBook: getIt<PriceBook>(),
          );
        }
        final holdsHosted = holdsHostedReader(getIt);
        final hostedByServer = hostedByServerReader(getIt);
        return switch (product) {
          PaywallProduct.pro => ProPaywallBuyCubit(
            access: getIt<ProPackAccess>(),
            shop: getIt<ProPackShop>(),
            priceBook: getIt<PriceBook>(),
          ),
          PaywallProduct.hosted => HostedPaywallBuyCubit(
            priceBook: getIt<PriceBook>(),
            getOfferings: getIt<GetOfferingsUsecase>(),
            purchasePackage: getIt<PurchasePackageUsecase>(),
            restorePurchases: getIt<RestorePurchasesUsecase>(),
            readIsPaid: holdsHosted, // access-ok: the buy cubit's name
            readIsRegisteredPaid: hostedByServer, // access-ok: same
            refreshRegistration: () async {
              await getIt<RevenueCatService>().invalidateCustomerInfoCache();
              await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
              getIt<WidgetSync>().rewrite();
            },
          ),
        };
      },
    )
    ..registerFactory(
      () => ProStatusCubit(
        readHoldsHosted: holdsHostedReader(getIt),
        holdingChanges: getIt<Holdings>().stream,
      ),
    );
}

void _mirrorStorePro(CustomerInfo info) => appPlanChanges.setStoreSaysPro(
  value: HostedHoldingSource.storeSaysHosted(info),
);
