import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_results.freezed.dart';

/// Which screen the person was on when the app called `POST /v1/account/link`
/// (api.md §3.7).
///
/// Two calls can carry the same device token and the same brand new identity
/// and mean opposite things, and the server has no way to tell them apart, so
/// the app says which it meant. Leaving it out reads as [signIn] on the
/// server, which is what every client before 1.14.0 sent.
enum AccountLinkIntent {
  /// The sign-in screen. "This is me, put me on my account."
  signIn('sign_in'),

  /// The account screen, under the button that adds another way to sign in.
  /// "Also let me in with this one."
  link('link');

  const AccountLinkIntent(this.wireValue);

  /// What goes in the `intent` field.
  final String wireValue;
}

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

  /// 200 `linked`. Intent `link` only. The identity was new and this phone's
  /// account already held one, so the account now holds both. Nothing moved.
  const factory AccountLinkResult.linked({required String accountId}) =
      AccountLinkLinked;

  /// 200 `already_linked`. The identity already points at this phone's own
  /// account, so the work is done. A retry after a dropped reply lands here,
  /// and it is a success, not an error.
  const factory AccountLinkResult.alreadyLinked({required String accountId}) =
      AccountLinkAlreadyLinked;

  /// 409 `identity has another account`. Intent `link` only. That Apple ID or
  /// Google account is already somebody's account, so adding it here would
  /// mean deciding whose data wins.
  const factory AccountLinkResult.identityHasAnotherAccount() =
      AccountLinkIdentityHasAnotherAccount;

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

/// What `DELETE /v1/account` answered (api.md §3.7).
@freezed
sealed class AccountDeleteResult with _$AccountDeleteResult {
  /// 204. The account and everything under it is gone, and every credential
  /// it held is dead.
  const factory AccountDeleteResult.deleted() = AccountDeleted;

  /// 409 `live incident`. An alarm is ringing. The person acknowledges it and
  /// tries again; nothing here closes it for them. Only an `open` incident
  /// lands here, never an acked one: nothing is ringing once it is
  /// acknowledged, and a person must never be stuck unable to leave.
  const factory AccountDeleteResult.liveIncident({
    required String incidentId,
  }) = AccountDeleteLiveIncident;

  /// 401. A dead device token, or an account that holds an identity whose
  /// token was missing, invalid, or somebody else's.
  const factory AccountDeleteResult.unauthorized() = AccountDeleteUnauthorized;
}

/// What `POST /v1/account/join-token` answered (api.md §3.7).
@freezed
sealed class AccountJoinTokenResult with _$AccountJoinTokenResult {
  /// 200. A fresh `aj_`. Every call mints a new one and retires the one
  /// before it, so this reply is the only place the value ever appears.
  const factory AccountJoinTokenResult.minted({required String joinToken}) =
      AccountJoinTokenMinted;

  /// 401. A device token the server no longer knows.
  const factory AccountJoinTokenResult.unauthorized() =
      AccountJoinTokenUnauthorized;
}
