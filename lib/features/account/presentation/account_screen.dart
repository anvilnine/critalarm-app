import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/constants/legal_links.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/features/account/presentation/widgets/merge_or_fresh_panel.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_actions.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// The key of the white card that holds who is signed in, so a test can
/// tell it from the card of risky actions under it.
const Key accountCardKey = ValueKey('account-card');

/// Who this phone belongs to, and the way in and out: the account part of
/// Settings, Account and plan.
///
/// One titled card holds who is signed in (or the sign-in buttons) and the
/// row to the join code. Under it a card of its own holds Sign out and the
/// row to Delete account, so nothing is reached past to get to them.
///
/// On a self-hosted server there is nothing here: that server has one operator
/// and no accounts to sign in to, so the part is left out rather than shown
/// greyed out. Takes its cubit from the tree.
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountCubit, AccountState>(
      // A sign-in that did not work is worth interrupting for. It used to be
      // a note under the buttons, which reads like a caption rather than a
      // failure, so people carried on thinking the tap had done nothing.
      listenWhen: (previous, current) =>
          current.errorMessage != null &&
          current.errorMessage != previous.errorMessage,
      listener: (context, state) => unawaited(
        _showErrorDialog(context, state.errorMessage!),
      ),
      builder: _body,
    );
  }

  Widget _body(BuildContext context, AccountState state) {
    if (state.status == AccountStatus.loading || !state.isAvailable) {
      return const SizedBox.shrink();
    }
    // The leave panel stays up while its leave is in flight, so the button
    // that was pressed is the one that spins.
    if (state.status == AccountStatus.choosing ||
        (state.isBusy && state.leave != null)) {
      return MergeOrFreshPanel(state: state);
    }
    final cubit = context.read<AccountCubit>();
    // Whether anyone is signed in, not what the screen is busy doing.
    // `working` covers adding a second provider, and keying off the status
    // showed a signed-in person the signed-out pitch for as long as the link
    // took. Every path that signs out clears the identity.
    final signedIn = state.identity != null;
    // Nobody signed in, and the account the phone is on holds an identity.
    // Drawn in the signed-in layout, saying which account it is.
    final unfinished = signedIn ? null : state.unfinished;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTitledCard(
          key: accountCardKey,
          title: LocaleKeys.account_header.tr(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: signedIn || unfinished != null
                  ? _SignedIn(state: state)
                  : _SignedOut(state: state),
            ),
            // Any device on the account may mint a join code, signed in or
            // not, so the row shows either way.
            AppCardRow(
              title: LocaleKeys.account_join_code_header.tr(),
              onTap: () => unawaited(context.push(_joinCodePath)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppTitledCard(
          children: [
            if (signedIn)
              AppCardRow(
                title: LocaleKeys.account_sign_out.tr(),
                isDanger: true,
                showsArrow: false,
                onTap: state.isBusy ? null : () => unawaited(cubit.signOut()),
              ),
            // Where Sign out sits. When the provider cannot run here, the
            // same action is the card's one button instead.
            if (unfinished != null && unfinished.offered)
              AppCardRow(
                title: LocaleKeys.account_use_different_account.tr(),
                showsArrow: false,
                onTap: state.isBusy
                    ? null
                    : () => unawaited(cubit.useDifferentAccount()),
              ),
            // It only leads to the confirm screen. Nothing is erased from
            // here.
            AppCardRow(
              title: LocaleKeys.account_delete_button.tr(),
              isDanger: true,
              onTap: () => unawaited(context.push(_deleteAccountPath)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The join code page: Settings, Account and plan, Join code.
const String _joinCodePath = '/settings/account/join-code';

/// Delete account and its confirm.
const String _deleteAccountPath = '/settings/account/delete';

/// Mint a join code on a page of its own, one level under Account and plan.
class JoinCodeScreen extends StatelessWidget {
  const JoinCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<AccountCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocBuilder<AccountCubit, AccountState>(
        builder: (context, state) => AppScreenScaffold(
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.account_join_code_header.tr(),
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
                child: AppSheet(child: _JoinCode(state: state)),
              ),
            ),
          ],
        ),
      ),
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
        const SizedBox(height: 16),
        // Apple is iOS only. Android gets Google alone, not a dead button.
        if (cubit.supports(IdentityProvider.apple)) ...[
          AppButton(
            label: LocaleKeys.account_sign_in_apple.tr(),
            icon: BrandIcon.apple(color: colors.canvas),
            variant: AppButtonVariant.ink,
            isFullWidth: true,
            isLoading: state.isBusy,
            onPressed: () => unawaited(cubit.signIn(IdentityProvider.apple)),
          ),
          const SizedBox(height: 8),
        ],
        AppButton(
          label: LocaleKeys.account_sign_in_google.tr(),
          icon: const BrandIcon.google(),
          variant: AppButtonVariant.paper,
          isFullWidth: true,
          isLoading: state.isBusy,
          onPressed: () => unawaited(cubit.signIn(IdentityProvider.google)),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: LocaleKeys.account_sign_in_github.tr(),
          icon: BrandIcon.github(color: colors.ink),
          trailingIcon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: colors.ink.withValues(alpha: 0.08),
              borderRadius: Radii.fullAll,
            ),
            child: Text(
              LocaleKeys.account_coming_soon.tr(),
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.ink2,
              ),
            ),
          ),
          variant: AppButtonVariant.paper,
          isFullWidth: true,
        ),
        const SizedBox(height: 14),
        // Apple wants the terms and the privacy policy reachable from the
        // screen that creates an account, not just buried in Settings.
        const _SignInLegalFooter(),
      ],
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final identity = state.identity;
    if (identity == null) return _Unfinished(state: state);
    // Every way in the account holds, not just the one this phone used. A
    // second provider is added by the rows below.
    final names = identity.providers.map(providerName).join(', ');
    final label = identity.providers.length > 1
        ? LocaleKeys.account_providers_label.tr()
        : LocaleKeys.account_provider_label.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardLabel(text: '$label $names'),
        const SizedBox(height: 6),
        // Apple's private relay address is a real address, so it is shown
        // exactly as it came back.
        _CardTitle(
          text: identity.email ?? LocaleKeys.account_email_missing.tr(),
        ),
        const SizedBox(height: 12),
        // Small and selectable, because it is the one thing a support message
        // needs.
        AppKeyValueRow(
          label: LocaleKeys.account_account_id_label.tr(),
          value: identity.accountId,
          showCopyButton: true,
        ),
        _AddProviderRows(state: state),
      ],
    );
  }
}

