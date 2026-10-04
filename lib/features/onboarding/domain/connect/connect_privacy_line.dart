import 'package:critalarm/core/models/server_info.dart';

/// The one line on the connect step that says what the push relay sees.
///
/// Each value is a sentence the server's own `/v1/info` answer supports, so
/// the line is never shown before that answer is in hand.
enum ConnectPrivacyLine {
  cloudNone('onboarding_connect.privacy_cloud_none'),
  ownNone('onboarding_connect.privacy_own_none'),
  cloudFull('onboarding_connect.privacy_cloud_full'),
  ownFull('onboarding_connect.privacy_own_full');

  const ConnectPrivacyLine(this.translationKey);

  /// The key of the sentence in the translations file.
  final String translationKey;
}

/// Picks the line for a server from the `mode` and `relay_content` of its
/// `/v1/info` answer.
///
/// [relayContent] is the field as the server sent it, null when the answer
/// had none. Null comes back for that, and for any value this version has
/// no sentence for. Saying nothing is better than a claim the answer does
/// not back.
ConnectPrivacyLine? connectPrivacyLine({
  required String mode,
  required String? relayContent,
}) {
  final isCloud = mode == ServerModes.hosted;
  final isOwn = mode == ServerModes.selfhosted;
  if (!isCloud && !isOwn) return null;
  return switch (relayContent) {
    'none' =>
      isCloud ? ConnectPrivacyLine.cloudNone : ConnectPrivacyLine.ownNone,
    'full' =>
      isCloud ? ConnectPrivacyLine.cloudFull : ConnectPrivacyLine.ownFull,
    _ => null,
  };
}
