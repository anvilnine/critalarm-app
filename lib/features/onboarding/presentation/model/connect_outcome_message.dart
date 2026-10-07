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
  ServerIncompatible(:final version) =>
    LocaleKeys.onboarding_connect_version_incompatible.tr(
      namedArgs: {'version': version},
    ),
  // An exception dump is not a sentence. This one is a transport error, so
  // it gets the transport wording.
  ConnectTransportError(:final error) => networkFailureMessage(error),
};
