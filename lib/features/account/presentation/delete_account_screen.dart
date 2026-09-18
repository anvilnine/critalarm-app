import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The last screen before an account is erased.
///
/// Its own route rather than a dialog: there are four things to read here and
/// a dialog that long gets dismissed instead of read. Every one of them is
/// something a person only finds out afterwards otherwise, and the
/// subscription warning is the one that costs money.
class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<AccountCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: DeleteAccountView(
        onManageSubscription: () async {
          // The same customer centre the paywall opens. Cancelling is the
          // store's job, not ours, so this hands the person straight to it.
          await getIt<PaywallCubit>().presentCustomerCenter();
        },
      ),
    );
  }
}

/// The screen itself, taking its cubit from the tree so a test can supply one.
class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({required this.onManageSubscription, super.key});

  final Future<void> Function() onManageSubscription;

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  /// The second deliberate action. Erasing everything is one tap too cheap,
  /// so the button does nothing until this is on.
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountCubit, AccountState>(
      listener: (context, state) {
        if (state.status != AccountStatus.deleted) return;
        // The account screen behind this one is showing an account that no
        // longer exists, so it is rebuilt from scratch on the fresh anonymous
        // account rather than popped back to.
        //
        // The shared topic and incident lists still hold the deleted account's
        // data, so they are refreshed onto the fresh anonymous account now.
        // Leave them alone and the home screen comes back showing topics that
        // are gone.
        unawaited(getIt<TopicsCubit>().refresh());
        unawaited(getIt<IncidentsCubit>().refresh());
        context.go('/settings/account');
      },
      builder: (context, state) {
        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.account_delete_header.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings/account');
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

  /// The third deliberate action. The toggle arms the button, the button
  /// opens this prompt, and the prompt only confirms once the word is typed,
  /// so erasing an account is never a single tap.
  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteConfirmDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    AppHaptics.destructive();
    await context.read<AccountCubit>().deleteAccount();
  }

  Widget _body(BuildContext context, AccountState state) {
    // Self-hosted servers have one operator and no accounts, so there is
    // nothing here to erase. Same gate the account screen uses.
    if (state.status == AccountStatus.loading || !state.isAvailable) {
      return const SizedBox.shrink();
    }
    final colors = context.appColors;

    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.account_delete_intro.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 14,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          AppSectionHeader(LocaleKeys.account_delete_what_goes_title.tr()),
          AppFeatureBullet(
            text: LocaleKeys.account_delete_what_goes_topics.tr(),
          ),
          AppFeatureBullet(
            text: LocaleKeys.account_delete_what_goes_history.tr(),
          ),
          AppFeatureBullet(
            text: LocaleKeys.account_delete_what_goes_devices.tr(),
          ),
          const SizedBox(height: 12),
          AppNote(text: LocaleKeys.account_delete_webhooks.tr()),
          if (state.isPaid) ...[
            const SizedBox(height: 12),
            _SubscriptionWarning(onManage: widget.onManageSubscription),
          ],
          const SizedBox(height: 14),
          Text(
            LocaleKeys.account_delete_cannot_undo.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.crit,
            ),
          ),
          if (state.liveIncidentId != null) ...[
            const SizedBox(height: 12),
            _LiveAlarm(incidentId: state.liveIncidentId!),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            AppNote(text: state.errorMessage!),
          ],
          const SizedBox(height: 14),
          AppToggleRow(
            title: LocaleKeys.account_delete_confirm_toggle.tr(),
            value: _understood,
            onChanged: state.isBusy
                ? null
                : (value) => setState(() => _understood = value),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: LocaleKeys.account_delete_confirm_button.tr(),
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            isLoading: state.isBusy,
            onPressed: _understood
                ? () => unawaited(_confirmAndDelete(context))
                : null,
          ),
        ],
      ),
    );
  }
}

/// The last word. The person has to type it out, so deleting an account can
/// never happen by accident or by mashing through a dialog. The confirm button
/// stays dead until the field matches, case-insensitive.
class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog();

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    final word = LocaleKeys.account_delete_dialog_word.tr();
    final matches = _controller.text.trim().toUpperCase() == word.toUpperCase();
    if (matches != _matches) setState(() => _matches = matches);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final word = LocaleKeys.account_delete_dialog_word.tr();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AppDialog(
        title: LocaleKeys.account_delete_dialog_title.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.account_delete_dialog_body.tr(
                namedArgs: {'word': word},
              ),
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontSize: 14,
                color: colors.ink2,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _controller,
              placeholder: word,
            ),
          ],
        ),
        actions: [
          AppButton(
            label: LocaleKeys.common_cancel.tr(),
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton(
            label: LocaleKeys.account_delete_dialog_confirm.tr(),
            variant: AppButtonVariant.crit,
            size: AppButtonSize.sm,
            onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          ),
        ],
      ),
    );
  }
}

/// A store subscription outlives the account, so this is the one warning on
/// the screen that costs money to miss.
class _SubscriptionWarning extends StatelessWidget {
  const _SubscriptionWarning({required this.onManage});

  final Future<void> Function() onManage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.account_delete_subscription_title.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.account_delete_subscription_body.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: LocaleKeys.account_delete_manage_subscription.tr(),
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            onPressed: () => unawaited(onManage()),
          ),
        ],
      ),
    );
  }
}

/// The 409. Only an open alarm lands here, so there is always something
/// ringing when it shows.
class _LiveAlarm extends StatelessWidget {
  const _LiveAlarm({required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.account_live_incident_title.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.crit,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.account_delete_live_incident_body.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: LocaleKeys.account_live_incident_button.tr(),
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            onPressed: () => context.push('/incidents/$incidentId'),
          ),
        ],
      ),
    );
  }
}