/// The signed-in layout for a phone whose session is gone: which account it
/// is on, that its alarms still ring, and one way forward.
class _Unfinished extends StatelessWidget {
  const _Unfinished({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();
    final colors = context.appColors;
    final unfinished = state.unfinished!;
    final provider = unfinished.provider;
    final hint = unfinished.emailHidden || unfinished.emailHint == null
        ? LocaleKeys.account_on_account_email_hidden.tr()
        : unfinished.emailHint!;
    final topics = unfinished.topics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardLabel(text: LocaleKeys.account_on_account_label.tr()),
        const SizedBox(height: 6),
        _CardTitle(text: hint),
        if (unfinished.others > 0) ...[
          const SizedBox(height: 2),
          _CardLabel(
            text: LocaleKeys.account_on_account_others.plural(
              unfinished.others,
            ),
          ),
        ],
        if (topics > 0) ...[
          const SizedBox(height: 10),
          Text(
            LocaleKeys.account_on_account_status.tr(
              namedArgs: {
                'topics': LocaleKeys.account_choose_topics.plural(topics),
                // The quiet wording on an iPhone that has no AlarmKit.
                'alarms': state.ringClaim == RingClaim.timeSensitive
                    ? LocaleKeys.account_on_account_alerts_arrive.tr()
                    : LocaleKeys.account_on_account_alarms_ring.tr(),
              },
            ),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (unfinished.offered && provider != null)
          AppButton(
            label: LocaleKeys.account_finish_sign_in.tr(),
            icon: switch (provider) {
              IdentityProvider.apple => BrandIcon.apple(color: colors.canvas),
              IdentityProvider.google => const BrandIcon.google(),
            },
            variant: switch (provider) {
              IdentityProvider.apple => AppButtonVariant.ink,
              IdentityProvider.google => AppButtonVariant.paper,
            },
            isFullWidth: true,
            isLoading: state.isBusy,
            onPressed: () => unawaited(cubit.signIn(provider)),
          )
        else
          // An Apple-only account on Android: its sign-in cannot run here,
          // so another account is the one way forward.
          AppButton(
            label: LocaleKeys.account_use_different_account.tr(),
            variant: AppButtonVariant.paper,
            isFullWidth: true,
            isLoading: state.isBusy,
            onPressed: () => unawaited(cubit.useDifferentAccount()),
          ),
      ],
    );
  }
}

/// The small grey line over the card's main line.
class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.appColors.ink3,
      ),
    );
  }
}

