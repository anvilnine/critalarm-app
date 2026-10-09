import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/constants/legal_links.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/pro_ask_sheet.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_replay_rules.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_face.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/topics/domain/count_card_layout.dart';
import 'package:critalarm/features/topics/domain/first_topic_rules.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/features/topics/presentation/formatters/topic_name_formatter.dart';
import 'package:critalarm/features/topics/presentation/widgets/create_topic_face.dart';
import 'package:critalarm/features/topics/presentation/widgets/first_topic_critical_card.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_actions.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_made_beat.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// CreateTopicScreen matching docs/design-system/index.html mobile mockup.
class CreateTopicScreen extends StatelessWidget {
  const CreateTopicScreen({
    this.onDone,
    this.isReplay = false,
    this.initialTool,
    super.key,
  });

  /// The tool chip that starts picked, from `?tool=<id>` on the route. Null
  /// when none is asked for or the id is not one this build knows.
  final ToolTemplate? initialTool;

  /// Called in place of every exit, whether the topic was created or the
  /// screen was closed. Setup passes it to move on to its next step. Null
  /// everywhere else, where the exits pop or open the new topic.
  final VoidCallback? onDone;

  /// A replay of setup: confirming ends the step without making a topic.
  final bool isReplay;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        // Only a setup step hands its new topic on to the steps after it. A
        // replay never makes one.
        final cubit = getIt<CreateTopicCubit>()
          ..holdsHandoff = onDone != null && !isReplay
          // Setup asks for the topic and nothing else: no token-name step.
          ..isOneStep = onDone != null;
        unawaited(cubit.loadConnection());
        final tool = initialTool;
        if (tool != null) cubit.toolTemplateTapped(tool);
        // The shared topic list is already in memory, so a name that is taken
        // can be caught on step 1 instead of by the server after step 2. The
        // first-topic card waits on the list being ready.
        final topics = context.read<TopicsCubit>().state;
        cubit.existingNamesChanged(
          topics.topics.map((topic) => topic.name),
          isListReady: topics.isReady,
        );
        return cubit;
      },
      child: BlocListener<TopicsCubit, TopicsState>(
        listener: (context, topicsState) =>
            context.read<CreateTopicCubit>().existingNamesChanged(
              topicsState.topics.map((topic) => topic.name),
              isListReady: topicsState.isReady,
            ),
        child: _CreateTopicScreenContent(onDone: onDone, isReplay: isReplay),
      ),
    );
  }
}

class _CreateTopicScreenContent extends StatefulWidget {
  const _CreateTopicScreenContent({this.onDone, this.isReplay = false});

  final VoidCallback? onDone;
  final bool isReplay;

  @override
  State<_CreateTopicScreenContent> createState() =>
      _CreateTopicScreenContentState();
}

