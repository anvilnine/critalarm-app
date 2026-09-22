import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/constants/legal_links.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/prompts/domain/pro_prompt_rules.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/widgets/pro_prompt_sheet.dart';
import 'package:critalarm/features/reminders/domain/reminder_settler.dart';
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
      create: (context) {
        final cubit = getIt<CreateTopicCubit>();
        unawaited(cubit.loadConnection());
        // The shared topic list is already in memory, so a name that is taken
        // can be caught on step 1 instead of by the server after step 2.
        cubit.existingNamesChanged(
          context.read<TopicsCubit>().state.topics.map((topic) => topic.name),
        );
        return cubit;
      },
      child: BlocListener<TopicsCubit, TopicsState>(
        listener: (context, topicsState) =>
            context.read<CreateTopicCubit>().existingNamesChanged(
              topicsState.topics.map((topic) => topic.name),
            ),
        child: const _CreateTopicScreenContent(),
      ),
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
  late final TextEditingController _tokenNameController;

  /// One field per step, so the keyboard never has to come down between them.
  late final FocusNode _nameFocus;
  late final FocusNode _tokenNameFocus;

  /// Shown just above the pinned button, in the layout rather than floating
  /// over it. A SnackBar is a Material idea and lands on top of the button
  /// the user is reaching for.
  String? _toast;
  Timer? _toastTimer;

  /// The cubit reports the refused create on every rebuild, so remember that
  /// the sheet already went up and do not stack a second one.
  bool _hasAskedAboutPro = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _tokenNameController = TextEditingController();
    _nameFocus = FocusNode();
    _tokenNameFocus = FocusNode();
    // Step 1 is a single field, so open with the keyboard already on it
    // instead of making the user tap it first.
    _focusNameField();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _nameController.dispose();
    _tokenNameController.dispose();
    _nameFocus.dispose();
    _tokenNameFocus.dispose();
    super.dispose();
  }

  /// Moves focus once the frame that builds the field has run.
  ///
  /// The steps swap through an AnimatedSwitcher, so the field being focused
  /// is not in the tree yet at the moment the step changes. Waiting for the
  /// frame works whether the swap animates or, under reduce motion, takes
  /// zero time.
  void _focusAfterBuild(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || node.context == null) return;
      node.requestFocus();
    });
  }

  /// Focus the topic name field with the caret after the text already there,
  /// so coming back to a typed name carries on from the end rather than
  /// jumping to the front.
  void _focusNameField() {
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );
    _focusAfterBuild(_nameFocus);
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// Asked once per refusal, and only if the rules say this user still wants
  /// to hear it. Somebody who already pays, or who has said no twice, never
  /// sees it.
  Future<void> _askAboutPro(BuildContext context) async {
    if (_hasAskedAboutPro) return;
    _hasAskedAboutPro = true;
    final rules = getIt<ProPromptRules>();
    final repository = getIt<HomePromptRepository>();
    // A delivered review or feedback reminder counts as an ask before the
    // Pro rules read the ask times.
    await getIt<ReminderSettler>().settleAsks(now: DateTime.now());
    if (!await rules.shouldAsk()) return;
    if (!context.mounted) return;
    await showProPromptSheet(context: context, repository: repository);
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    unawaited(context.read<CreateTopicCubit>().createTopic());
  }

  /// Step 1 to step 2. No network call: the topic is created on step 2.
  void _next() {
    final cubit = context.read<CreateTopicCubit>()..nextStep();
    if (cubit.state.step == CreateTopicStep.token) {
      // Both steps are one text field, so the keyboard stays up and moves to
      // the new field.
      _focusAfterBuild(_tokenNameFocus);
    } else {
      // nextStep turned the name down. Put the keyboard back on the field
      // that has to be fixed.
      _focusNameField();
    }
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

  /// Step 1: the topic name, the critical toggle and the free tier note.
  Widget _topicStepBody(BuildContext context, CreateTopicState state) {
    final colors = context.appColors;
    final cubit = context.read<CreateTopicCubit>();
    final isSubmitting = state.status == CreateTopicStatus.submitting;
    // The typed name matches a topic the app already holds. Say so here, so
    // the user is not told about it by the server after filling in step 2.
    final duplicateError = state.isDuplicateName
        ? LocaleKeys.api_errors_topic_already_exists.tr()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TourAnchor(
          id: TourAnchorId.createName,
          child: AppTextField(
            label: LocaleKeys.create_topic_name_label.tr(),
            controller: _nameController,
            focusNode: _nameFocus,
            placeholder: LocaleKeys.create_topic_name_placeholder.tr(),
            helperText: LocaleKeys.create_topic_name_helper.tr(),
            errorText: state.errorMessage ?? duplicateError,
            enabled: !isSubmitting,
            maxLength: 100,
            textInputAction: TextInputAction.done,
            inputFormatters: const [
              TopicNameInputFormatter(),
            ],
            headerTrailing: AppButton(
              label: LocaleKeys.create_topic_paste_button.tr(),
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
            onSubmitted: (_) => _next(),
          ),
        ),
        const SizedBox(height: 14),
        TourAnchor(
          id: TourAnchorId.createCritical,
          child: AppToggleRow(
            title: LocaleKeys.create_topic_critical_toggle_title.tr(),
            // An iPhone older than iOS 26 has no AlarmKit, so it must not be
            // promised a ring through silent mode.
            subtitle:
                RingClaim.forPhone(state.alarm) == RingClaim.timeSensitive
                ? LocaleKeys
                      .create_topic_critical_toggle_subtitle_time_sensitive
                      .tr()
                : LocaleKeys.create_topic_critical_toggle_subtitle.tr(),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _criticalRemainingText(state),
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocaleKeys.create_topic_free_tier_pro_hint.tr(),
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontSize: 12,
                          color: colors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: LocaleKeys.create_topic_go_pro_button.tr(),
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
    );
  }

  /// Step 2: what to call the first token.
  Widget _tokenStepBody(BuildContext context, CreateTopicState state) {
    final colors = context.appColors;
    final cubit = context.read<CreateTopicCubit>();
    final isSubmitting = state.status == CreateTopicStatus.submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // What step 1 holds, so the topic this token belongs to is still on
        // screen. A reminder, not a control: the top bar already has Back.
        Row(
          children: [
            Text(
              LocaleKeys.create_topic_token_recap_label.tr(),
              style: AppTypography.small(colors.ink3, fontSize: 12),
            ),
            const SizedBox(width: 6),
            // A name runs to 64 characters. It shrinks and ellipsizes so it
            // stays on one line and the card does not grow under it.
            Flexible(
              child: Text(
                state.name.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono(colors.ink2, fontSize: 12),
              ),
            ),
            // Only when it is on. Off is the default, so saying so every time
            // is noise; on is the thing worth remembering.
            if (state.isCritical) ...[
              const SizedBox(width: 8),
              Text(
                LocaleKeys.create_topic_token_recap_critical.tr(),
                style: AppTypography.small(colors.crit, fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        AppTextField(
          label: LocaleKeys.create_topic_token_name_label.tr(),
          controller: _tokenNameController,
          focusNode: _tokenNameFocus,
          placeholder: LocaleKeys.create_topic_token_name_placeholder.tr(),
          helperText: LocaleKeys.create_topic_token_name_helper.tr(),
          // No errorText here. A failed create is always about the topic, and
          // the cubit sends the user back to step 1 so the message sits under
          // the topic name field.
          enabled: !isSubmitting,
          isMono: false,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          onChanged: cubit.tokenNameChanged,
          onSubmitted: (_) => _handleEnterSubmit(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<CreateTopicCubit, CreateTopicState>(
      // Only on a change of status, so typing after a failed create does not
      // drag the caret back to the end of the name on every keystroke.
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CreateTopicStatus.success) {
          AppHaptics.success();
          _showToast(
            '${LocaleKeys.create_topic_toast_created.tr()} ${state.name}',
          );
          // One critical topic left on the free plan. The user is closer to
          // the wall than they may know, so this is a fair time to mention
          // it, after the topic they came for is safely made.
          if (state.isFreeTier && state.criticalRemaining == 1) {
            unawaited(_askAboutPro(context));
          }
        }
        // Hitting the limit is the one moment the user is actually thinking
        // about limits, so it is the moment worth asking about Pro. Only the
        // critical topic cap: a device or daily cap is a different problem
        // and Pro is not the answer to it.
        if (state.capReached?.name == 'critical_topics') {
          unawaited(_askAboutPro(context));
        }
        if (state.status == CreateTopicStatus.failure) {
          // A failed create sends the user back to step 1 with the message
          // under the topic name field. Focus it, so the keyboard is up on
          // the field they have to fix.
          _focusNameField();
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
        final isTokenStep = state.step == CreateTopicStep.token;
        final stepKey = ValueKey<CreateTopicStep>(state.step);
        // Duration.zero under reduce motion, so the step swaps instead of
        // sliding. Same flag the ambient canvas below is handed.
        final stepDuration = context.motion(AppDurations.base);
        // Nothing to do on step 2 with a name the app already knows is taken.
        final isNameTaken = !isSuccess && !isTokenStep && state.isDuplicateName;

        // The system back button and the back gesture do what the top bar's
        // Back does: on step 2 they return to step 1 with everything typed
        // still there. Once the topic exists the form is over, so back leaves
        // the screen like it does on step 1.
        final canPop = !isTokenStep || isSuccess;

        final content = PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            cubit.previousStep();
            _focusNameField();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: AppScreenScaffold(
              hasTabBar: false,
              resizeForKeyboard: true,
              topBar: AppTopBar(
                title: LocaleKeys.create_topic_title.tr(),
                leading: isTokenStep && !isSuccess
                    ? AppIconButton(
                        glyph: GlyphType.back,
                        ariaLabel: LocaleKeys.create_topic_back_aria_label.tr(),
                        onPressed: () {
                          cubit.previousStep();
                          // Step 1 is one field too, so the keyboard moves back
                          // to it instead of coming down.
                          _focusNameField();
                        },
                      )
                    : null,
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
                      label: switch ((isSuccess, isTokenStep)) {
                        (true, _) => 'Done',
                        (false, true) =>
                          LocaleKeys.create_topic_create_button.tr(),
                        (false, false) =>
                          LocaleKeys.create_topic_next_button.tr(),
                      },
                      isFullWidth: true,
                      isLoading: isSubmitting,
                      onPressed: isNameTaken
                          ? null
                          : () {
                              AppHaptics.capture();
                              if (isSuccess) {
                                final name = state.createdTopic!.name;
                                if (context.canPop()) {
                                  context.pop();
                                  unawaited(context.push('/topics/$name'));
                                } else {
                                  context.go('/topics/$name');
                                }
                              } else if (isTokenStep) {
                                _submit();
                              } else {
                                _next();
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
                            Text(
                              LocaleKeys.create_topic_step_label.tr(
                                namedArgs: {
                                  'current': isTokenStep ? '2' : '1',
                                  'total': '2',
                                },
                              ),
                              style: TextStyle(
                                fontFamily: AppTypography.fontBody,
                                fontFamilyFallback:
                                    AppTypography.fontBodyFallbacks,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.ink3,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!isSuccess)
                            AnimatedSize(
                              duration: stepDuration,
                              curve: AppCurves.easeOut,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: stepDuration,
                                switchInCurve: AppCurves.easeOut,
                                switchOutCurve: AppCurves.easeOut,
                                layoutBuilder:
                                    (currentChild, previousChildren) => Stack(
                                      alignment: Alignment.topLeft,
                                      children: [
                                        ...previousChildren,
                                        ?currentChild,
                                      ],
                                    ),
                                transitionBuilder: (child, animation) {
                                  // Next slides the new step in from the right
                                  // and the old one out to the left. Back runs
                                  // the other way, so the movement matches the
                                  // travel.
                                  final isIncoming = child.key == stepKey;
                                  final fromRight = isTokenStep == isIncoming;
                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(
                                        fromRight ? 0.12 : -0.12,
                                        0,
                                      ),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  key: stepKey,
                                  width: double.infinity,
                                  child: isTokenStep
                                      ? _tokenStepBody(context, state)
                                      : _topicStepBody(context, state),
                                ),
                              ),
                            ),
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
                            if (state.createdTopic?.tokenName
                                case final tokenName?
                                when tokenName.isNotEmpty) ...[
                              Text(
                                tokenName,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontBody,
                                  fontFamilyFallback:
                                      AppTypography.fontBodyFallbacks,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
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
          ),
        );

        // A different profile per step, so the canvas drifts the background
        // along with the card instead of holding still.
        final profile = AmbientAppProfiles.createTopic(
          colors,
          step: isTokenStep ? 2 : 1,
        );

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
