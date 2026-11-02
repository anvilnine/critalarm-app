part of 'create_topic_screen.dart';

// The sections the create screen's `build` is made of. Each one takes what it
// draws as constructor arguments. The state, the controllers and the cubit
// calls stay in `_CreateTopicScreenContentState`.

/// Setup made the topic: the picture of Home with the new topic in it, which
/// is all there is to look at for that beat. A tap anywhere skips it.
class _TopicMadePicture extends StatelessWidget {
  const _TopicMadePicture({required this.topic, required this.onDone});

  final Topic topic;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: LocaleKeys.onboarding_welcome_continue.tr(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // A tap anywhere skips the picture.
        onTap: onDone,
        child: AppScreenScaffold(
          hasTabBar: false,
          topBar: AppTopBar(title: setupTopBarTitle(context)),
          slivers: [
            SliverToBoxAdapter(
              child: TopicMadeBeat(
                topicName: topic.name,
                ringsThroughSilent: topic.critical,
                onDone: onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one button: Next on step 1, Create on step 2 and in setup, Done once
/// the topic exists.
class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.isSuccess,
    required this.isSetup,
    required this.isTokenStep,
    required this.isSubmitting,
    required this.isNameTaken,
    required this.onClose,
    required this.onSubmit,
    required this.onNext,
  });

  final bool isSuccess;
  final bool isSetup;
  final bool isTokenStep;
  final bool isSubmitting;
  final bool isNameTaken;
  final VoidCallback onClose;
  final VoidCallback onSubmit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return AppButton(
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
                onClose();
              } else if (isTokenStep || isSetup) {
                onSubmit();
              } else {
                onNext();
              }
            },
    );
  }
}

/// The face and what names the step. In setup it gives way to the form when
/// the keyboard is up, unless it has a pane of its own.
class _CreateStage extends StatelessWidget {
  const _CreateStage({
    required this.isSetup,
    required this.face,
    required this.frame,
    required this.faceBase,
    required this.stepDuration,
    required this.givesWayToForm,
  });

  final bool isSetup;
  final FaceState face;
  final ScreenFrame frame;

  /// The setup face's size, read in the page's context. Unused outside setup.
  final double faceBase;
  final Duration stepDuration;

