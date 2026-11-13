import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/sign_in_methods_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/sign_in_methods_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Where the page lives: Settings, Account and plan, Ways to sign in.
const String signInMethodsPath = '/settings/account/sign-in-methods';

/// Every way in the account holds, with a remove on each but the last, and
/// a card of adds under it. One level under Account and plan, the Join code
/// pattern.
class SignInMethodsScreen extends StatelessWidget {
  const SignInMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SignInMethodsCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocConsumer<SignInMethodsCubit, SignInMethodsState>(
        listenWhen: (previous, current) =>
            current.status != previous.status ||
            current.errorMessage != previous.errorMessage ||
            current.liveIncidentId != previous.liveIncidentId,
        listener: _listen,
        builder: (context, state) => AppScreenScaffold(
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.account_ways_title.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () => _back(context),
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
                child: _Body(state: state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _listen(BuildContext context, SignInMethodsState state) {
    // Nothing to manage without a session on the account: the account card
    // says what to do next.
    if (state.status == SignInMethodsStatus.signedOut) {
      _back(context);
      return;
    }
    final message = state.errorMessage;
    if (message != null) {
      unawaited(_showError(context, message));
      return;
    }
    final incident = state.liveIncidentId;
    if (incident != null) unawaited(_showLiveIncident(context, incident));
  }
}

void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/settings/account');
  }
}

Future<void> _showError(BuildContext context, String message) async {
  final cubit = context.read<SignInMethodsCubit>();
  await showAppDialog<void>(
    context: context,
    title: LocaleKeys.account_error_dialog_title.tr(),
    body: message,
    actions: [AppDialogAction<void>(label: LocaleKeys.common_close.tr())],
  );
  cubit.dismissError();
}

Future<void> _showLiveIncident(BuildContext context, String incidentId) async {
  final cubit = context.read<SignInMethodsCubit>();
  final open = await showAppDialog<bool>(
    context: context,
    title: LocaleKeys.account_live_incident_title.tr(),
    body: LocaleKeys.account_live_incident_body.tr(),
    actions: [
      AppDialogAction<bool>(
        label: LocaleKeys.common_close.tr(),
        value: false,
        variant: AppButtonVariant.ghost,
      ),
      AppDialogAction<bool>(
        label: LocaleKeys.account_live_incident_button.tr(),
        value: true,
      ),
    ],
  );
  cubit.dismissError();
  if (open ?? false) {
    if (!context.mounted) return;
    unawaited(context.push('/incidents/$incidentId'));
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final SignInMethodsState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == SignInMethodsStatus.loading ||
        state.status == SignInMethodsStatus.signedOut) {
      return const SizedBox.shrink();
    }
    final cubit = context.read<SignInMethodsCubit>();
    final addable = state.addable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTitledCard(
          title: LocaleKeys.account_ways_list_header.tr(),
          children: [
            for (final row in state.rows)
              _MethodRow(
                row: row,
                onRemove: state.canRemove && !state.isBusy
                    ? () => unawaited(_confirmRemove(context, row))
                    : null,
                showsRemove: state.canRemove,
              ),
          ],
        ),
        if (addable.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppTitledCard(
            title: LocaleKeys.account_ways_add_header.tr(),
            children: [
              for (final provider in addable)
                AppCardRow(
                  title: switch (provider) {
                    IdentityProvider.apple =>
                      LocaleKeys.account_link_add_apple.tr(),
                    IdentityProvider.google =>
                      LocaleKeys.account_link_add_google.tr(),
                  },
                  leading: _ProviderMark(provider: provider),
                  onTap: state.isBusy
                      ? null
                      : () => unawaited(cubit.add(provider)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    SignInMethodRow row,
  ) async {
    final cubit = context.read<SignInMethodsCubit>();
    final body = row.current
        ? '${LocaleKeys.account_ways_remove_body.tr()}\n\n'
              '${LocaleKeys.account_ways_remove_current.tr()}'
        : LocaleKeys.account_ways_remove_body.tr();
    final remove = await showAppDialog<bool>(
      context: context,
      title: LocaleKeys.account_ways_remove_title.tr(),
      body: body,
      actions: [
        AppDialogAction<bool>(
          label: LocaleKeys.common_cancel.tr(),
          value: false,
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction<bool>(
          label: LocaleKeys.account_ways_remove_button.tr(),
          value: true,
          variant: AppButtonVariant.crit,
        ),
      ],
    );
    if (remove ?? false) await cubit.remove(row.id);
  }
}

/// The row's title: the full address, or that Apple keeps it hidden.
String _titleOf(SignInMethodRow row) {
  final email = row.email;
  if (row.emailHidden || email == null) {
    return LocaleKeys.account_on_account_email_hidden.tr();
  }
  return email;
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.row,
    required this.onRemove,
    required this.showsRemove,
  });

  final SignInMethodRow row;
  final VoidCallback? onRemove;
  final bool showsRemove;

  @override
  Widget build(BuildContext context) {
    final title = _titleOf(row);
    final provider = row.provider;
    return AppCardRow(
      title: title,
      detail: row.showsDate
          ? LocaleKeys.account_ways_added.tr(
              args: [
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(row.linkedAt.toLocal()),
              ],
            )
          : null,
      leading: provider == null ? null : _ProviderMark(provider: provider),
      showsArrow: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.current)
            AppBadge(text: LocaleKeys.account_ways_this_device.tr()),
          if (showsRemove)
            AppDismissCross(
              label: LocaleKeys.account_ways_remove_label.tr(args: [title]),
              tapSize: 48,
              onPressed: onRemove ?? () {},
            ),
        ],
      ),
    );
  }
}

class _ProviderMark extends StatelessWidget {
  const _ProviderMark({required this.provider});

  final IdentityProvider provider;

  @override
  Widget build(BuildContext context) => switch (provider) {
    IdentityProvider.apple => BrandIcon.apple(color: context.appColors.ink),
    IdentityProvider.google => const BrandIcon.google(),
  };
}
