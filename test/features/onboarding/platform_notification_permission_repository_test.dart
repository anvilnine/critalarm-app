import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/features/onboarding/data/repositories/platform_notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class MockPrefs extends Mock implements SharedPreferences {}

const _askedKey = 'notifications_prompt_shown';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.critalarm/settings');
  final channelCalls = <MethodCall>[];

  setUp(() {
    channelCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          channelCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('on web', () {
    // A browser reports the platform of its device, so the web answer must
    // not depend on it.
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      late MockPlugin plugin;
      late MockPrefs prefs;
      late PlatformNotificationPermissionRepository repository;

      setUp(() {
        plugin = MockPlugin();
        prefs = MockPrefs();
        repository = PlatformNotificationPermissionRepository(
          capabilities: PlatformCapabilities(isWeb: true, platform: platform),
          plugin: plugin,
          channel: channel,
          prefs: prefs,
        );
      });

      test('checkPermission is granted and asks nobody '
          '(${platform.name})', () async {
        final result = await repository.checkPermission();

        expect(result.getOrNull(), NotificationPermissionStatus.granted);
        verifyZeroInteractions(plugin);
        verifyZeroInteractions(prefs);
        expect(channelCalls, isEmpty);
      });

      test('requestPermission is granted, asks nobody and does not set the '
          'asked flag (${platform.name})', () async {
        final result = await repository.requestPermission();

        expect(result.getOrNull(), NotificationPermissionStatus.granted);
        verifyZeroInteractions(plugin);
        verifyZeroInteractions(prefs);
        expect(channelCalls, isEmpty);
      });
    }

    test('a real prefs store stays empty after both calls', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = PlatformNotificationPermissionRepository(
        capabilities: const PlatformCapabilities(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        plugin: MockPlugin(),
        channel: channel,
        prefs: prefs,
      );

      await repository.checkPermission();
      await repository.requestPermission();

      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('on a phone', () {
    late SharedPreferences prefs;
    late MockPlugin plugin;
    late MockAndroidPlugin android;

    /// What the asked flag held each time the plugin was reached.
    late List<bool?> flagWhenPluginReached;

    PlatformNotificationPermissionRepository repositoryOn(
      TargetPlatform platform,
    ) => PlatformNotificationPermissionRepository(
      capabilities: PlatformCapabilities(isWeb: false, platform: platform),
      plugin: plugin,
      channel: channel,
      prefs: prefs,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      plugin = MockPlugin();
      android = MockAndroidPlugin();
      flagWhenPluginReached = [];

      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenAnswer((_) {
        flagWhenPluginReached.add(prefs.getBool(_askedKey));
        return android;
      });
    });

    test('requestPermission sets the asked flag before it reaches the '
        'plugin', () async {
      when(android.requestNotificationsPermission).thenAnswer((_) async {
        flagWhenPluginReached.add(prefs.getBool(_askedKey));
        return true;
      });

      final result = await repositoryOn(
        TargetPlatform.android,
      ).requestPermission();

      expect(result.getOrNull(), NotificationPermissionStatus.granted);
      // Once when the plugin was resolved, once when it was asked.
      expect(flagWhenPluginReached, [true, true]);
      verify(android.requestNotificationsPermission).called(1);
      expect(prefs.getBool(_askedKey), isTrue);
    });

    test('a refused prompt is denied, and the flag stays set', () async {
      when(
        android.requestNotificationsPermission,
      ).thenAnswer((_) async => false);

      final result = await repositoryOn(
        TargetPlatform.android,
      ).requestPermission();

      expect(result.getOrNull(), NotificationPermissionStatus.denied);
      expect(prefs.getBool(_askedKey), isTrue);
    });

    test('checkPermission reads the plugin and never sets the asked '
        'flag', () async {
      when(android.areNotificationsEnabled).thenAnswer((_) async => false);

      final result = await repositoryOn(
        TargetPlatform.android,
      ).checkPermission();

      // Never asked, so "not granted" reads as not determined.
      expect(result.getOrNull(), NotificationPermissionStatus.notDetermined);
      verify(android.areNotificationsEnabled).called(1);
      expect(prefs.getBool(_askedKey), isNull);
    });
  });
}