class _CreateTopicScreenContentState extends State<_CreateTopicScreenContent>
    with WidgetsBindingObserver {
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

  /// This screen is a setup step: one screen, no token-name step and no
  /// created stop.
  bool get _isSetup => widget.onDone != null;

  /// Room a focused field keeps under itself, so it comes to rest above the
  /// pinned button and its links, never behind them.
  static const _fieldScrollPadding = EdgeInsets.fromLTRB(20, 20, 20, 132);

  final ScrollController _scroll = ScrollController();

  /// The keyboard came up or went down. With a field in focus the form is
  /// brought up above the pinned button: the list already leaves room for
  /// the button under its last row, so the end of the list is the place
  /// where the whole form shows.
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
      final isTyping = _nameFocus.hasFocus || _tokenNameFocus.hasFocus;
      if (!hasKeyboard || !isTyping) return;
      final end = _scroll.position.maxScrollExtent;
      if (end <= _scroll.offset) return;
      final duration = context.motion(AppDurations.base);
      if (duration == Duration.zero) {
        _scroll.jumpTo(end);
      } else {
        unawaited(
          _scroll.animateTo(end, duration: duration, curve: AppCurves.easeOut),
        );
      }
    });
  }

  /// The glad face has had its moment and settles.
  bool _faceSettled = false;
  Timer? _settleTimer;

  /// Setup moves on by itself after the topic is made. Guards the button and
  /// the timer from both doing it.
  bool _hasLeftSetup = false;

  void _leaveSetup() {
    if (_hasLeftSetup) return;
    _hasLeftSetup = true;
    widget.onDone?.call();
  }

  /// Setup made the topic and is showing where it lives on Home. The
  /// picture moves setup on when it is over, and a tap moves on at once.
  bool _showsTopicMade = false;

  /// What the topic being made does on screen. In setup the form gives way
  /// to a picture of Home with the new topic in it, and then the screen
  /// moves on, because the next steps show the address and token where
  /// they are used. Anywhere else the face is glad for a beat, then
  /// settles.
  void _onCreated() {
    if (_isSetup) {
      setState(() => _showsTopicMade = true);
      return;
    }
    final beat = context.motion(AppDurations.slow);
    _settleTimer?.cancel();
    _settleTimer = Timer(beat, () {
      if (mounted) setState(() => _faceSettled = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _tokenNameController = TextEditingController();
    _nameFocus = FocusNode();
    _tokenNameFocus = FocusNode();
    WidgetsBinding.instance.addObserver(this);
    // Step 1 is a single field, so open with the keyboard already on it
    // instead of making the user tap it first. Not during a guide, or when
    // this screen's own guide is about to start: it points at the field, and
    // the keyboard would cover the card. Nor on a first topic, where the
    // Critical delivery card sits under the field and the keyboard would hide
    // it.
    unawaited(_focusUnlessFirstTopic());
  }

  /// Opens the keyboard on the name field, except on a first topic.
  ///
  /// Nothing loads the topic list before Home, so a setup run starts with it
  /// not ready. Ask for it and wait a moment: the first-topic card needs it,
  /// and a keyboard that opened first would cover the card. A list that does
  /// not arrive in time leaves the plain row and the keyboard, so nothing
  /// waits on the network.
  Future<void> _focusUnlessFirstTopic() async {
    final topics = context.read<TopicsCubit>();
    if (!topics.state.isReady) {
      try {
        await topics.ensureLoaded().timeout(const Duration(seconds: 2));
      } on Object catch (_) {
        // Not loaded in time. The plain row is drawn.
      }
    }
    if (!mounted) return;
    if (getIt<FeatureGuideCubit>().state.isActive || _isFirstTopicNow()) {
      return;
    }
    _focusNameField();
  }

  /// Whether the shared list is ready and empty right now, so the screen is
  /// about to draw the first-topic card.
  bool _isFirstTopicNow() {
    final topics = context.read<TopicsCubit>().state;
    return isFirstTopicFor(
      existingNames: {
        for (final topic in topics.topics) topic.name.trim().toLowerCase(),
      },
      isListReady: topics.isReady,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _toastTimer?.cancel();
    _settleTimer?.cancel();
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
  Future<void> _askAboutPro(
    BuildContext context,
    HostedAskTrigger trigger,
  ) async {
    if (_hasAskedAboutPro) return;
    _hasAskedAboutPro = true;
    final rules = getIt<ProAskRules>();
    final repository = getIt<InAppNoticeRepository>();
    // A delivered review or feedback reminder counts as an ask before the
    // Pro rules read the ask times.
    await getIt<LocalReminderSettler>().settleAsks(now: DateTime.now());
    if (!await rules.shouldAsk()) return;
    if (!context.mounted) return;
    await showProAskSheet(
      context: context,
      repository: repository,
      trigger: trigger,
    );
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!onboardingCreatesTopic(isReplay: widget.isReplay)) {
      _leaveSetup();
      return;
    }
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

  /// "N of M critical topics used", the same line Settings shows.
  String _criticalUsedText(CreateTopicState state) {
    return LocaleKeys.account_critical_usage.tr(
      namedArgs: {
        'count': '${state.criticalUsed}',
        'limit': '${state.criticalLimit ?? 2}',
      },
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
                          semanticLabel: LocaleKeys
                              .create_topic_confirm_dialog_ask_again
                              .tr(),
                          onChanged: (val) {
                            setDialogState(() {
                              askAgainNextTime = val;
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          // Read through the switch's label.
                          child: ExcludeSemantics(
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
    // The user's first topic gets the Critical delivery card and the tool
    // chips. Every later topic keeps the plain row.
    final isFirstTopic = state.isFirstTopic;
    final claim = RingClaim.forPhone(state.alarm);
    // An iPhone older than iOS 26 has no AlarmKit, so it must not be promised
    // a ring through silent mode.
    final plainSubtitle = claim == RingClaim.timeSensitive
        ? LocaleKeys.create_topic_critical_toggle_subtitle_time_sensitive.tr()
        : LocaleKeys.create_topic_critical_toggle_subtitle.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirstTopic) ...[
          // Locked while a create runs, without changing how the chips are
          // built: a chip with no tap is laid out tighter, and the rows
          // would shift under the user's finger.
          IgnorePointer(
            ignoring: isSubmitting,
            child: _ToolChips(
              selected: state.selectedTool,
              onTap: cubit.toolTemplateTapped,
            ),
          ),
          const SizedBox(height: Spacing.s4),
        ],
        FeatureGuideAnchor(
          id: FeatureGuideAnchorId.createName,
          child: AppTextField(
            label: LocaleKeys.create_topic_name_label.tr(),
            controller: _nameController,
            focusNode: _nameFocus,
            placeholder: LocaleKeys.create_topic_name_placeholder.tr(),
            errorText: state.errorMessage ?? duplicateError,
            enabled: !isSubmitting,
            maxLength: 100,
            scrollPadding: _fieldScrollPadding,
            textInputAction: TextInputAction.done,
            inputFormatters: const [
              TopicNameInputFormatter(),
            ],
            // Nobody on their first topic has a topic name on the clipboard.
            headerTrailing: _isSetup
                ? null
                : AppButton(
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
            // In setup the keyboard's Done only puts the keyboard away: the
            // Critical card is still to be read, and Create is pinned.
            onSubmitted: (_) =>
                _isSetup ? FocusScope.of(context).unfocus() : _next(),
          ),
        ),
        const SizedBox(height: 14),
        FeatureGuideAnchor(
          id: FeatureGuideAnchorId.createCritical,
          child: isFirstTopic
              ? FirstTopicCriticalCard(
                  claim: claim,
                  isCritical: state.isCritical,
                  // Both numbers come from the plan, so the line stays true if
                  // the cap changes. This topic would be the next critical one.
                  plan: state.isFreeTier
                      ? (
                          used: state.criticalUsed + 1,
                          limit: state.criticalLimit ?? 2,
                        )
                      : null,
                  onChanged: isSubmitting ? null : _onCriticalChanged,
                )
              : AppToggleRow(
                  title: LocaleKeys.create_topic_critical_toggle_title.tr(),
                  subtitle: plainSubtitle,
                  value: state.isCritical,
                  onChanged: isSubmitting ? null : _onCriticalChanged,
                ),
        ),
        // On the first topic the card above carries the plan line and the
        // See Hosted plans button waits until a critical topic exists.
        if (state.showsCriticalCountCard) ...[
          const SizedBox(height: 10),
          _criticalCountCard(context, state),
        ],
      ],
    );
  }

  /// The plan count, what Hosted adds, the own-server line and the See Hosted
  /// plans button. At a large text size the row has no room for both, so the
  /// button moves under the text and the words wrap between words.
  Widget _criticalCountCard(BuildContext context, CreateTopicState state) {
    final colors = context.appColors;
    final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _criticalUsedText(state),
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
          HostedBenefit.all
              .firstWhere((b) => b.id == HostedBenefitId.topics)
              .shortKey
              .tr(namedArgs: HostedBenefit.args),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            color: colors.ink3,
          ),
        ),
        if (HostedSurface.createTopicCard.ownServerLine case final line?) ...[
          const SizedBox(height: 2),
          Text(
            line,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 12,
              color: colors.ink3,
            ),
          ),
        ],
      ],
    );
    final button = AppButton(
      label: LocaleKeys.asks_pro_button.tr(),
      variant: AppButtonVariant.ghost,
      size: AppButtonSize.sm,
      onPressed: () {
        AppHaptics.capture();
        unawaited(
          openPaywallForFeature(
            context,
            AppFeature.unlimitedCriticalTopics,
            LockSource.createTopicCard,
          ),
        );
      },
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, box) =>
            countCardStacks(innerWidth: box.maxWidth, textScale: textScale)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  text,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: button),
                ],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 12),
                  button,
                ],
              ),
      ),
    );
  }

  void _onCriticalChanged(bool value) {
    AppHaptics.selection();
    context.read<CreateTopicCubit>().criticalToggled(isCritical: value);
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
          ],
        ),
        const SizedBox(height: 10),
        AppTextField(
          label: LocaleKeys.create_topic_token_name_label.tr(),
          controller: _tokenNameController,
          focusNode: _tokenNameFocus,
          placeholder: LocaleKeys.create_topic_token_name_placeholder.tr(),
          // No errorText here. A failed create is always about the topic, and
          // the cubit sends the user back to step 1 so the message sits under
          // the topic name field.
          enabled: !isSubmitting,
          isMono: false,
          maxLength: 40,
          scrollPadding: _fieldScrollPadding,
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
      // Only on a change of status, or a name the field does not hold yet (a
      // tool chip filled it), so typing after a failed create does not drag
      // the caret back to the end of the name on every keystroke.
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          (previous.name != current.name &&
              current.name != _nameController.text),
      listener: (context, state) {
        if (state.name != _nameController.text) {
          _nameController.value = TextEditingValue(
            text: state.name,
            selection: TextSelection.collapsed(offset: state.name.length),
          );
        }
        if (_isSetup) {
          // The small face beside the setup tracker is worried after a
          // failed create. Back is held while the topic is being made and
          // once it exists: there is no going back behind a topic.
          OnboardingAmbientScope.maybeOf(context)
            ?..setFaceMood(
              state.status == CreateTopicStatus.failure
                  ? TravellingFaceMood.worried
                  : null,
            )
            ..holdBack(
              isHeld:
                  state.status == CreateTopicStatus.submitting ||
                  state.status == CreateTopicStatus.success,
            );
        }
        if (state.status == CreateTopicStatus.success) {
          AppHaptics.success();
          final created = LocaleKeys.create_topic_toast_created.tr();
          if (_isSetup) {
            // The screen is about to move on, so a toast would only flash.
            // The face says it, and a screen reader hears it.
            unawaited(
              SemanticsService.sendAnnouncement(
                View.of(context),
                created,
                Directionality.of(context),
              ),
            );
          } else {
            _showToast(created);
          }
          _onCreated();
          // One critical topic left on the free plan. The user is closer to
          // the wall than they may know, so this is a fair time to mention
          // it, after the topic they came for is safely made. Never in
          // setup, which shows no ask.
          if (!_isSetup && state.isFreeTier && state.criticalRemaining == 1) {
            unawaited(_askAboutPro(context, HostedAskTrigger.lastCriticalUsed));
          }
        }
        // Hitting the limit is the one moment the user is actually thinking
        // about limits, so it is the moment worth asking about Pro. Only the
        // critical topic cap: a device or daily cap is a different problem
        // and Pro is not the answer to it.
        if (state.capReached?.name == 'critical_topics') {
          // Just bought Pro and the server has not heard yet. Asking them to
          // buy it again would be wrong, so say it is on its way.
          if (state.isPlanConfirming) {
            _showToast(LocaleKeys.create_topic_toast_pro_pending.tr());
          } else if (!_isSetup) {
            unawaited(_askAboutPro(context, HostedAskTrigger.capRefused));
          }
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
        final isSetup = _isSetup;
        final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

        final isSubmitting = state.status == CreateTopicStatus.submitting;
        final isSuccess = state.status == CreateTopicStatus.success;
        final isTokenStep = state.step == CreateTopicStep.token;
        final face = createTopicFace(
          hasError: state.errorMessage != null,
          isCreated: isSuccess,
          hasSettled: _faceSettled,
          isCritical: state.isCritical,
        );
        final stepKey = ValueKey<CreateTopicStep>(state.step);
        // Duration.zero under reduce motion, so the step swaps instead of
        // sliding. Same flag the ambient canvas below is handed.
        final stepDuration = context.motion(AppDurations.base);
        // Nothing to do with a name the app already knows is taken.
        final isNameTaken = !isSuccess && !isTokenStep && state.isDuplicateName;
        // Setup has no created stop: the picture of Home takes the form's
        // place for a beat and the screen moves on.
        final showsForm = !isSuccess || isSetup;
        final showsCreated = token != null && !isSetup;
        // The step where the topic gets made is the one with something to
        // agree to.
        final showsLegal = !isSuccess && (isSetup || isTokenStep);
        // Setup made the topic: the form and the button give way to the
        // picture of Home, which is all there is to look at for that beat.
        final madeTopic = isSetup && _showsTopicMade
            ? state.createdTopic
            : null;
        if (madeTopic != null) {
          return AmbientOverride(
            profile: AmbientAppProfiles.createTopic(colors),
            direction: AmbientDirection.push,
            child: Semantics(
              button: true,
              label: LocaleKeys.onboarding_welcome_continue.tr(),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                // A tap anywhere skips the picture.
                onTap: _leaveSetup,
                child: AppScreenScaffold(
                  hasTabBar: false,
                  topBar: AppTopBar(title: setupTopBarTitle(context)),
                  slivers: [
                    SliverToBoxAdapter(
                      child: TopicMadeBeat(
                        topicName: madeTopic.name,
                        ringsThroughSilent: madeTopic.critical,
                        onDone: _leaveSetup,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // The system back button and the back gesture do what the top bar's
        // Back does: on step 2 they return to step 1 with everything typed
        // still there. Once the topic exists the form is over, so back leaves
        // the screen like it does on step 1.
        final canPop = !isTokenStep || isSuccess;

        void close() {
          if (isSetup) {
            _leaveSetup();
            return;
          }
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
        }

        final button = AppButton(
          label: switch ((isSuccess && !isSetup, isTokenStep || isSetup)) {
            (true, _) => LocaleKeys.create_topic_done_button.tr(),
            (false, true) => LocaleKeys.create_topic_create_button.tr(),
            (false, false) => LocaleKeys.create_topic_next_button.tr(),
          },
          size: isSetup ? AppButtonSize.lg : AppButtonSize.md,
          isFullWidth: true,
          // In setup the button keeps spinning through the glad beat, so
          // it cannot be tapped twice on the way out.
          isLoading: isSubmitting || (isSetup && isSuccess),
          onPressed: isNameTaken
              ? null
              : () {
                  AppHaptics.capture();
                  if (isSuccess) {
                    close();
                  } else if (isTokenStep || isSetup) {
                    _submit();
                  } else {
                    _next();
                  }
                },
        );

        final content = PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            // Something else on the page can hold the pop too, such as Back
            // in setup. This one only acts when it is the one holding it.
            if (didPop || canPop) return;
            cubit.previousStep();
            _focusNameField();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: AppScreenScaffold(
              hasTabBar: false,
              resizeForKeyboard: true,
              scrollController: _scroll,
              topBar: AppTopBar(
                // In setup the top bar reads like every other step's, and
                // the title sits under the face.
                title: isSetup
                    ? setupTopBarTitle(context)
                    : LocaleKeys.create_topic_title.tr(),
                // With the keyboard up the big face makes room for the form.
                // It moves up here, smaller, so a worried face after a
                // failed create and the glad one after a good one are
                // still seen. While the setup tracker is up there, its own
                // small face does that and no second one is drawn.
                leading:
                    isSetup &&
                        hasKeyboard &&
                        !OnboardingAmbientScope.showsTrackerOf(context)
                    ? ExcludeSemantics(
                        child: FaceWidget(state: face, size: 32, isLive: true),
                      )
                    : isTokenStep && !isSuccess
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
                // Setup has no way out of this step but making the topic.
                trailing: isSetup
                    ? null
                    : AppIconButton(
                        glyph: GlyphType.close,
                        ariaLabel: LocaleKeys.create_topic_cancel_aria_label
                            .tr(),
                        onPressed: close,
                      ),
              ),
              // Pinned, so the button is at one height in every state and
              // stays above the keyboard.
              bottomBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_toast case final message?) ...[
                    AppToast(message: message),
                    const SizedBox(height: Spacing.s2),
                  ],
                  FeatureGuideAnchor(
                    id: FeatureGuideAnchorId.createButton,
                    child: button,
                  ),
                  if (showsLegal)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.s2),
                      // A wrap, so the second link drops to its own line at a
                      // large text size instead of running off the edge.
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        children: [
                          _LegalLink(
                            label: LocaleKeys.create_topic_terms_link.tr(),
                            url: termsUrl,
                          ),
                          _LegalLink(
                            label: LocaleKeys.create_topic_privacy_link.tr(),
                            url: privacyUrl,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              slivers: [
                if (isSetup)
                  SliverToBoxAdapter(
                    // With the keyboard up there is room for the form or
                    // for the face and title, not both, and the form is
                    // what the user is typing into.
                    child: AnimatedSize(
                      duration: stepDuration,
                      curve: AppCurves.easeOut,
                      alignment: Alignment.topCenter,
                      child: hasKeyboard
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Spacing.s5,
                                Spacing.s4,
                                Spacing.s5,
                                0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // The face every setup step shares, so
                                  // it flies in from the step before. It
                                  // shrinks and goes with a large text size.
                                  SetupFace(state: face, gap: Spacing.s4),
                                  Semantics(
                                    header: true,
                                    child: AppFittedTitle(
                                      LocaleKeys.create_topic_first_topic_title
                                          .tr(),
                                      minFontSize: setupTitleMinFontSize,
                                      style: AppTypography.headline(
                                        colors.onCanvas,
                                        fontSize: 30,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: AppStage(
                      faceState: face,
                      faceSize: 110,
                      isLive: true,
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        Spacing.s3,
                        24,
                        0,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    // Tighter with the keyboard up in setup, where every
                    // point decides whether the form fits above the button.
                    padding: isSetup && hasKeyboard
                        ? const EdgeInsets.fromLTRB(12, 0, 12, Spacing.s1)
                        : const EdgeInsets.fromLTRB(12, Spacing.s4, 12, 16),
                    child: AppSheet(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.capReached != null)
                            AppEmptyState(
                              title: state.capReached!.message,
                              description: LocaleKeys
                                  .create_topic_limit_review_plan_hint
                                  .tr(),
                              showFace: false,
                            ),
                          // One step needs no counter.
                          if (showsForm && !isSetup) ...[
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
                          if (showsForm)
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
                          if (showsCreated) ...[
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
                      ),
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

        return AmbientOverride(
          profile: profile,
          direction: AmbientDirection.push,
          child: content,
        );
      },
    );
  }
}

/// The tools a first topic is usually set up for. A tap fills the name and
/// remembers the tool, and it never opens a sheet.
class _ToolChips extends StatelessWidget {
  const _ToolChips({required this.selected, required this.onTap});

  final ToolTemplate? selected;
  final ValueChanged<ToolTemplate>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onTap = this.onTap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LocaleKeys.create_topic_tool_chips_label.tr(),
          style: AppTypography.small(
            colors.ink3,
            fontSize: 12,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            // No chip for "something else": picking none already means it.
            for (final template in ToolTemplate.values)
              if (template.label case final label?)
                AppTopicChip(
                  // Tool names are product names and stay as they are.
                  text: label,
                  isSelected: template == selected,
                  // With the slop above and below, two rows sit 8 apart.
                  hitSlop: 4,
                  onTap: onTap == null ? null : () => onTap(template),
                ),
          ],
        ),
      ],
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
      // A link, read once by its name. The raw URL is noise to a listener.
      link: true,
      linkUrl: Uri.tryParse(url),
      label: label,
      excludeSemantics: true,
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
