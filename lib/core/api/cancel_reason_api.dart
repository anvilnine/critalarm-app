import 'package:critalarm/core/models/cancel_reason.dart';

/// The one route that takes an answer to "What made you cancel?"
/// (api.md §3.9). Authorised with the phone's management credential, like
/// every `/v1/` route. Only a server in `hosted` mode takes it.
// ignore: one_member_abstracts
abstract interface class CancelReasonApi {
  /// POST /v1/account/cancel-reason
  ///
  /// The request has no key. The server keeps at most one answer per account
  /// in any rolling 30 days: the first call creates it and every later call
  /// in the window is a repeat. A repeat never changes the reason, version or
  /// platform, may fill an empty text once, and never replaces text. Every
  /// accepted call answers 204. [text] must already be cleaned
  /// (`cleanCancelText`). [platform] is `ios` or `android`.
  ///
  /// Throws `ApiException` on a refusal. These will not change on a retry:
  /// 400 (`invalid request`, `invalid reason`, `text too long`), 401, 403
  /// (`tier`, with `tier` set to `hosted`), 413 and 501. A 429 or a 5xx may
  /// pass.
  Future<void> sendCancelReason({
    required CancelReason reason,
    required String appVersion,
    required String platform,
    String? text,
  });
}

/// For a build whose API client does not speak this route.
final class NoCancelReasonApi implements CancelReasonApi {
  const NoCancelReasonApi();

  @override
  Future<void> sendCancelReason({
    required CancelReason reason,
    required String appVersion,
    required String platform,
    String? text,
  }) => throw StateError('No cancel reason API');
}
