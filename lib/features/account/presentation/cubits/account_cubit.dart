import 'dart:async';

import 'package:critalarm/core/access/own_server.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/held_session.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/account/domain/usecases/sign_in_restore.dart';
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
    this.restore,
    this.held,
    this.readTopicCount,
    this.readLiveIncidentId,
    this.readRingClaim,
  }) : super(const AccountState());

  final IdentityRepository identities;
  final AccountRepository account;

  /// Puts a lost sign-in back, or says which account the phone is on. Null
  /// in a test that only reads the saved identity.
  final SignInRestore? restore;

  /// Writes a session back after leaving an account drops the stored one.
  final HeldSession? held;

  /// How many topics are in the list this phone holds. Null reads as none.
  final Future<int> Function()? readTopicCount;

  /// An alarm ringing or set to ring on this phone, or open on the server.
  /// Leaving is refused while there is one.
  final Future<String?> Function()? readLiveIncidentId;

  /// Which words a line about ringing may use here. Null reads as
  /// [RingClaim.alarm].
  final Future<RingClaim> Function()? readRingClaim;

  /// The session behind the open prompt. Held here, not in the state, so a
  /// token never reaches a widget.
  IdentitySession? _pending;

  /// What was held before a sign-in from the signed-out or "Finish signing
  /// in" card. The provider sign-in writes its session over it before the
  /// server has said that identity is on this account, so a sign-in that
  /// does not finish puts this back. Null once nothing needs putting back.
  HeldSnapshot? _heldBefore;

  bool supports(IdentityProvider provider) => identities.supports(provider);

  /// The providers this phone can offer that the account does not hold yet.
  ///
  /// Empty when nobody is signed in, and never holds Apple on Android, which
  /// [IdentityRepository.supports] already rules out for the sign-in buttons.
  List<IdentityProvider> get addableProviders {
    final identity = state.identity;
    if (identity == null) return const [];
    return [
      for (final provider in IdentityProvider.values)
        if (identities.supports(provider) && !identity.holds(provider))
          provider,
    ];
  }

  Future<void> load() async {
    final mode = await account.readServerMode();
    final holdsHosted = await account.readHoldsHosted();
    final restore = this.restore;
    final SignInRestoreOutcome outcome;
    if (restore != null && mode != null && !isOwnServerMode(mode)) {
      outcome = await restore.run();
    } else {
      final saved = await identities.readIdentity();
      outcome = saved == null
          ? const SignInRestoreSignedOut()
          : SignInRestoreSignedIn(saved);
    }
    if (isClosed) return;
    switch (outcome) {
      case SignInRestoreSignedIn(:final identity):
        emit(
          state.copyWith(
            status: AccountStatus.signedIn,
            mode: mode,
            identity: identity,
            holdsHosted: holdsHosted,
            clearUnfinished: true,
          ),
        );
      case SignInRestoreUnfinished(:final rows):
        final unfinished = await _unfinishedFrom(rows);
        final claim = await _ringClaim();
        if (isClosed) return;
        emit(
          state.copyWith(
            status: AccountStatus.unfinished,
            mode: mode,
            holdsHosted: holdsHosted,
            unfinished: unfinished,
            ringClaim: claim,
            clearIdentity: true,
          ),
        );
      case SignInRestoreSignedOut():
        emit(
          state.copyWith(
            status: AccountStatus.signedOut,
            mode: mode,
            holdsHosted: holdsHosted,
            clearIdentity: true,
            clearUnfinished: true,
          ),
        );
    }
  }

  /// The card's "Finish signing in" state, from the identities list. Shows
  /// the oldest row and counts the rest.
  Future<UnfinishedSignIn> _unfinishedFrom(
    List<AccountIdentityRow> rows,
  ) async {
    final oldest = rows.first;
    final provider = IdentityProvider.fromWire(oldest.provider);
    return UnfinishedSignIn(
      provider: provider,
      offered: provider != null && identities.supports(provider),
      emailHint: oldest.emailHidden ? null : oldest.emailHint,
      emailHidden: oldest.emailHidden,
      others: rows.length - 1,
      topics: await _topicCount(),
    );
  }

  Future<int> _topicCount() async {
    try {
      return await readTopicCount?.call() ?? 0;
    } on Object catch (_) {
      return 0;
    }
  }

  Future<RingClaim> _ringClaim() async {
    try {
      return await readRingClaim?.call() ?? RingClaim.alarm;
    } on Object catch (_) {
      // The quiet wording is never wrong on an older iPhone.
      return RingClaim.timeSensitive;
    }
  }

  Future<String?> _liveIncident() async {
    try {
      return await readLiveIncidentId?.call();
    } on Object catch (_) {
      return null;
    }
  }

  /// Where the card rests when nothing is in flight.
  AccountStatus get _restingStatus => state.identity != null
      ? AccountStatus.signedIn
      : state.unfinished != null
      ? AccountStatus.unfinished
      : AccountStatus.signedOut;

  Future<void> signIn(IdentityProvider provider) async {
    emit(
      state.copyWith(
        status: AccountStatus.working,
        clearError: true,
        clearLiveIncident: true,
        clearChoice: true,
      ),
    );
    final h = held;
    if (h != null && state.identity == null) {
      try {
        _heldBefore = await h.snapshot();
      } on Object catch (_) {
        _heldBefore = null;
      }
    }
    try {
      final session = await identities.signIn(provider);
      await _linkSession(session, canRetry: true);
    } on IdentitySignInCancelled {
      if (isClosed) return;
      await _putBackHeld();
      if (isClosed) return;
      emit(state.copyWith(status: _restingStatus));
    } on Object catch (_) {
      _failSignedOut(LocaleKeys.account_error_sign_in_failed.tr());
    }
  }

  /// Puts back what was held before the sign-in, once.
  Future<void> _putBackHeld([HeldSnapshot? replacement]) async {
    final before = replacement ?? _heldBefore;
    _heldBefore = null;
    final h = held;
    if (h == null || before == null) return;
    try {
      await h.putBack(before);
    } on Object catch (_) {
      // The store would not answer. Nothing better to do here.
    }
  }

  /// "Use a different account" on the card: the leave panel, with nobody
  /// signed in yet. Leaving lands on the sign-in buttons.
  Future<void> useDifferentAccount() async {
    if (state.isBusy) return;
    _pending = null;
    await _offerLeave();
  }

  /// "Leave and sign in" on the leave panel.
  Future<void> leaveAndSignIn() async {
    if (state.isBusy) return;
    await _leave();
  }

  /// "Stay on this account": back to the card, nothing sent anywhere. The
  /// session the sign-in just wrote is of an identity on another account, so
  /// what was held before goes back.
  void stayOnThisAccount() {
    if (state.isBusy) return;
    _pending = null;
    unawaited(_putBackHeld());
    emit(
      state.copyWith(
        status: _restingStatus,
        clearLeave: true,
        clearLiveIncident: true,
        clearError: true,
      ),
    );
  }

  /// Raises the leave panel, or leaves straight away when the phone holds
  /// no topics, because then there is nothing to warn about.
  Future<void> _offerLeave() async {
    final topics = await _topicCount();
    if (isClosed) return;
    if (topics == 0) {
      await _leave();
      return;
    }
    emit(
      state.copyWith(
        status: AccountStatus.choosing,
        leave: LeaveOffer(topics: topics),
        clearChoice: true,
        clearError: true,
        clearLiveIncident: true,
      ),
    );
  }

  /// Leaves the account this phone is on, then signs in with the identity
  /// the person just used, if there is one.
  ///
  /// Leaving is the ordinary sign-out: the device is deleted on the server
  /// and registers again on a fresh anonymous account (api.md §3.7). The
  /// account it left stays as it was.
  Future<void> _leave() async {
    emit(
      state.copyWith(
        status: AccountStatus.working,
        clearError: true,
        clearLiveIncident: true,
      ),
    );
    final live = await _liveIncident();
    if (isClosed) return;
    if (live != null) {
      // Not acknowledged here. The person acknowledges it and tries again.
      emit(
        state.copyWith(
          status: AccountStatus.choosing,
          leave: state.leave ?? LeaveOffer(topics: await _topicCount()),
          liveIncidentId: live,
          clearChoice: true,
        ),
      );
      return;
    }
    try {
      await account.signOutDevice();
    } on Object catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: state.leave != null ? AccountStatus.choosing : _restingStatus,
          errorMessage: LocaleKeys.account_sign_out_failed.tr(),
        ),
      );
      return;
    }
    if (isClosed) return;
    final session = _pending;
    if (session == null) {
      emit(
        const AccountState(status: AccountStatus.signedOut).copyWith(
          mode: state.mode,
          holdsHosted: state.holdsHosted,
          ringClaim: state.ringClaim,
        ),
      );
      return;
    }
    final AccountLinkResult result;
    try {
      result = await account.link(session.token);
    } on Object catch (_) {
      _failAfterLeave();
      return;
    }
    if (isClosed) return;
    switch (result) {
      case AccountLinkClaimed(:final accountId) ||
          AccountLinkAttached(:final accountId) ||
          AccountLinkAlreadyLinked(:final accountId) ||
          AccountLinkLinked(:final accountId):
        // Signing out dropped the stored session, so it goes back first.
        await held?.keep(session);
        await _signedIn(session, accountId);
      case _:
        _failAfterLeave();
    }
  }

  /// The phone left and the sign-in after it did not go through. It is on a
  /// fresh anonymous account that works, so that is what the card shows.
  void _failAfterLeave() {
    if (isClosed) return;
    _pending = null;
    // The phone left the account the old session was on, and the new one
    // never got on this one, so nothing stays held.
    if (_heldBefore != null) unawaited(_putBackHeld(const HeldSnapshot()));
    emit(
      const AccountState(status: AccountStatus.signedOut).copyWith(
        mode: state.mode,
        holdsHosted: state.holdsHosted,
        ringClaim: state.ringClaim,
        errorMessage: LocaleKeys.account_error_sign_in_failed.tr(),
      ),
    );
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

  /// Adds another way in to the account this phone already has.
  ///
  /// Same provider sheet the sign-in screen runs, then the same route with
  /// `intent: link`, which is the only thing that tells the server this is
  /// somebody adding their second provider rather than a second person
  /// signing in on a borrowed handset (api.md §3.7).
  Future<void> addProvider(IdentityProvider provider) async {
    if (state.identity == null || state.isBusy) return;
    emit(
      state.copyWith(
        status: AccountStatus.working,
        linkingProvider: provider,
        clearError: true,
      ),
    );
    final IdentitySession session;
    try {
      session = await identities.signIn(provider);
    } on IdentitySignInCancelled {
      // Backing out of the sheet is not a failure, so nothing is said about
      // it.
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AccountStatus.signedIn,
          clearLinkingProvider: true,
        ),
      );
      return;
    } on Object catch (_) {
      _failAddProvider(LocaleKeys.account_error_sign_in_failed.tr());
      return;
    }
    if (isClosed) return;
    await _addProviderOnce(session, canRetry: true);
  }

  Future<void> _addProviderOnce(
    IdentitySession session, {
    required bool canRetry,
  }) async {
    final result = await account.link(
      session.token,
      intent: AccountLinkIntent.link,
    );
    if (isClosed) return;
    switch (result) {
      // `already_linked` is a retry after a dropped reply landing on work
      // that is already done, so it looks like success and says nothing.
      case AccountLinkLinked(:final accountId) ||
          AccountLinkAlreadyLinked(:final accountId) ||
          AccountLinkClaimed(:final accountId) ||
          AccountLinkAttached(:final accountId):
        await _providerAdded(session, accountId);
      case AccountLinkIdentityHasAnotherAccount():
        _failAddProvider(LocaleKeys.account_error_identity_taken.tr());
      case AccountLinkChoose() ||
          AccountLinkAccountHasAnotherIdentity() ||
          AccountLinkUnknownConflict():
        // api.md §3.7 answers neither of these to `intent: link`. If a server
        // ever does, the person is told the add did not happen rather than
        // being shown a prompt built for the sign-in screen.
        _failAddProvider(LocaleKeys.account_error_sign_in_failed.tr());
      case AccountLinkUnauthorized():
        if (!canRetry) {
          _failAddProvider(LocaleKeys.account_error_sign_in_failed.tr());
          return;
        }
        // The session died rather than the person being refused. Drop it and
        // run the provider sheet once more. One retry, never a loop.
        await identities.clearSession();
        final IdentitySession retried;
        try {
          retried = await identities.signIn(session.provider);
        } on Object catch (_) {
          _failAddProvider(LocaleKeys.account_error_sign_in_failed.tr());
          return;
        }
        if (isClosed) return;
        await _addProviderOnce(retried, canRetry: false);
    }
  }

  /// The account now holds one more way in, and this phone holds the session
  /// that came with it.
  Future<void> _providerAdded(IdentitySession session, String accountId) async {
    final identity = AccountIdentity(
      provider: session.provider,
      accountId: accountId,
      email: session.email ?? state.identity?.email,
      providers: {...?state.identity?.providers, session.provider},
    );
    await identities.saveIdentity(identity);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: AccountStatus.signedIn,
        identity: identity,
        clearLinkingProvider: true,
        clearError: true,
      ),
    );
  }

  /// The person has read the error dialog. Drops the message so closing and
  /// reopening the screen does not show it a second time.
  void dismissError() {
    if (isClosed || state.errorMessage == null) return;
    emit(state.copyWith(clearError: true));
  }

  void _failAddProvider(String message) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: AccountStatus.signedIn,
        errorMessage: message,
        clearLinkingProvider: true,
      ),
    );
  }

  /// Mints a join code and holds it for the screen to show once.
  ///
  /// Every call retires the code before it, and the server keeps a hash
  /// rather than the value, so nothing can read this back later.
  Future<void> mintJoinToken() async {
    if (state.isMintingJoinToken) return;
    emit(
      state.copyWith(
        isMintingJoinToken: true,
        clearJoinToken: true,
        clearJoinTokenError: true,
      ),
    );
    final AccountJoinTokenResult result;
    try {
      result = await account.mintJoinToken();
    } on Object catch (_) {
      _failJoinToken();
      return;
    }
    if (isClosed) return;
    switch (result) {
      case AccountJoinTokenMinted(:final joinToken):
        emit(
          state.copyWith(
            isMintingJoinToken: false,
            joinToken: joinToken,
            joinTokenMints: state.joinTokenMints + 1,
          ),
        );
      case AccountJoinTokenUnauthorized():
        _failJoinToken();
    }
  }

  /// Takes the code off the screen once the person says they have it.
  void dismissJoinToken() {
    emit(state.copyWith(clearJoinToken: true));
  }

  void _failJoinToken() {
    if (isClosed) return;
    emit(
      state.copyWith(
        isMintingJoinToken: false,
        joinTokenError: LocaleKeys.account_join_code_failed.tr(),
      ),
    );
  }

  Future<void> signOut() async {
    emit(state.copyWith(status: AccountStatus.working, clearError: true));
    try {
      await account.signOutDevice();
    } on Object catch (_) {
      if (isClosed) return;
      // Either the delete failed, so the phone still holds its old credential
      // and is still signed in, or the delete went through and the store
      // logout failed, so the phone is signed in on a credential the server
      // has dropped. Pressing sign out again finishes the second case. Say
      // so rather than pretending it worked.
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
    // The account being deleted, read now. A refused delete signs the person
    // in again and sends it once more, and by then the phone no longer names
    // this account.
    final deleting = (await identities.readIdentity())?.accountId;
    await _deleteOnce(
      await identities.readSession(),
      deleting: deleting,
      wasSignedIn: wasSignedIn,
      canRetry: true,
    );
  }

  Future<void> _deleteOnce(
    IdentitySession? session, {
    required String? deleting,
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
          await account.wipeAfterDelete(accountId: deleting);
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
        await _deleteOnce(
          retried,
          deleting: deleting,
          wasSignedIn: wasSignedIn,
          canRetry: false,
        );
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
      // `already_linked` is this identity arriving on the account it already
      // points at, which is what a retry after a dropped reply looks like. It
      // lands on the account screen with no error.
      case AccountLinkClaimed(:final accountId) ||
          AccountLinkAttached(:final accountId) ||
          AccountLinkAlreadyLinked(:final accountId) ||
          AccountLinkLinked(:final accountId):
        await _signedIn(session, accountId);
      case AccountLinkChoose():
        if (result.topics == 0) {
          // The server counted this phone's account, so a zero here means it
          // asked about an account holding nothing. Nobody should ever see
          // this screen with no topics on it.
          debugPrint('CritAlarm: account choose prompt with 0 topics');
        }
        _pending = session;
        emit(
          state.copyWith(
            status: AccountStatus.choosing,
            choice: result,
            clearLeave: true,
          ),
        );
      case AccountLinkAccountHasAnotherIdentity():
        // The phone is on an account somebody signed in to with another
        // identity. One panel offers to leave it, in place of an error.
        _pending = session;
        await _offerLeave();
      case AccountLinkIdentityHasAnotherAccount():
        // api.md §3.7 answers this to `intent: link` only, so the sign-in
        // screen never sees it. Said plainly rather than left silent.
        _failSignedOut(LocaleKeys.account_error_identity_taken.tr());
      case AccountLinkUnknownConflict():
        // A 409 this build does not know. The ordinary failure, never the
        // leave panel: leaving is only offered for the one answer that
        // means it.
        _failSignedOut(LocaleKeys.account_error_sign_in_failed.tr());
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
    _heldBefore = null;
    emit(
      state.copyWith(
        status: AccountStatus.signedIn,
        identity: identity,
        clearChoice: true,
        clearError: true,
        clearLiveIncident: true,
        clearUnfinished: true,
        clearLeave: true,
      ),
    );
  }

  void _failSignedOut(String message) {
    if (isClosed) return;
    _pending = null;
    unawaited(_putBackHeld());
    emit(
      state.copyWith(
        status: state.unfinished != null
            ? AccountStatus.unfinished
            : AccountStatus.signedOut,
        errorMessage: message,
        clearChoice: true,
        clearIdentity: true,
        clearLeave: true,
      ),
    );
  }
}
