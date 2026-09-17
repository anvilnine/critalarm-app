import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_results.freezed.dart';

/// What `POST /v1/account/link` answered (api.md §3.7).
///
/// Every documented answer is its own variant, including the ones the happy
/// path never reaches. A 409 carries the numbers the prompt has to show, so
/// these routes read the response instead of letting an exception drop them.
@freezed
sealed class AccountLinkResult with _$AccountLinkResult {
  /// 200 `claimed`. The identity was new and now points at the account this
  /// phone already had. Nothing moved. This is the common path.
  const factory AccountLinkResult.claimed({required String accountId}) =
      AccountLinkClaimed;

  /// 200 `attached`. The identity already had an account and this phone's was
  /// empty, so there was nothing to ask about.
  const factory AccountLinkResult.attached({required String accountId}) =
      AccountLinkAttached;

  /// 409 `choose`. Both sides hold data, so the person picks.
  ///
  /// [topics] and [incidents] are counted on this phone's account, the one
  /// that is folded in or given up. [intoAccount] is the identity's account.
  const factory AccountLinkResult.choose({
    required String intoAccount,
    required int topics,
    required int incidents,
  }) = AccountLinkChoose;

  /// 409 `account has another identity`. Somebody else is signed in on this
  /// handset and signing out first is the way through.
  const factory AccountLinkResult.accountHasAnotherIdentity() =
      AccountLinkAccountHasAnotherIdentity;

  /// 401. A bad device token, or a session that has died.
  const factory AccountLinkResult.unauthorized() = AccountLinkUnauthorized;
}

/// What `POST /v1/account/merge` answered (api.md §3.7).
@freezed
sealed class AccountMergeResult with _$AccountMergeResult {
  /// 200. This phone's account folded into the identity's, every topic token
  /// on both sides still working.
  const factory AccountMergeResult.merged({
    required String accountId,
    required String mergedFrom,
  }) = AccountMerged;

  /// 409 `live incident`. An alarm is up. The person acknowledges it and
  /// tries again; nothing here closes it for them.
  const factory AccountMergeResult.liveIncident({
    required String incidentId,
  }) = AccountMergeLiveIncident;

  /// 409 `already merged`. One of the two accounts is a tombstone, so the
  /// work is done.
  const factory AccountMergeResult.alreadyMerged() = AccountMergeAlreadyMerged;

  /// 409 `same account`. Both credentials resolve to one account, so there is
  /// nothing to move.
  const factory AccountMergeResult.sameAccount() = AccountMergeSameAccount;

  /// 401. A bad device token, or a session that has died.
  const factory AccountMergeResult.unauthorized() = AccountMergeUnauthorized;
}

/// What `POST /v1/account/switch` answered (api.md §3.7).
@freezed
sealed class AccountSwitchResult with _$AccountSwitchResult {
  /// 200. The phone joined the identity's account and its old one is a
  /// tombstone, carrying nothing with it.
  const factory AccountSwitchResult.switched({required String accountId}) =
      AccountSwitched;

  /// 401. A bad device token, or a session that has died.
  const factory AccountSwitchResult.unauthorized() = AccountSwitchUnauthorized;
}
