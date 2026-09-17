import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/features/account/presentation/widgets/merge_or_fresh_panel.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Who this phone belongs to, and the way in and out.
///
/// On a self-hosted server there is nothing here: that server has one operator
/// and no accounts to sign in to, so the section is left out rather than shown
/// greyed out.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<AccountCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const AccountView(),
    );
  }
}

/// The screen itself, taking its cubit from the tree so a test can supply one.
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.account_header.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
                child: _body(context, state),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, AccountState state) {
    if (state.status == AccountStatus.loading || !state.isAvailable) {
      return const SizedBox.shrink();
    }
    if (state.status == AccountStatus.choosing) {
      return MergeOrFreshPanel(state: state);
    }
    return AppSheet(
      child: state.status == AccountStatus.signedIn
          ? _SignedIn(state: state)
          : _SignedOut(state: state),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LocaleKeys.account_signed_out_pitch.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 14,
            color: colors.ink2,
            height: 1.4,
          ),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          AppNote(text: state.errorMessage!),
        ],
        const SizedBox(height: 16),
        // Apple is iOS only. Android gets Google alone, not a dead button.
        if (cubit.supports(IdentityProvider.apple)) ...[
          AppButton(
            label: LocaleKeys.account_sign_in_apple.tr(),
            variant: AppButtonVariant.ink,
            isFullWidth: true,
            isLoading: state.isBusy,
            onPressed: () => unawaited(cubit.signIn(IdentityProvider.apple)),
          ),
          const SizedBox(height: 8),
        ],
        AppButton(
          label: LocaleKeys.account_sign_in_google.tr(),
          variant: AppButtonVariant.paper,
          isFullWidth: true,
          isLoading: state.isBusy,
          onPressed: () => unawaited(cubit.signIn(IdentityProvider.google)),
        ),
      ],
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();
    final colors = context.appColors;
    final identity = state.identity!;
    final provider = switch (identity.provider) {
      IdentityProvider.apple => LocaleKeys.account_provider_apple.tr(),
      IdentityProvider.google => LocaleKeys.account_provider_google.tr(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${LocaleKeys.account_provider_label.tr()} $provider',
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.ink3,
          ),
        ),
        const SizedBox(height: 6),
        // Apple's private relay address is a real address, so it is shown
        // exactly as it came back.
        Text(
          identity.email ?? LocaleKeys.account_email_missing.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 12),
        // Small and selectable, because it is the one thing a support message
        // needs.
        AppKeyValueRow(
          label: LocaleKeys.account_account_id_label.tr(),
          value: identity.accountId,
          showCopyButton: true,
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          AppNote(text: state.errorMessage!),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: LocaleKeys.account_sign_out.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          isLoading: state.isBusy,
          onPressed: () => unawaited(cubit.signOut()),
        ),
        // A19 fills the gap below with Delete account. Nothing here builds it.
      ],
    );
  }
}
