import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/constants/legal_links.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/features/topics/presentation/formatters/topic_name_formatter.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_actions.dart';
import 'package:critalarm/features/tour/presentation/tour_anchor.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// CreateTopicScreen matching docs/design-system/index.html mobile mockup.
class CreateTopicScreen extends StatelessWidget {
  const CreateTopicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<CreateTopicCubit>();
        unawaited(cubit.loadConnection());
        return cubit;
      },
      child: const _CreateTopicScreenContent(),
    );
  }
}

class _CreateTopicScreenContent extends StatefulWidget {
  const _CreateTopicScreenContent();

  @override
  State<_CreateTopicScreenContent> createState() =>
      _CreateTopicScreenContentState();
}

class _CreateTopicScreenContentState extends State<_CreateTopicScreenContent> {
  static const String _prefAskAgainOnEnter = 'create_topic_ask_again_on_enter';

  late final TextEditingController _nameController;

  /// Shown just above the pinned button, in the layout rather than floating
  /// over it. A SnackBar is a Material idea and lands on top of the button
  /// the user is reaching for.
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    unawaited(context.read<CreateTopicCubit>().createTopic());
  }

  String _criticalRemainingText(CreateTopicState state) {
    final limit = state.criticalLimit ?? 2;
    final remaining = state.criticalRemaining;
    if (remaining != null && remaining > 0) {
      return LocaleKeys.create_topic_free_tier_critical_remaining.tr(
        namedArgs: {'remaining': '$remaining', 'limit': '$limit'},
      );
    }
    return LocaleKeys.create_topic_free_tier_critical_exhausted.tr(
      namedArgs: {'limit': '$limit'},
    );
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) return;

    const formatter = TopicNameInputFormatter();
    final formatted = formatter.formatEditUpdate(
      TextEditingValue(text: _nameController.text),
      TextEditingValue(
        text: raw,
        selection: TextSelection.collapsed(offset: raw.length),
      ),
    );

    _nameController.value = formatted;
    if (mounted) {
      context.read<CreateTopicCubit>().nameChanged(formatted.text);
    }
  }

  Future<void> _handleEnterSubmit() async {
    final cubit = context.read<CreateTopicCubit>();
    final state = cubit.state;
    if (state.status == CreateTopicStatus.submitting ||
        state.status == CreateTopicStatus.success) {
      return;
    }

    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      _submit();
      return;
    }

    final prefs = getIt<SharedPreferences>();
    final shouldAsk = prefs.getBool(_prefAskAgainOnEnter) ?? true;

    if (!shouldAsk) {
      _submit();
      return;
    }

    var askAgainNextTime = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        final colors = dialogContext.appColors;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return _ConfirmDialog(
              title: LocaleKeys.create_topic_confirm_dialog_title.tr(),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LocaleKeys.create_topic_confirm_dialog_message.tr(
                      namedArgs: {'name': trimmed},
                    ),
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 14,
                      height: 1.45,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setDialogState(() {
                        askAgainNextTime = !askAgainNextTime;
                      });
                    },
                    child: Row(
                      children: [
                        AppSwitch(
                          value: askAgainNextTime,
                          onChanged: (val) {
                            setDialogState(() {
                              askAgainNextTime = val;
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            LocaleKeys.create_topic_confirm_dialog_ask_again
                                .tr(),
                            style: TextStyle(
                              fontFamily: AppTypography.fontBody,
                              fontFamilyFallback:
                                  AppTypography.fontBodyFallbacks,
                              fontSize: 13,
                              color: colors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              cancelLabel: LocaleKeys.common_cancel.tr(),
              confirmLabel: LocaleKeys.create_topic_create_button.tr(),
              onCancel: () => Navigator.of(dialogContext).pop(false),
              onConfirm: () => Navigator.of(dialogContext).pop(true),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await prefs.setBool(_prefAskAgainOnEnter, askAgainNextTime);
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<CreateTopicCubit, CreateTopicState>(
      listener: (context, state) {
        if (state.status == CreateTopicStatus.success) {
          AppHaptics.success();
          _showToast(
            '${LocaleKeys.create_topic_toast_created.tr()} ${state.name}',
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<CreateTopicCubit>();
        final token = state.createdToken;
        final stageFace = state.errorMessage != null
            ? FaceState.worried
            : FaceState.watching;

        final isSubmitting = state.status == CreateTopicStatus.submitting;
        final isSuccess = state.status == CreateTopicStatus.success;

        final content = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: AppScreenScaffold(
            hasTabBar: false,
            resizeForKeyboard: true,
            topBar: AppTopBar(
              title: LocaleKeys.create_topic_title.tr(),
              trailing: AppIconButton(
                glyph: GlyphType.close,
                ariaLabel: LocaleKeys.create_topic_cancel_aria_label.tr(),
                onPressed: () {
                  final created = state.createdTopic;
                  if (created != null) {
                    if (context.canPop()) {
                      context.pop();
                      unawaited(context.push('/topics/${created.name}'));
                    } else {
                      context.go('/topics/${created.name}');
                    }
                    return;
                  }
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            ),
            bottomBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_toast case final message?) ...[
                  AppToast(message: message),
                  const SizedBox(height: Spacing.s2),
                ],
                TourAnchor(
                  id: TourAnchorId.createButton,
                  child: AppButton(
                    label: isSuccess
                        ? 'Done'
                        : LocaleKeys.create_topic_create_button.tr(),
                    isFullWidth: true,
                    isLoading: isSubmitting,
                    onPressed: () {
                      AppHaptics.capture();
                      if (isSuccess) {
                        final name = state.createdTopic!.name;
                        if (context.canPop()) {
                          context.pop();
                          unawaited(context.push('/topics/$name'));
                        } else {
                          context.go('/topics/$name');
                        }
                      } else {
                        _submit();
                      }
                    },
                  ),
                ),
              ],
            ),
            slivers: [
              SliverToBoxAdapter(
                child: AppStage(
                  faceState: stageFace,
                  faceSize: 110,
                  isLive: true,
                  padding: const EdgeInsets.fromLTRB(24, Spacing.s3, 24, 0),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, Spacing.s4, 12, 16),
                  child: AppSheet(
                    border: Border.all(color: colors.hairline, width: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.capReached != null)
                          AppEmptyState(
                            title: state.capReached!.message,
                            description:
                                'Review your plan to increase this limit.',
                            buttonLabel: null,
                            showFace: false,
                          ),
                        if (!isSuccess) ...[
                          TourAnchor(
                            id: TourAnchorId.createName,
                            child: AppTextField(
                              label: LocaleKeys.create_topic_name_label.tr(),
                              controller: _nameController,
                              placeholder: LocaleKeys
                                  .create_topic_name_placeholder
                                  .tr(),
                              helperText: LocaleKeys.create_topic_name_helper
                                  .tr(),
                              errorText: state.errorMessage,
                              enabled: !isSubmitting,
                              maxLength: 100,
                              textInputAction: TextInputAction.done,
                              inputFormatters: const [
                                TopicNameInputFormatter(),
                              ],
                              headerTrailing: AppButton(
                                label: LocaleKeys.create_topic_paste_button
                                    .tr(),
                                size: AppButtonSize.sm,
                                variant: AppButtonVariant.paper,
                                icon: AppGlyph(
                                  GlyphType.copy,
                                  size: 13,
                                  color: colors.ink,
                                ),
                                onPressed: isSubmitting ? null : _handlePaste,
                              ),
                              onChanged: cubit.nameChanged,
                              onSubmitted: (_) => _handleEnterSubmit(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TourAnchor(
                            id: TourAnchorId.createCritical,
                            child: AppToggleRow(
                              title: LocaleKeys
                                  .create_topic_critical_toggle_title
                                  .tr(),
                              subtitle: LocaleKeys
                                  .create_topic_critical_toggle_subtitle
                                  .tr(),
                              value: state.isCritical,
                              onChanged: isSubmitting
                                  ? null
                                  : (val) {
                                      AppHaptics.selection();
                                      cubit.criticalToggled(isCritical: val);
                                    },
                            ),
                          ),
                          if (state.isFreeTier) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colors.cream,
                                borderRadius: Radii.mdAll,
                                border: Border.all(color: colors.hairline),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _criticalRemainingText(state),
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontBody,
                                            fontFamilyFallback:
                                                AppTypography.fontBodyFallbacks,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          LocaleKeys
                                              .create_topic_free_tier_pro_hint
                                              .tr(),
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontBody,
                                            fontFamilyFallback:
                                                AppTypography.fontBodyFallbacks,
                                            fontSize: 12,
                                            color: colors.ink3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AppButton(
                                    label: LocaleKeys.create_topic_go_pro_button
                                        .tr(),
                                    size: AppButtonSize.sm,
                                    onPressed: () {
                                      AppHaptics.capture();
                                      unawaited(context.push('/paywall'));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        if (token != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            LocaleKeys.create_topic_generated_label.tr(),
                            style: TextStyle(
                              fontFamily: AppTypography.fontBody,
                              fontFamilyFallback:
                                  AppTypography.fontBodyFallbacks,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.ink3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (state.serverUrl.isNotEmpty) ...[
                            AppKeyValueRow(
                              value: '${state.serverUrl}/${state.name}',
                              trailing: TokenActions(
                                value: '${state.serverUrl}/${state.name}',
                                onCopied: _showToast,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          AppKeyValueRow(
                            value: token,
                            trailing: TokenActions(
                              value: token,
                              onCopied: _showToast,
                            ),
                          ),
                          ...[
                            const SizedBox(height: 6),
                            Text(
                              LocaleKeys.create_topic_token_warning.tr(),
                              style: TextStyle(
                                fontFamily: AppTypography.fontBody,
                                fontFamilyFallback:
                                    AppTypography.fontBodyFallbacks,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.ink3,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegalLink(
                        label: LocaleKeys.create_topic_terms_link.tr(),
                        url: termsUrl,
                      ),
                      const SizedBox(width: 16),
                      _LegalLink(
                        label: LocaleKeys.create_topic_privacy_link.tr(),
                        url: privacyUrl,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        final profile = AmbientAppProfiles.createTopic(colors);

        return AmbientScope(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: AmbientCanvas(
                    key: const ValueKey('create-topic-ambient-canvas'),
                    profile: profile,
                    direction: AmbientDirection.push,
                    variant: AmbientMotionVariant.drift,
                    reduceMotion: context.reduceMotion,
                  ),
                ),
              ),
              Positioned.fill(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: '$label: $url',
      button: true,
      child: GestureDetector(
        onTap: () => unawaited(
          launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            color: colors.ink3,
            decoration: TextDecoration.underline,
            decorationColor: colors.ink3,
          ),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final Widget content;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            boxShadow: AppShadows.shadowLg(isDark: isDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.02 * 20,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 12),
              content,
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: cancelLabel,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: onCancel,
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: confirmLabel,
                    size: AppButtonSize.sm,
                    onPressed: onConfirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