/// The card's main line: the address.
class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: context.appColors.ink,
      ),
    );
  }
}

/// What a provider is called on screen.
/// Puts a failed sign-in in front of the person, then clears it.
///
/// The cubit is read before the dialog opens, because the screen can be gone
/// by the time it closes and a dead context cannot find it.
Future<void> _showErrorDialog(BuildContext context, String message) async {
  final cubit = context.read<AccountCubit>();
  await showAppDialog<void>(
    context: context,
    title: LocaleKeys.account_error_dialog_title.tr(),
    body: message,
    actions: [
      AppDialogAction<void>(label: LocaleKeys.common_close.tr()),
    ],
  );
  cubit.dismissError();
}

String providerName(IdentityProvider provider) => switch (provider) {
  IdentityProvider.apple => LocaleKeys.account_provider_apple.tr(),
  IdentityProvider.google => LocaleKeys.account_provider_google.tr(),
};

/// One button per way in the account does not hold yet.
///
/// Apple is missing from this list on Android, the same way it is missing
/// from the sign-in buttons: the cubit asks whether the platform offers it at
/// all before offering to add it.
class _AddProviderRows extends StatelessWidget {
  const _AddProviderRows({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();
    final colors = context.appColors;
    final addable = cubit.addableProviders;
    if (addable.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 18),
        Text(
          LocaleKeys.account_link_header.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.ink3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          LocaleKeys.account_link_body.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 13,
            color: colors.ink2,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        for (final provider in addable) ...[
          AppButton(
            label: switch (provider) {
              IdentityProvider.apple => LocaleKeys.account_link_add_apple.tr(),
              IdentityProvider.google =>
                LocaleKeys.account_link_add_google.tr(),
            },
            icon: switch (provider) {
              IdentityProvider.apple => BrandIcon.apple(color: colors.ink),
              IdentityProvider.google => const BrandIcon.google(),
            },
            variant: AppButtonVariant.paper,
            isFullWidth: true,
            // One row spins, not the whole screen, so it is obvious which
            // sheet is open.
            isLoading: state.linkingProvider == provider,
            onPressed: state.isBusy
                ? null
                : () => unawaited(cubit.addProvider(provider)),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Mint a join code and show it once.
///
/// The server keeps a hash and not the value, so the reply is the only place
/// the code ever appears. Minting again retires the one before it, which the
/// warning says before the button is pressed rather than after.
class _JoinCode extends StatelessWidget {
  const _JoinCode({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();
    final colors = context.appColors;
    final code = state.joinToken;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LocaleKeys.account_join_code_header.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.ink3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          LocaleKeys.account_join_code_body.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 13,
            color: colors.ink2,
            height: 1.4,
          ),
        ),
        // The one moment the value exists on screen, with the warning beside
        // it rather than on a screen the person has to go back to.
        if (code != null) ...[
          const SizedBox(height: 12),
          AppKeyValueRow(
            label: LocaleKeys.account_join_code_label.tr(),
            value: code,
            trailingFillsRow: true,
            trailing: TokenActions(
              value: code,
              onCopied: (_) => AppHaptics.selection(),
            ),
          ),
          const SizedBox(height: 6),
          AppNote(text: LocaleKeys.account_join_code_shown_once.tr()),
          if (state.hasRetiredAJoinToken) ...[
            const SizedBox(height: 6),
            AppNote(text: LocaleKeys.account_join_code_retired.tr()),
          ],
          // The button is a 36 pill in a 48 tap box: 6 less above it, and 6
          // less of whatever follows it.
          const SizedBox(height: 2),
          AppButton(
            label: LocaleKeys.account_join_code_saved_button.tr(),
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            isFullWidth: true,
            onPressed: cubit.dismissJoinToken,
          ),
        ],
        if (state.joinTokenError != null) ...[
          SizedBox(height: code != null ? 6 : 12),
          AppNote(text: state.joinTokenError!),
        ],
        SizedBox(
          height: code != null && state.joinTokenError == null ? 4 : 10,
        ),
        Text(
          LocaleKeys.account_join_code_retire_warning.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.ink3,
          ),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: state.joinTokenMints > 0
              ? LocaleKeys.account_join_code_again_button.tr()
              : LocaleKeys.account_join_code_button.tr(),
          variant: AppButtonVariant.paper,
          isFullWidth: true,
          isLoading: state.isMintingJoinToken,
          onPressed: () => unawaited(cubit.mintJoinToken()),
        ),
      ],
    );
  }
}

/// "By signing in you agree to the Terms and the Privacy Policy", with the
/// two names tappable. Same open-then-copy behaviour as the About screen's
/// link row: try the in-app browser sheet, and if the platform will not
/// open it, copy the link instead so a tap never does nothing.
class _SignInLegalFooter extends StatelessWidget {
  const _SignInLegalFooter();

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppBrowserView,
      );
    } on Exception {
      opened = false;
    }
    if (!opened) {
      unawaited(Clipboard.setData(ClipboardData(text: url)));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            LocaleKeys.settings_copied_toast.tr(namedArgs: {'url': url}),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textStyle = TextStyle(
      fontFamily: AppTypography.fontBody,
      fontFamilyFallback: AppTypography.fontBodyFallbacks,
      fontSize: 12,
      color: colors.ink3,
    );
    final linkStyle = textStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: colors.ink3,
    );

