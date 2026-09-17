import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Signing in, choosing what happens to the data already on the phone, and
/// signing back out.
///
/// The account already exists. Registration made it long before any of these
/// screens ran, so signing in attaches an identity to what is here. Nothing
/// moves unless the person asks for it on the prompt.
class AccountCubit extends Cubit<AccountState> {
  AccountCubit({
    required this.identities,
    required this.account,
  }) : super(const AccountState());

  final IdentityRepository identities;
  final AccountRepository account;

  /// The session behind the open prompt. Held here, not in the state, so a
  /// token never reaches a widget.
  IdentitySession? _pending;

  bool supports(IdentityProvider provider) => identities.supports(provider);

  Future<void> load() async {
    final mode = await account.readServerMode();
    final identity = await identities.readIdentity();
    final isPaid = await account.readIsPaid();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: identity == null
            ? AccountStatus.signedOut
            : AccountStatus.signedIn,
        mode: mode,
        identity: identity,
        isPaid: isPaid,
        clearIdentity: identity == null,
      ),
    );
  }

  Future<void> signIn(IdentityProvider provider) async {
    emit(
      state.copyWith(
        status: AccountStatus.working,
        clearError: true,
        clearLiveIncident: true,
        clearChoice: true,
      ),
    );
    try {
      final session = await identities.signIn(provider);
      await _linkSession(session, canRetry: true);
    } on IdentitySignInCancelled {
      if (isClosed) return;
      emit(state.copyWith(status: AccountStatus.signedOut));
    } on Object catch (_) {
      _failSignedOut(LocaleKeys.account_error_sign_in_failed.tr());
    }
  }

  /// Keep both. Folds this phone's account into the one being signed in to.
  Future<void> keepBoth() async {
    final session = _pending;
    final choice = state.choice;
    if (session == null || choice == null) return;
    emit(state.copyWith(status: AccountStatus.working, clearError: true));
    final result = await account.merge(
      identityToken: session.token,
      intoAccount: choice.intoAccount,
    );
    if (isClosed) return;
    switch (result) {
      case AccountMerged(:final accountId):
        await _signedIn(session, accountId);
      case AccountMergeLiveIncident(:final incidentId):
        // The alarm is not closed here and the call is not retried. The
        // person acknowledges it and tries again, and they stay signed out
        // until they do.
        emit(
          state.copyWith(
            status: AccountStatus.choosing,
            liveIncidentId: incidentId,
          ),
        );
      case AccountMergeAlreadyMerged() || AccountMergeSameAccount():
        // Both mean there is nothing left to do, so this lands on the account
        // screen with no error banner.
        await _signedIn(session, choice.intoAccount);
      case AccountMergeUnauthorized():
        _failSignedOut(LocaleKeys.account_error_sign_in_failed.tr());
    }
  }

  /// Start fresh. The phone joins the identity's account and its old one is
  /// left behind, tokens and all.
  Future<void> startFresh() async {
    final session = _pending;
    final choice = state.choice;
    if (session == null || choice == null) return;
    emit(state.copyWith(status: AccountStatus.working, clearError: true));
    final result = await account.switchTo(
      identityToken: session.token,
      intoAccount: choice.intoAccount,
    );
    if (isClosed) return;
    switch (result) {
      case AccountSwitched(:final accountId):
        await _signedIn(session, accountId);
      case AccountSwitchUnauthorized():
        _failSignedOut(LocaleKeys.account_error_sign_in_failed.tr());
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(status: AccountStatus.working, clearError: true));
    try {
      await account.signOutDevice();
    } on Object catch (_) {
      if (isClosed) return;
      // The delete failed, so the phone still holds its old credential and is
      // still signed in. Say so rather than pretending it worked.
      emit(
        state.copyWith(
          status: AccountStatus.signedIn,
          errorMessage: LocaleKeys.account_sign_out_failed.tr(),
        ),
      );
      return;
    }
    if (isClosed) return;
    _pending = null;
    emit(
      const AccountState(status: AccountStatus.signedOut).copyWith(
        mode: state.mode,
      ),
    );
  }

  /// Erases the account. Works signed in or signed out, because an account
  /// with no identity is deleted on this phone's own credential.
  Future<void> deleteAccount() async {
    final wasSignedIn = state.status == AccountStatus.signedIn;
    emit(
      state.copyWith(
        status: AccountStatus.working,
        clearError: true,
        clearLiveIncident: true,
      ),
    );
    await _deleteOnce(
      await identities.readSession(),
      wasSignedIn: wasSignedIn,
      canRetry: true,
    );
  }

  Future<void> _deleteOnce(
    IdentitySession? session, {
    required bool wasSignedIn,
    required bool canRetry,
  }) async {
    final AccountDeleteResult result;
    try {
      result = await account.deleteAccount(identityToken: session?.token);
    } on Object catch (_) {
      // Offline, or the server broke. Nothing local is touched: a wipe on a
      // call that never landed leaves a live account nobody can reach and a
      // phone that has forgotten it.
      _failDelete(wasSignedIn: wasSignedIn);
      return;
    }
    if (isClosed) return;
    switch (result) {
      case AccountDeleted():
        try {
          await account.wipeAfterDelete();
        } on Object catch (_) {
          // The account is already gone on the server, so there is nothing to
          // put back. A registration that did not go through leaves the phone
          // with no credential, which is exactly the state it registers
          // itself out of on the next launch.
        }
        if (isClosed) return;
        _pending = null;
        emit(
          const AccountState(status: AccountStatus.deleted).copyWith(
            mode: state.mode,
          ),
        );
      case AccountDeleteLiveIncident(:final incidentId):
        // The alarm is not acknowledged here and the call is not retried. The
        // person acknowledges it and presses delete again, which works with
        // no restart because nothing local moved.
        emit(
          state.copyWith(
            status: wasSignedIn
                ? AccountStatus.signedIn
                : AccountStatus.signedOut,
            liveIncidentId: incidentId,
          ),
        );
      case AccountDeleteUnauthorized():
        if (session == null || !canRetry) {
          _failDelete(wasSignedIn: wasSignedIn);
          return;
        }
        // The session died rather than the person being refused. Drop it, run
        // the provider flow once more and try the delete again. One retry,
        // never a loop. Same shape as [_linkSession].
        await identities.clearSession();
        final IdentitySession retried;
        try {
          retried = await identities.signIn(session.provider);
        } on Object catch (_) {
          _failDelete(wasSignedIn: wasSignedIn);
          return;
        }
        if (isClosed) return;
        await _deleteOnce(retried, wasSignedIn: wasSignedIn, canRetry: false);
    }
  }

  void _failDelete({required bool wasSignedIn}) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: wasSignedIn ? AccountStatus.signedIn : AccountStatus.signedOut,
        errorMessage: LocaleKeys.account_delete_failed.tr(),
      ),
    );
  }

  Future<void> _linkSession(
    IdentitySession session, {
    required bool canRetry,
  }) async {
    final result = await account.link(session.token);
    if (isClosed) return;
    switch (result) {
      case AccountLinkClaimed(:final accountId) ||
          AccountLinkAttached(:final accountId):
        await _signedIn(session, accountId);
      case AccountLinkChoose():
        if (result.topics == 0) {
          // The server counted this phone's account, so a zero here means it
          // asked about an account holding nothing. Nobody should ever see
          // this screen with no topics on it.
          debugPrint('CritAlarm: account choose prompt with 0 topics');
        }
        _pending = session;
        emit(state.copyWith(status: AccountStatus.choosing, choice: result));
      case AccountLinkAccountHasAnotherIdentity():
        _failSignedOut(LocaleKeys.account_error_other_identity.tr());
      case AccountLinkUnauthorized():
        if (!canRetry) {
          _failSignedOut(LocaleKeys.account_error_sign_in_failed.tr());
          return;
        }
        // The session died. Drop it and run the provider flow once more. One
        // retry, never a loop.
        await identities.clearSession();
        final retried = await identities.signIn(session.provider);
        if (isClosed) return;
        await _linkSession(retried, canRetry: false);
    }
  }

  Future<void> _signedIn(IdentitySession session, String accountId) async {
    final identity = AccountIdentity(
      provider: session.provider,
      accountId: accountId,
      email: session.email,
    );
    await identities.saveIdentity(identity);
    if (isClosed) return;
    _pending = null;
    emit(
      state.copyWith(
        status: AccountStatus.signedIn,
        identity: identity,
        clearChoice: true,
        clearError: true,
        clearLiveIncident: true,
      ),
    );
  }

  void _failSignedOut(String message) {
    if (isClosed) return;
    _pending = null;
    emit(
      state.copyWith(
        status: AccountStatus.signedOut,
        errorMessage: message,
        clearChoice: true,
        clearIdentity: true,
      ),
    );
  }
}
