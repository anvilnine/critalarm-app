import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/read_permission_setup_usecase.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:flutter/foundation.dart';

/// The phone a flow runs on, passed in as values so nothing in the registry
/// asks the platform itself.
@immutable
class OnboardingPlatform {
  const OnboardingPlatform({required this.platform, required this.isWeb});

  final TargetPlatform platform;
  final bool isWeb;
}

/// What is already true for this user. Every answer is a local read, so
/// launch never waits on the network.
abstract interface class OnboardingStepFacts {
  /// A server connection is saved.
  Future<bool> hasConnection();

  /// Every permission in this phone's setup step list is granted.
  Future<bool> hasEveryPermission();

  /// The user has owned a topic.
  Future<bool> hasOwnedTopic();

  /// A message from the user's own tool has reached this phone.
  Future<bool> hasReceivedFirstMessage();

  /// The offer step would show nothing to this user right now: it is
  /// switched off, or one of its skip reasons holds.
  Future<bool> hasNoOfferToShow();
}

/// Reads the facts from what the phone already holds.
class DeviceOnboardingStepFacts implements OnboardingStepFacts {
  const DeviceOnboardingStepFacts({
    required this.on,
    required this.getConnection,
    required this.readPermissionSetup,
    required this.notices,
    required this.firstMessage,
    required this.offer,
  });

  final OnboardingOfferGate offer;
  final OnboardingPlatform on;
  final GetConnectionUsecase getConnection;
  final ReadPermissionSetupUsecase readPermissionSetup;
  final InAppNoticeRepository notices;
  final FirstMessageStore firstMessage;

  @override
  Future<bool> hasConnection() async =>
      (await getConnection(const NoParams())).getOrNull() != null;

  /// The same read the permissions screen draws from, so the engine and the
  /// screen cannot disagree about what is left to ask.
  @override
  Future<bool> hasEveryPermission() async =>
      (await readPermissionSetup()).everyGranted;

  @override
  Future<bool> hasOwnedTopic() async => notices.getFirstTopicOwnedAt() != null;

  @override
  Future<bool> hasReceivedFirstMessage() async => firstMessage.isReceived;

  @override
  Future<bool> hasNoOfferToShow() async =>
      !(await offer.decide(isReplay: false)).isShown;
}
