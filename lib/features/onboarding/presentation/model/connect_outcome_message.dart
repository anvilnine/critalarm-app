import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// The line to show for a connect that did not succeed, or null for one that
/// did or that only needs a token. The setup connect step and a connect link
/// both read it, so a person sees the same words either way.
String? connectOutcomeMessage(ConnectOutcome outcome) => switch (outcome) {
  Connected() || AdminTokenMissing() => null,
  ServerUnreachable(:final failure) ||
  ConnectionNotSaved(:final failure) => failureMessage(failure),
  ServerAddressDiffers(:final host) =>
    LocaleKeys.connect_link_address_differs.tr(namedArgs: {'host': host}),
  ServerDowngrade() => LocaleKeys.connect_link_downgrade.tr(),
  ServerAnswerInvalid() => LocaleKeys.onboarding_connect_answer_invalid.tr(),
  LinkServerNotSelfHosted() => LocaleKeys.connect_link_not_self_hosted.tr(),
  AdminTokenRefused() =>
    LocaleKeys.onboarding_connect_admin_token_error_wrong.tr(),
  RelayDiffers() => LocaleKeys.onboarding_connect_relay_differs.tr(),
  RelayUnchecked() => LocaleKeys.connect_link_relay_unchecked.tr(),
  ServerIncompatible(:final version) =>
    LocaleKeys.onboarding_connect_version_incompatible.tr(
      namedArgs: {'version': version},
    ),
  // An exception dump is not a sentence. This one is a transport error, so
  // it gets the transport wording.
  ConnectTransportError(:final error) => networkFailureMessage(error),
};