  /// Setup only: the keyboard is up and the face has no pane of its own, so
  /// the form takes the room.
  final bool givesWayToForm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return isSetup
        ? AnimatedSize(
            duration: stepDuration,
            curve: AppCurves.easeOut,
            alignment: Alignment.topCenter,
            child: givesWayToForm
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
                        SetupFace(
                          state: face,
                          gap: Spacing.s4,
                          base: faceBase,
                        ),
                        Semantics(
                          header: true,
                          child: AppFittedTitle(
                            LocaleKeys.create_topic_first_topic_title.tr(),
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
          )
        : AppStage(
            faceState: face,
            faceSize: 110,
            isLive: true,
            // The cover is 388 tall: the face sits right under the top
            // bar, so the name field is whole on screen at rest.
            padding: EdgeInsets.fromLTRB(
              24,
              frame == ScreenFrame.cover ? 0 : Spacing.s3,
              24,
              0,
            ),
          );
  }
}

/// Step 1 of 2.
class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.isTokenStep});

  final bool isTokenStep;

  @override
  Widget build(BuildContext context) {
    return Text(
      LocaleKeys.create_topic_step_label.tr(
        namedArgs: {'current': isTokenStep ? '2' : '1', 'total': '2'},
      ),
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

/// The card the steps live in: the cap notice, the step counter, the step
/// that is showing, and once the topic exists the endpoint and its token.
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.state,
    required this.token,
    required this.stepKey,
    required this.stepDuration,
    required this.isSetup,
    required this.isTokenStep,
    required this.showsForm,
    required this.splits,
    required this.frame,
    required this.hasKeyboard,
    required this.onCopied,
    required this.stepBody,
  });

  final CreateTopicState state;
  final String? token;
  final ValueKey<CreateTopicStep> stepKey;
  final Duration stepDuration;
  final bool isSetup;
  final bool isTokenStep;
  final bool showsForm;
  final bool splits;
  final ScreenFrame frame;
  final bool hasKeyboard;
  final void Function(String message) onCopied;

  /// The body of the step that is showing. Null once the form is gone.
  final Widget? stepBody;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final token = this.token;

    return Padding(
      // Tighter with the keyboard up in setup, where every
      // point decides whether the form fits above the button.
      padding: isSetup && hasKeyboard
          ? const EdgeInsets.fromLTRB(12, 0, 12, Spacing.s1)
          : EdgeInsets.fromLTRB(
              12,
              frame == ScreenFrame.cover ? Spacing.s2 : Spacing.s4,
              12,
              16,
            ),
      child: AppSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.capReached != null)
              AppEmptyState(
                title: state.capReached!.message,
                description: LocaleKeys.create_topic_limit_review_plan_hint
                    .tr(),
                showFace: false,
              ),
            // One step needs no counter.
            if (showsForm && !isSetup && !splits) ...[
              _StepLabel(isTokenStep: isTokenStep),
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
                  layoutBuilder: (currentChild, previousChildren) => Stack(
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
                    child: stepBody,
                  ),
                ),
              ),
            if (token != null && !isSetup) ...[
              Text(
                LocaleKeys.create_topic_generated_label.tr(),
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.ink3,
                ),
              ),
              const SizedBox(height: 8),
              if (state.serverUrl.isNotEmpty) ...[
                AppKeyValueRow(
                  value: '${state.serverUrl}/${state.name}',
                  trailingFillsRow: true,
                  trailing: TokenActions(
                    value: '${state.serverUrl}/${state.name}',
                    onCopied: onCopied,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (state.createdTopic?.tokenName case final tokenName?
                  when tokenName.isNotEmpty) ...[
                Text(
                  tokenName,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              AppKeyValueRow(
                value: token,
                trailingFillsRow: true,
                trailing: TokenActions(
                  value: token,
                  onCopied: onCopied,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                LocaleKeys.create_topic_token_warning.tr(),
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.ink3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The button, the toast above it and the legal line under it. Pinned to the
/// bottom, or right under the form on a wide window.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.toast,
    required this.button,
    required this.showsLegal,
    required this.isSetup,
    required this.isPinned,
  });

  final String? toast;
  final Widget button;
  final bool showsLegal;
  final bool isSetup;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (toast case final message?) ...[
          AppToast(message: message),
          const SizedBox(height: Spacing.s2),
        ],
        FeatureGuideAnchor(
          id: FeatureGuideAnchorId.createButton,
          child: button,
        ),
        // Pinned under the button where the topic is made in two
        // steps. Setup puts it at the end of the page instead: a
        // line of small text pinned over a page that scrolls has
        // the rows behind it showing through. Under the form, both
        // keep it under the button.
        if (showsLegal && (!isSetup || !isPinned))
          const Padding(
            padding: EdgeInsets.only(top: Spacing.s2),
            child: _LegalLinks(),
          ),
      ],
    );
  }
}

/// The top bar: the title, Back on step 2, the close cross, and in setup the
/// small face while the keyboard has the big one's room.
class _CreateTopBar extends StatelessWidget {
  const _CreateTopBar({
    required this.isSetup,
    required this.isTokenStep,
    required this.isSuccess,
    required this.face,
    required this.showsSmallFace,
    required this.onBack,
    required this.onClose,
  });

  final bool isSetup;
  final bool isTokenStep;
  final bool isSuccess;
  final FaceState face;
  final bool showsSmallFace;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppTopBar(
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
      leading: showsSmallFace
          ? ExcludeSemantics(
              child: FaceWidget(state: face, size: 32, isLive: true),
            )
          : isTokenStep && !isSuccess
          ? AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.create_topic_back_aria_label.tr(),
              onPressed: onBack,
            )
          : null,
      // Setup has no way out of this step but making the topic.
      trailing: isSetup
          ? null
          // The house close: a bare x, no circle.
          : AppDismissCross(
              label: LocaleKeys.create_topic_cancel_aria_label.tr(),
              color: context.appColors.onCanvas,
              tapSize: kMinTapTarget,
              onPressed: onClose,
            ),
      // The cross sits where the old 40 circle sat in its 48 box.
      trailingTapRoom: isSetup ? null : AppIconButton.tapRoom(40),
    );
  }
}

