import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/repositories/account_identities_repository.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/held_session.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/account/presentation/cubits/sign_in_methods_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "Ways to sign in" page: every way in the account holds, adding one
/// and removing one (api.md §3.7).
///
/// Every server call carries the session this phone holds. An add runs a
/// provider sign-in, which writes its session over the held one, so the held
/// one is put back afterwards: the phone stays signed in as it was.
class SignInMethodsCubit extends Cubit<SignInMethodsState> {
  SignInMethodsCubit({
    required this.identities,
    required this.account,
    required this.accountIdentities,
    required this.held,
  }) : super(const SignInMethodsState());

  final IdentityRepository identities;
  final AccountRepository account;
  final AccountIdentitiesRepository accountIdentities;
  final HeldSession held;

  Future<void> load() async {
    final offered = [
      for (final provider in IdentityProvider.values)
        if (identities.supports(provider)) provider,
    ];
    final List<AccountIdentityRow> list;
    try {
      list = await accountIdentities.list(
        identityToken: await held.readOwnToken(),
      );
    } on Object catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(status: SignInMethodsStatus.failed, offered: offered),
      );
      return;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: list.any((row) => row.current)
            ? SignInMethodsStatus.ready
            : SignInMethodsStatus.signedOut,
        rows: _rowsFrom(list),
        offered: offered,
      ),
    );
  }

  /// The person has read the dialog.
  void dismissError() {
    if (isClosed) return;
    emit(state.copyWith(clearError: true, clearLiveIncident: true));
  }

  /// Adds a way to sign in with [provider]: its sign-in, then `link` with
  /// `intent: link` and the held session as `proof_token`.
  Future<void> add(IdentityProvider provider) async {
    if (state.isBusy) return;
    _working();
    final before = await held.snapshot();
    final IdentitySession session;
    try {
      session = await identities.signIn(provider);
    } on IdentitySignInCancelled {
      await held.putBack(before);
      _ready();
      return;
    } on Object catch (_) {
      await held.putBack(before);
      _fail(LocaleKeys.account_error_sign_in_failed.tr());
      return;
    }
    await _link(session, before: before, proof: before.token);
  }

  Future<void> _link(
    IdentitySession session, {
    required HeldSnapshot before,
    required String? proof,
    HeldSnapshot? fallback,
    bool proofRetried = false,
    bool sheetRetried = false,
  }) async {
    final AccountLinkResult result;
    try {
      result = await account.link(
        session.token,
        intent: AccountLinkIntent.link,
        proofToken: proof,
      );
    } on Object catch (_) {
      await held.putBack(before);
      _fail(LocaleKeys.account_error_sign_in_failed.tr());
      return;
    }
    if (isClosed) return;
    switch (result) {
      case AccountLinkLinked() ||
          AccountLinkAlreadyLinked() ||
          AccountLinkClaimed() ||
          AccountLinkAttached():
        // The phone keeps the session it had, so it stays signed in as
        // before and the badge does not move.
        await held.putBack(before);
        await _refresh();
      case AccountLinkIdentityHasAnotherAccount():
        await held.putBack(before);
        _fail(LocaleKeys.account_error_identity_taken.tr());
      case AccountLinkCapIdentities():
        await held.putBack(before);
        _fail(LocaleKeys.account_ways_error_cap.tr());
      case AccountLinkProofRequired():
        // Never clears the held session. The held one was too old or gone,
        // so the identity this phone signed in with signs in once more.
        if (proofRetried) {
          // The fresh session was not taken either, so the one from before
          // the add goes back.
          await held.putBack(fallback ?? before);
          _fail(LocaleKeys.account_error_sign_in_failed.tr());
          return;
        }
        final current = await _currentProvider();
        if (current == null) {
          await held.putBack(before);
          _fail(LocaleKeys.account_error_sign_in_failed.tr());
          return;
        }
        final IdentitySession fresh;
        try {
          fresh = await identities.signIn(current);
        } on IdentitySignInCancelled {
          await held.putBack(before);
          _ready();
          return;
        } on Object catch (_) {
          await held.putBack(before);
          _fail(LocaleKeys.account_error_sign_in_failed.tr());
          return;
        }
        if (isClosed) return;
        await _link(
          session,
          // If the server takes it, the fresh session is the one to keep.
          before: HeldSnapshot(
            token: fresh.token,
            provider: fresh.provider,
            email: fresh.email,
          ),
          fallback: before,
          proof: fresh.token,
          proofRetried: true,
          sheetRetried: sheetRetried,
        );
      case AccountLinkUnauthorized():
        // The new identity's session died before it was used. Its sheet
        // runs once more, never a loop, and the held session is untouched.
        if (sheetRetried) {
          await held.putBack(before);
          _fail(LocaleKeys.account_error_sign_in_failed.tr());
          return;
        }
        final IdentitySession retried;
        try {
          retried = await identities.signIn(session.provider);
        } on Object catch (_) {
          await held.putBack(before);
          _fail(LocaleKeys.account_error_sign_in_failed.tr());
          return;
        }
        if (isClosed) return;
        await _link(
          retried,
          before: before,
          proof: proof,
          fallback: fallback,
          proofRetried: proofRetried,
          sheetRetried: true,
        );
      case AccountLinkChoose() ||
          AccountLinkAccountHasAnotherIdentity() ||
          AccountLinkUnknownConflict():
        await held.putBack(before);
        _fail(LocaleKeys.account_error_sign_in_failed.tr());
    }
  }

  /// Removes the way to sign in [rowId] names, with the held session. A
  /// session older than 300 seconds runs one provider sign-in and one retry.
  Future<void> remove(String rowId) async {
    if (state.isBusy) return;
    _working();
    final token = await held.readOwnToken();
    if (token == null) {
      await _signedOut();
      return;
    }
    await _remove(rowId, token, retried: false);
  }

  Future<void> _remove(
    String rowId,
    String token, {
    required bool retried,
    HeldSnapshot? before,
  }) async {
    final AccountIdentityRemoveResult result;
    try {
      result = await accountIdentities.remove(
        identityId: rowId,
        identityToken: token,
      );
    } on Object catch (_) {
      if (before != null) await held.putBack(before);
      _fail(LocaleKeys.account_ways_remove_failed.tr());
      return;
    }
    if (isClosed) return;
    switch (result) {
      case AccountIdentityRemoved():
        await _afterRemove();
      case AccountIdentityRemoveRecentSignInRequired() ||
          AccountIdentityRemoveUnauthorized():
        if (retried) {
          // A session the server will not take is never kept.
          if (before != null) await held.putBack(before);
          _fail(LocaleKeys.account_ways_remove_failed.tr());
          return;
        }
        final provider = _reSignInProvider();
        if (provider == null) {
          _fail(LocaleKeys.account_ways_remove_failed.tr());
          return;
        }
        final snapshot = await held.snapshot();
        final IdentitySession fresh;
        try {
          fresh = await identities.signIn(provider);
        } on IdentitySignInCancelled {
          await held.putBack(snapshot);
          _ready();
          return;
        } on Object catch (_) {
          await held.putBack(snapshot);
          _fail(LocaleKeys.account_ways_remove_failed.tr());
          return;
        }
        if (isClosed) return;
        await _remove(rowId, fresh.token, retried: true, before: snapshot);
      case AccountIdentityRemoveLiveIncident(:final incidentId):
        emit(
          state.copyWith(
            status: SignInMethodsStatus.ready,
            liveIncidentId: incidentId,
          ),
        );
      case AccountIdentityRemoveNotFound() ||
          AccountIdentityRemoveLastIdentity():
        // Somebody else changed the list. It is read again.
        await _refresh();
    }
  }

  /// Reads the list with the session the phone holds. A row still marked
  /// current means signed in as before. None, or a 401, means the identity
  /// this phone signed in with is gone: the session and the saved identity
  /// are dropped, and the account card asks to finish signing in.
  Future<void> _afterRemove() async {
    final token = await held.readOwnToken();
    List<AccountIdentityRow>? list;
    if (token != null) {
      try {
        list = await accountIdentities.list(identityToken: token);
      } on ApiException catch (e) {
        if (e.statusCode != 401) {
          _fail(LocaleKeys.account_ways_remove_failed.tr());
          return;
        }
      } on Object catch (_) {
        _fail(LocaleKeys.account_ways_remove_failed.tr());
        return;
      }
    }
    AccountIdentityRow? current;
    for (final row in list ?? const <AccountIdentityRow>[]) {
      if (row.current) current = row;
    }
    final provider = current == null
        ? null
        : IdentityProvider.fromWire(current.provider);
    final saved = await identities.readIdentity();
    if (list == null || provider == null || saved == null) {
      await _signedOut();
      return;
    }
    await identities.saveIdentity(
      AccountIdentity(
        provider: provider,
        accountId: saved.accountId,
        email: current!.email,
        providers: {
          for (final row in list) ?IdentityProvider.fromWire(row.provider),
        },
      ),
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        status: SignInMethodsStatus.ready,
        rows: _rowsFrom(list),
        clearError: true,
      ),
    );
  }

  Future<void> _signedOut() async {
    await identities.clearSession();
    if (isClosed) return;
    emit(state.copyWith(status: SignInMethodsStatus.signedOut));
  }

  Future<void> _refresh() async {
    final List<AccountIdentityRow> list;
    try {
      list = await accountIdentities.list(
        identityToken: await held.readOwnToken(),
      );
    } on Object catch (_) {
      _ready();
      return;
    }
    if (isClosed) return;
    final saved = await identities.readIdentity();
    if (saved != null) {
      await identities.saveIdentity(
        AccountIdentity(
          provider: saved.provider,
          accountId: saved.accountId,
          email: saved.email,
          providers: {
            saved.provider,
            for (final row in list) ?IdentityProvider.fromWire(row.provider),
          },
        ),
      );
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: SignInMethodsStatus.ready,
        rows: _rowsFrom(list),
        clearError: true,
      ),
    );
  }

  /// The provider the phone signed in with, for a fresh proof.
  Future<IdentityProvider?> _currentProvider() async {
    for (final row in state.rows) {
      final provider = row.provider;
      if (row.current && provider != null && identities.supports(provider)) {
        return provider;
      }
    }
    final saved = await identities.readIdentity();
    final provider = saved?.provider;
    return provider != null && identities.supports(provider) ? provider : null;
  }

  /// The provider to sign in again with before a remove: the current row's
  /// first, then any other row this platform can run.
  IdentityProvider? _reSignInProvider() {
    final ordered = [
      ...state.rows.where((row) => row.current),
      ...state.rows.where((row) => !row.current),
    ];
    for (final row in ordered) {
      final provider = row.provider;
      if (provider != null && identities.supports(provider)) return provider;
    }
    return null;
  }

  void _working() => emit(
    state.copyWith(
      status: SignInMethodsStatus.working,
      clearError: true,
      clearLiveIncident: true,
    ),
  );

  void _ready() {
    if (isClosed) return;
    emit(state.copyWith(status: SignInMethodsStatus.ready));
  }

  void _fail(String message) {
    if (isClosed) return;
    emit(
      state.copyWith(status: SignInMethodsStatus.ready, errorMessage: message),
    );
  }

  static List<SignInMethodRow> _rowsFrom(List<AccountIdentityRow> list) {
    String readsAs(AccountIdentityRow row) =>
        '${row.provider}|${row.emailHidden ? '' : row.email ?? row.emailHint}';
    final counts = <String, int>{};
    for (final row in list) {
      counts.update(readsAs(row), (n) => n + 1, ifAbsent: () => 1);
    }
    return [
      for (final row in list)
        SignInMethodRow(
          id: row.id,
          provider: IdentityProvider.fromWire(row.provider),
          email: row.email,
          emailHidden: row.emailHidden,
          linkedAt: row.linkedAt,
          current: row.current,
          showsDate: (counts[readsAs(row)] ?? 0) > 1,
        ),
    ];
  }
}