    final termsLabel = LocaleKeys.account_legal_footer_terms.tr();
    final privacyLabel = LocaleKeys.account_legal_footer_privacy.tr();
    final sentence = LocaleKeys.account_legal_footer.tr(
      namedArgs: {'terms': termsLabel, 'privacy': privacyLabel},
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: buildLegalFooterSpans(
        sentence,
        termsLabel: termsLabel,
        privacyLabel: privacyLabel,
        termsUrl: termsUrl,
        privacyUrl: privacyUrl,
        textStyle: textStyle,
        linkStyle: linkStyle,
        onTapTerms: () => unawaited(_open(context, termsUrl)),
        onTapPrivacy: () => unawaited(_open(context, privacyUrl)),
      ),
    );
  }
}

/// Splits the resolved legal-footer sentence into one widget per piece, in
/// whatever order the two labels actually appear in it.
///
/// A translation can put "Privacy Policy" before "Terms", or word the
/// sentence completely differently, so the split follows the sentence
/// instead of assuming an English word order. If a translation drops one of
/// the placeholders, the plain sentence is shown rather than crashing the
/// sign-in screen.
///
/// Exposed only so a test can prove the order is not hardcoded.
@visibleForTesting
List<Widget> buildLegalFooterSpans(
  String sentence, {
  required String termsLabel,
  required String privacyLabel,
  required String termsUrl,
  required String privacyUrl,
  required TextStyle textStyle,
  required TextStyle linkStyle,
  required VoidCallback onTapTerms,
  required VoidCallback onTapPrivacy,
}) {
  final termsIndex = sentence.indexOf(termsLabel);
  final privacyIndex = sentence.indexOf(privacyLabel);
  if (termsIndex == -1 || privacyIndex == -1) {
    return [Text(sentence, style: textStyle)];
  }

  final termsFirst = termsIndex < privacyIndex;
  final firstLabel = termsFirst ? termsLabel : privacyLabel;
  final firstIndex = termsFirst ? termsIndex : privacyIndex;
  final firstUrl = termsFirst ? termsUrl : privacyUrl;
  final firstTap = termsFirst ? onTapTerms : onTapPrivacy;
  final secondLabel = termsFirst ? privacyLabel : termsLabel;
  final secondIndex = termsFirst ? privacyIndex : termsIndex;
  final secondUrl = termsFirst ? privacyUrl : termsUrl;
  final secondTap = termsFirst ? onTapPrivacy : onTapTerms;

  Widget link(String label, String url, VoidCallback onTap) {
    return Semantics(
      // A link, read once by its name. The raw URL is noise to a listener.
      link: true,
      linkUrl: Uri.tryParse(url),
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: linkStyle),
      ),
    );
  }

  final spans = <Widget>[];
  if (firstIndex > 0) {
    spans.add(Text(sentence.substring(0, firstIndex), style: textStyle));
  }
  spans.add(link(firstLabel, firstUrl, firstTap));
  final middleStart = firstIndex + firstLabel.length;
  if (secondIndex > middleStart) {
    spans.add(
      Text(sentence.substring(middleStart, secondIndex), style: textStyle),
    );
  }
  spans.add(link(secondLabel, secondUrl, secondTap));
  final tailStart = secondIndex + secondLabel.length;
  if (tailStart < sentence.length) {
    spans.add(Text(sentence.substring(tailStart), style: textStyle));
  }
  return spans;
}