/// The page around the form: back handling, tap-away to drop the keyboard,
/// and the scaffold with its pinned button.
class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    required this.canPop,
    required this.onStepBack,
    required this.scroll,
    required this.topBar,
    required this.bottomBar,
    required this.foldStage,
    required this.slivers,
  });

  final bool canPop;

  /// Back on step 2: the previous step, with the name field focused.
  final VoidCallback onStepBack;
  final ScrollController scroll;
  final Widget topBar;
  final Widget? bottomBar;
  final Widget? foldStage;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        // Something else on the page can hold the pop too, such as Back
        // in setup. This one only acts when it is the one holding it.
        if (didPop || canPop) return;
        onStepBack();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: AppScreenScaffold(
          hasTabBar: false,
          resizeForKeyboard: true,
          scrollController: scroll,
          topBar: topBar,
          bottomBar: bottomBar,
          foldStage: foldStage,
          slivers: slivers,
        ),
      ),
    );
  }
}

/// The stage pane of a half-open foldable: the face and the step stay put in
/// one pane and the form scrolls in the other.
class _FoldStage extends StatelessWidget {
  const _FoldStage({
    required this.isSetup,
    required this.showsStepLabel,
    required this.face,
    required this.stage,
    required this.isTokenStep,
  });

  final bool isSetup;
  final bool showsStepLabel;
  final FaceState face;
  final Widget stage;
  final bool isTokenStep;

  @override
  Widget build(BuildContext context) {
    return FoldStageBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The face on its own: a half is too short for
          // the stage, which would put it beside its words.
          if (isSetup) stage else FaceWidget(state: face, isLive: true),
          if (showsStepLabel) ...[
            const SizedBox(height: Spacing.s3),
            _StepLabel(isTokenStep: isTokenStep),
          ],
        ],
      ),
    );
  }
}

/// A tablet or desktop window: the stage, the form and (when it fits) the
/// button as one group, centred in the window.
class _CentredGroup extends StatelessWidget {
  const _CentredGroup({
    required this.isCentred,
    required this.onAvailable,
    required this.onFormSize,
    required this.onActionsSize,
    required this.stage,
    required this.formCard,
    required this.inlineActions,
  });

  final bool isCentred;
  final ValueChanged<double> onAvailable;
  final ValueChanged<Size> onFormSize;
  final ValueChanged<Size> onActionsSize;

  /// Null when the stage is in a pane of its own.
  final Widget? stage;
  final Widget formCard;

  /// The button under the form, or null when it is pinned instead.
  final Widget? inlineActions;

  @override
  Widget build(BuildContext context) {
    return CentredGroupSliver(
      isCentred: isCentred,
      onAvailable: onAvailable,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReportSize(
            onSize: onFormSize,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [?stage, formCard],
            ),
          ),
          if (inlineActions case final actions?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                _CreateTopicScreenContentState._actionsGap,
                12,
                0,
              ),
              child: ReportSize(
                onSize: onActionsSize,
                child: InlineActions(child: actions),
              ),
            ),
        ],
      ),
    );
  }
}

/// The button under the form, where a pinned one would sit on the form.
class _FlowingActions extends StatelessWidget {
  const _FlowingActions({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        _CreateTopicScreenContentState._actionsGap,
        12,
        0,
      ),
      child: InlineActions(child: child),
    );
  }
}
