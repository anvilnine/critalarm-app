import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_morph.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_privacy_line.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_routes.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/connect_morph_layout.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/connect_routes_picture.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/local_test_alarm_views.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_face.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_tap_room.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Which of the two setup steps in this file a route shows.
enum OnboardingConnectPart {
  /// Pick Crit Alarm Cloud or your own server. Done once a server answers.
  connect,

  /// Connected, ready to run the local test alarm.
  test,
}

/// Two setup steps, each on its own route: the server connection
/// (/onboarding/connect) and the local test alarm of the first shipped
/// order (/onboarding/test), which Health also opens on its own.
class OnboardingConnectScreen extends StatelessWidget {
  const OnboardingConnectScreen({
    this.part = OnboardingConnectPart.connect,
    this.cameBack = false,
    super.key,
  });

  final OnboardingConnectPart part;

  /// Opened by Back from a later step. The screen then shows the server the
  /// user picked and waits, instead of moving on because one is saved.
  final bool cameBack;

  @override
  Widget build(BuildContext context) {
    final isTest = part == OnboardingConnectPart.test;
    final isReplay = isOnboardingReplay(context);
    // A replay connects to nothing, so it has no choice to show.
    final showsChoice = cameBack && !isTest && !isReplay;
    return BlocProvider(
      create: (_) {
        final cubit = getIt<OnboardingConnectCubit>(param1: isTest);
        // A replay of the connect step is a look at the form, so a server
        // that is already saved does not move it on.
        unawaited(
          cubit
              .loadConnection(
                adoptSavedConnection: isTest || !isReplay,
                isReplay: isReplay,
              )
              .then((_) {
                if (showsChoice) return cubit.followPendingConnect();
              }),
        );
        return cubit;
      },
      child: _OnboardingConnectView(
        isTest: isTest,
        isReplay: isReplay,
        showsChoice: showsChoice,
      ),
    );
  }
}

class _OnboardingConnectView extends StatefulWidget {
  const _OnboardingConnectView({
    required this.isTest,
    required this.isReplay,
    required this.showsChoice,
  });

  final bool isTest;

  /// Opened from Settings to look at the screens. Nothing is saved, so the
  /// connect buttons move on without connecting.
  final bool isReplay;

  /// The user came back to this step: a server that is saved, or on its
  /// way, is shown with a way to change it.
  final bool showsChoice;

  @override
  State<_OnboardingConnectView> createState() => _OnboardingConnectViewState();
}

class _OnboardingConnectViewState extends State<_OnboardingConnectView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;

  /// How far the step has moved from Crit Alarm Cloud (0) to your own server
  /// (1). The picture, the titles, the card and the pinned bar all follow
  /// this one number, so the switch reads as one layout changing.
  late final AnimationController _morph;

  /// Switches the user asked for that the listener has not seen yet. A form
  /// restored from the last visit changes the same state without one, and
  /// comes up already open.
  int _askedSwitches = 0;

  /// The face every setup step shares, so it flies between them and stays
  /// put from the form to the check to the answer.
  static const _faceHeroTag = 'onboarding-face';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cubit = context.read<OnboardingConnectCubit>();
    _morph = AnimationController(
      vsync: this,
      duration: AppDurations.base,
      value: cubit.state.isSelfHosting ? 1 : 0,
    );
    _urlController = TextEditingController(text: cubit.state.serverUrl);
    _tokenController = TextEditingController(text: cubit.state.adminToken);
    unawaited(_checkConnectivity());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAmbientStep();
    });
  }

  void _syncAmbientStep() {
    final cubit = context.read<OnboardingConnectCubit>();
    final ambient = OnboardingAmbientScope.maybeOf(context);
    if (ambient == null) return;
    if (!widget.isTest) {
      ambient.setStep(OnboardingAmbientStep.connect);
    } else if (cubit.state.isCountingDown) {
      ambient.setStep(OnboardingAmbientStep.countdown);
    } else {
      ambient.setStep(OnboardingAmbientStep.connected);
    }
  }

  /// Coming back to the app is the usual moment someone has just turned wifi
  /// back on, so look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_checkConnectivity());
  }

  Timer? _connectivityRetryTimer;

  /// Asks Crit Alarm Cloud for its `/v1/info`. The one answer says whether
  /// the phone is online and which privacy line is true. Never blocks
  /// anything.
  Future<void> _checkConnectivity() async {
    _connectivityRetryTimer?.cancel();
    // The test step shows neither the offline card nor the line.
    if (widget.isTest) return;
    final cubit = context.read<OnboardingConnectCubit>();
    await cubit.probeCloud();
    if (!mounted) return;
    if (cubit.state.cloudOnline == false) {
      _connectivityRetryTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) unawaited(_checkConnectivity());
      });
    }
  }

  @override
  void dispose() {
    _connectivityRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _morph.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  /// The toggle in the pinned bar. Closes the keyboard when it leaves the
  /// form, so the field does not keep it open behind the Cloud card.
  void _toggleServer() {
    final cubit = context.read<OnboardingConnectCubit>();
    if (cubit.state.isSelfHosting) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _askedSwitches++;
    cubit.toggleSelfHosting();
  }

  /// Moves the layout to the state the cubit now holds. A new switch in the
  /// middle of one turns it around from where it is, so they never stack.
  void _followServerChoice(bool isSelfHosting) {
    final target = isSelfHosting ? 1.0 : 0.0;
    final userAsked = _askedSwitches > 0;
    if (userAsked) _askedSwitches--;
    if (!connectMorphPlays(
      userAsked: userAsked,
      reduceMotion: context.reduceMotion,
    )) {
      _morph.value = target;
      return;
    }
    unawaited(_morph.animateTo(target, curve: AppCurves.easeOut));
  }

  bool _connectStepFinished = false;

  /// [skippedItself] when the step moved on because a server was already
  /// saved, with nothing for the user to do. Back never opens it then.
  void _finishConnectStep({bool skippedItself = false}) {
    if (_connectStepFinished) return;
    _connectStepFinished = true;
    unawaited(
      finishOnboardingStep(
        context,
        OnboardingStepId.connect,
        skippedItself: skippedItself,
      ),
    );
  }

  /// True until the user asks for a different server. While it is, a saved
  /// server does not move the step on by itself.
  late bool _keepsChoice = widget.showsChoice;
  bool _isChangingServer = false;

  /// The last try to drop the server failed, so it is still the one saved.
  bool _changeServerFailed = false;

  /// Whether the screen is showing the server the user already picked: one
  /// that is connected, or Crit Alarm Cloud while its connect is on the way.
  bool _showsChoice(OnboardingConnectState state) =>
      _keepsChoice &&
      state.confirmation == null &&
      (state.isConnected ||
          (state.isConnecting && state.cloudWaitLine != null));

  /// Use a different server. Drops the one that is there, then the two
  /// choices show as they did the first time.
  Future<void> _changeServer() async {
    if (_isChangingServer) return;
    setState(() {
      _isChangingServer = true;
      _changeServerFailed = false;
    });
    var hasChanged = false;
    try {
      await context.read<OnboardingConnectCubit>().changeServer();
      hasChanged = true;
    } on Object {
      // The server is still saved. The line under it says so.
    } finally {
      if (mounted) {
        setState(() {
          _isChangingServer = false;
          _keepsChoice = !hasChanged;
          _changeServerFailed = !hasChanged;
        });
      }
    }
    if (mounted && hasChanged) unawaited(_checkConnectivity());
  }

  /// Continue with Crit Alarm Cloud. The connect is handed over to run
  /// behind the user and the step is done at once, online or not.
  ///
  /// Opened on its own after setup, from Home or Server settings, there is
  /// no next step: the screen waits with the user and closes when the
  /// connect lands, so whatever opened it reads the new connection.
  Future<void> _continueWithCloud() async {
    final opensOnItsOwn = context.canPop();
    await context.read<OnboardingConnectCubit>().connectToCloud(
      waitForResult: opensOnItsOwn,
    );
    if (mounted && !opensOnItsOwn) _finishConnectStep();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _tokenController.text = text;
      if (mounted) {
        context.read<OnboardingConnectCubit>().pasteToken(text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<OnboardingConnectCubit, OnboardingConnectState>(
          listenWhen: (prev, curr) =>
              prev.testAlarmStatus != curr.testAlarmStatus &&
              curr.isAlarmFailure,
          listener: (context, state) =>
              unawaited(explainLocalTestAlarmFailure(context, state.alarm)),
        ),
        BlocListener<OnboardingConnectCubit, OnboardingConnectState>(
          listenWhen: (prev, curr) => prev.isSelfHosting != curr.isSelfHosting,
          listener: (context, state) =>
              _followServerChoice(state.isSelfHosting),
        ),
      ],
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return BlocConsumer<OnboardingConnectCubit, OnboardingConnectState>(
      listenWhen: (prev, curr) =>
          (!prev.canNavigateToHome && curr.canNavigateToHome) ||
          (!prev.canLaunchDemoAlarm && curr.canLaunchDemoAlarm) ||
          prev.isConnected != curr.isConnected ||
          prev.isConnecting != curr.isConnecting ||
          prev.isCountingDown != curr.isCountingDown,
      listener: (context, state) {
        final cubit = context.read<OnboardingConnectCubit>();
        // The small face beside the tracker watches while a server is being
        // connected.
        OnboardingAmbientScope.maybeOf(context)?.setFaceMood(
          state.isConnecting ? TravellingFaceMood.watching : null,
        );
        if (state.canNavigateToHome) {
          cubit.navigationHandled();
          context.go('/');
          return;
        } else if (state.canLaunchDemoAlarm && widget.isTest) {
          cubit.demoAlarmHandled();
          // The demo alarm is a step forward in onboarding, not a detour, so
          // it replaces this screen. Pushing left it swipe-back-able into a
          // test the user has already run.
          context.go('/incidents/inc_demo');
          return;
        }
        if (!widget.isTest) {
          // A server answered, so this step is done. The flow says what
          // comes next; this screen no longer turns into the test. A server
          // the user typed by hand first shows that it worked, and waits
          // for Continue. So does the server of a user who came back here.
          if (state.isConnected &&
              state.confirmation == null &&
              !_keepsChoice) {
            _finishConnectStep(skippedItself: true);
          }
          return;
        }
        final ambient = OnboardingAmbientScope.maybeOf(context);
        if (ambient != null) {
          if (state.isCountingDown) {
            ambient.setStep(
              OnboardingAmbientStep.countdown,
              AmbientDirection.push,
            );
          } else {
            ambient.setStep(OnboardingAmbientStep.connected);
          }
        }
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingConnectCubit>();

        // connectToCloud writes the cloud URL into state. Without this the
        // field still showed whatever the user had typed, and the next tap
        // silently connected somewhere else.
        if (_urlController.text != state.serverUrl) {
          _urlController.text = state.serverUrl;
        }
        if (_tokenController.text != state.adminToken) {
          _tokenController.text = state.adminToken;
        }

        final isTest = widget.isTest;
        final showsChoice = _showsChoice(state);
        // Cloud and your own server share one layout while the user picks, and
        // it changes from one to the other. Every other state (connected, the
        // address being checked, the test alarm) has a layout of its own.
        final isPick =
            !isTest &&
            state.confirmation == null &&
            !showsChoice &&
            !(state.isSelfHosting && state.isConnecting);

        // What the pinned bar takes off the bottom of the viewport is its own
        // buttons, the 12 the scaffold puts under them, and the home
        // indicator. AppButton is lg 60, md 48, sm 36, and each grows once
        // its label does.
        final scale = setupTextScaleOf(context);
        final smButton = setupButtonHeightFor(
          minHeight: 36,
          fontSize: 14,
          textScale: scale,
        );
        final lgButton = setupButtonHeightFor(
          minHeight: 60,
          fontSize: 19,
          textScale: scale,
        );
        // The cloud bar is the self-host toggle plus the text button.
        final cloudBarButtons =
            smButton +
            4 +
            setupButtonHeightFor(
              minHeight: 36,
              fontSize: 15 * 1.3,
              textScale: scale,
              verticalPadding: 0,
            );
        // lg + Spacing.s3 + sm, on both the connected bar and the
        // self-hosted form's Connect + "use the cloud instead" pair.
        final ownBarButtons = lgButton + 12 + smButton;

        return AppScreenScaffold(
          // Still while the card fits above the buttons. At a large text
          // size the card outgrows the room, and then the page scrolls
          // instead of putting the card out of reach.
          physics: isPick && !state.isSelfHosting
              ? const ClampingScrollPhysics()
              : null,
          // The picking column fills the screen and keeps the room for the
          // buttons itself, so the list adds none on top of it.
          bodyClearsBottomBar: isPick,
          backgroundColor: Colors.transparent,
          withGhosts: false,
          withFades: false,
          hasTabBar: false,
          resizeForKeyboard: true,
          topBar: AppTopBar(
            title: setupTopBarTitle(context),
            // In a setup run the shell draws Back. Opened from Settings the
            // screen sits on top of it, and Back returns there.
            leading: context.canPop()
                ? AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: LocaleKeys.common_back.tr(),
                    onPressed: context.pop,
                  )
                : null,
          ),
          bottomBar: isTest
              ? _buildHookBottomBar(context, state, cubit)
              : isPick
              ? _buildPickBottomBar(context, state, cubit)
              : _buildConnectBottomBar(context, state, cubit),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s5,
                Spacing.s4,
                Spacing.s5,
                0,
              ),
              // The scaffold leaves room for the pinned bar under the list,
              // but a sliver that fills the viewport measures itself against
              // the whole viewport and ignores anything that comes after it,
              // so the picking column carries that room itself.
              //
              // It fills the viewport so the Cloud card can sit at the bottom,
              // within thumb reach, and still scroll once the content
              // outgrows it. The other states run top down as usual.
              sliver: isPick
                  ? SliverLayoutBuilder(
                      builder: (context, constraints) => SliverToBoxAdapter(
                        child: _buildPickBody(
                          context,
                          state,
                          cubit,
                          minHeight:
                              constraints.viewportMainAxisExtent -
                              constraints.precedingScrollExtent,
                          cloudBarButtons: cloudBarButtons,
                          ownBarButtons: ownBarButtons,
                        ),
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: isTest
                          ? _buildHookTestState(context, state, cubit)
                          : _buildConnectOptions(context, state, cubit),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// The states that are not a pick: the server answered, the user came
  /// back to it, or the address is being checked.
  Widget _buildConnectOptions(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final confirmation = state.confirmation;
    if (confirmation != null) {
      return _buildSelfHostConfirmation(context, confirmation);
    }
    if (_showsChoice(state)) return _buildCurrentChoice(context, state, cubit);
    // The address is being checked. The face waits with the user and one
    // line says what is going on.
    return Center(
      child: AppWaitingFace(
        message: LocaleKeys.onboarding_connect_self_host_connecting.tr(
          namedArgs: {'host': cubit.typedHost},
        ),
        faceSize: SetupFace.waitingSizeOf(context),
        heroTag: _faceHeroTag,
      ),
    );
  }

  /// Picking a server: Crit Alarm Cloud or your own. One column serves both.
  /// The picture, the card and the pinned bar stay mounted and follow
  /// [_morph]. What only one of them has (the title over the Cloud card, the
  /// title over the form) grows and shrinks in place.
  Widget _buildPickBody(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit, {
    required double minHeight,
    required double cloudBarButtons,
    required double ownBarButtons,
  }) {
    final colors = context.appColors;
    final heroFull = ConnectRoutesHeader.heightFor(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final fadeOut = ReverseAnimation(_morph);

    // Built once for a state. The column below only moves them.
    final children = <Widget>[
      // The Cloud state's title, over the picture. Gone in the other.
      _Reveal(
        progress: fadeOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.onboarding_connect_title.tr(),
              style: AppTypography.display(colors.onCanvas, fontSize: 32),
            ),
            const SizedBox(height: Spacing.s4),
          ],
        ),
      ),
      // The two routes an alert can take. The lit one follows the choice,
      // and the picture grows or shrinks as the form opens and closes.
      ConnectStepRoutes(
        state: state,
        background: cubit.backgroundConnect,
        fadesIn: true,
      ),
      AnimatedBuilder(
        animation: _morph,
        // The own server state has no gap under a picture that is not there.
        builder: (context, _) => SizedBox(
          height: heroFull == 0 ? Spacing.s4 * (1 - _morph.value) : Spacing.s4,
        ),
      ),
      // The own server state's title, under the picture. Gone in the other.
      _Reveal(
        progress: _morph,
        child: Column(
          children: [
            Center(
              child: AppFittedTitle(
                LocaleKeys.onboarding_connect_self_host_title.tr(),
                minFontSize: setupTitleMinFontSize,
                style: AppTypography.headline(colors.onCanvas, fontSize: 30),
              ),
            ),
            const SizedBox(height: Spacing.s5),
          ],
        ),
      ),
      // Says why a tap is about to fail, without stopping the user taking
      // it. Onboarding never blocks on the network.
      _ConnectNotices(
        isOffline: state.cloudOnline == false,
        errorMessage: state.errorMessage,
      ),
      _buildPickCard(context, state, cubit),
    ];

    return AnimatedBuilder(
      animation: _morph,
      builder: (context, _) {
        final own = _morph.value;
        final bar = connectMorphBarButtons(
          own: own,
          cloud: cloudBarButtons,
          ownServer: ownBarButtons,
        );
        return ConnectMorphLayout(
          own: own,
          heroIndex: 1,
          heroBase: connectMorphHeroBase(own: own, full: heroFull),
          minHeight: minHeight,
          // The pinned bar, the 12 the scaffold puts under it, the home
          // indicator, and the 12 the body keeps clear above the bar.
          bottomRoom: bar + 12 + bottomInset + 12,
          children: children,
        );
      },
    );
  }

  /// The card of the pick: one sheet whose face is the Cloud card or the
  /// address and token form. Both faces stay laid out, the card is as tall as
  /// the one that shows, and its colour follows too.
  Widget _buildPickCard(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;
    final cloudFace = _MorphFace(
      morph: _morph,
      opacityAt: (own) => connectMorphFades(own).cloud,
      isActiveAt: (own) => own < 0.5,
      child: _buildCloudCard(context, state),
    );
    final ownFace = _MorphFace(
      morph: _morph,
      opacityAt: (own) => connectMorphFades(own).own,
      isActiveAt: (own) => own >= 0.5,
      child: _buildOwnServerForm(context, state, cubit),
    );
    return AnimatedBuilder(
      animation: _morph,
      builder: (context, _) => AppSheet(
        color: Color.lerp(
          colors.surface.withValues(alpha: 0.88),
          colors.surface,
          _morph.value,
        ),
        child: ConnectMorphCross(
          own: _morph.value,
          children: [cloudFace, ownFace],
        ),
      ),
    );
  }

  /// Crit Alarm Cloud as the primary card.
  Widget _buildCloudCard(BuildContext context, OnboardingConnectState state) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The badge drops under the title when the title is too wide for
        // both, as it is at a large text size.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            // Title left and badge right while both fit.
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                LocaleKeys.onboarding_connect_cloud_title.tr(),
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: colors.ink,
                ),
              ),
              AppBadge(
                text: LocaleKeys.onboarding_connect_cloud_badge.tr(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          LocaleKeys.onboarding_connect_cloud_description.tr(),
          style: AppTypography.body(colors.ink2, fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (state.isConnecting)
          // Only when the screen was opened on its own: it waits here, with
          // the face and one line, until the connect lands.
          Center(
            child: AppWaitingFace(
              message: state.cloudWaitLine ?? '',
              faceSize: 56,
            ),
          )
        else
          AppButton(
            label: LocaleKeys.onboarding_connect_cloud_button.tr(),
            size: AppButtonSize.lg,
            isFullWidth: true,
            onPressed: widget.isReplay
                ? _finishConnectStep
                : _continueWithCloud,
          ),
        // What the push relay sees, in the words the Cloud's own answer
        // supports, as the small print of the choice it belongs to. Its room
        // is kept, so the card does not jump when the answer arrives.
        _PrivacyLine(line: state.cloudPrivacyLine),
      ],
    );
  }

  /// The address and the token in one card, like every other form in the
  /// app. Paste sits in the token field's own header.
  Widget _buildOwnServerForm(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          label: LocaleKeys.onboarding_connect_url_label.tr(),
          controller: _urlController,
          placeholder: 'https://api.critalarm.app',
          errorText: state.serverUrlError,
          // A long address wraps onto a second line rather than scrolling
          // out of sight, so the user can check what they typed.
          growToFit: true,
          onChanged: cubit.serverUrlChanged,
          onSubmitted: (_) =>
              widget.isReplay ? _finishConnectStep() : cubit.connect(),
        ),
        const SizedBox(height: Spacing.s4),
        AppTextField(
          label: LocaleKeys.onboarding_connect_admin_token_label.tr(),
          headerTrailing: AppButton(
            label: LocaleKeys.onboarding_connect_paste_button.tr(),
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            icon: AppGlyph(GlyphType.copy, size: 13, color: colors.ink),
            onPressed: _handlePaste,
          ),
          controller: _tokenController,
          placeholder: LocaleKeys.onboarding_connect_admin_token_placeholder
              .tr(),
          helperText: LocaleKeys.onboarding_connect_admin_token_helper.tr(),
          errorText: state.adminTokenError,
          growToFit: true,
          onChanged: cubit.adminTokenChanged,
          onSubmitted: (_) =>
              widget.isReplay ? _finishConnectStep() : cubit.connect(),
        ),
      ],
    );
  }

  /// The user's own server answered: its host, the privacy line its answer
  /// supports, and nothing else. Continue is in the pinned bar.
  Widget _buildSelfHostConfirmation(
    BuildContext context,
    ConnectConfirmation confirmation,
  ) {
    final colors = context.appColors;
    final line = confirmation.privacyLine;
    final connected = LocaleKeys.onboarding_connect_self_host_connected_title
        .tr();
    return Column(
      children: [
        // The route through the user's own server, drawn connected.
        const ConnectRoutesHeader(
          view: (
            lit: ConnectRoute.ownServer,
            status: ConnectRouteStatus.connected,
          ),
        ),
        Semantics(
          liveRegion: true,
          // Read as one: "Connected, alerts.example.com".
          label: '$connected, ${confirmation.host}',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppFittedTitle(
                  connected,
                  minFontSize: setupTitleMinFontSize,
                  style: AppTypography.headline(colors.onCanvas, fontSize: 30),
                ),
                const SizedBox(height: Spacing.s2),
                // A host is a machine string, so it is set in mono.
                Text(
                  confirmation.host,
                  textAlign: TextAlign.center,
                  style: AppTypography.mono(colors.onCanvas, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        if (line != null) ...[
          const SizedBox(height: Spacing.s4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              line.translationKey.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(colors.onCanvasMuted, fontSize: 15),
            ),
          ),
        ],
      ],
    );
  }

  /// What a user who came back to this step sees: "Connected to" the server
  /// they picked, or Crit Alarm Cloud with where its connect stands, in the
  /// words the rest of setup uses for it. Continue and the way to change it
  /// are in the pinned bar.
  Widget _buildCurrentChoice(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;
    final isOnItsWay = !state.isConnected;
    final title = isOnItsWay
        ? LocaleKeys.onboarding_connect_cloud_title.tr()
        : cubit.choseCloud
        ? LocaleKeys.onboarding_connect_came_back_connected_cloud.tr()
        : LocaleKeys.onboarding_connect_came_back_connected_own.tr();
    // While the connect is on its way the line under the name says where
    // it stands. Once it has landed, the host says which server it is.
    final waitLine = isOnItsWay ? state.cloudWaitLine : null;
    final host = cubit.chosenHost;
    return Column(
      children: [
        // The route the user picked, drawn as it stands now.
        ConnectRoutesHeader(
          view: (
            lit: cubit.choseCloud || isOnItsWay
                ? ConnectRoute.cloud
                : ConnectRoute.ownServer,
            status: isOnItsWay
                ? ConnectRouteStatus.connecting
                : ConnectRouteStatus.connected,
          ),
        ),
        Semantics(
          liveRegion: true,
          // Read as one: "Connected to your server, alerts.example.com".
          label: '$title, ${waitLine ?? host}',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppFittedTitle(
                  title,
                  minFontSize: setupTitleMinFontSize,
                  style: AppTypography.headline(colors.onCanvas, fontSize: 30),
                ),
                const SizedBox(height: Spacing.s2),
                if (waitLine != null)
                  Text(
                    waitLine,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(colors.onCanvasMuted),
                  )
                else
                  // A host is a machine string, so it is set in mono.
                  Text(
                    host,
                    textAlign: TextAlign.center,
                    style: AppTypography.mono(colors.onCanvas, fontSize: 15),
                  ),
              ],
            ),
          ),
        ),
        if (_changeServerFailed) ...[
          const SizedBox(height: Spacing.s4),
          AppToast(
            key: const ValueKey('connect-change-server-error-toast'),
            faceState: FaceState.worried,
            message: LocaleKeys.onboarding_connect_change_server_failed.tr(),
          ),
        ],
      ],
    );
  }

  /// The way out: the user has not connected, and neither Cloud nor the
  /// address has to be tried first.
  Widget _buildSkipButton(
    BuildContext context,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;
    return TextButton(
      onPressed: () => unawaited(
        cubit.navigateToHome(isReplay: widget.isReplay),
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        LocaleKeys.onboarding_connect_skip_for_now.tr(),
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontFamilyFallback: AppTypography.fontBodyFallbacks,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.onCanvas,
        ),
      ),
    );
  }

  /// Pinned actions while the user picks a server. One bar serves both:
  /// the toggle stays and its words change in place, Connect grows in above
  /// it for your own server, and the way out shrinks away under it.
  Widget _buildPickBottomBar(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Reveal(
          progress: _morph,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: LocaleKeys.onboarding_connect_connect_button.tr(),
                size: AppButtonSize.lg,
                isFullWidth: true,
                onPressed: widget.isReplay ? _finishConnectStep : cubit.connect,
              ),
              // The small pill's tap area takes its extra room out of the gap
              // above it, so the pill stays where it was.
              SizedBox(
                height:
                    Spacing.s3 -
                    math.min(
                      Spacing.s3,
                      setupTapRoomFor(
                        setupButtonHeightFor(
                          minHeight: 36,
                          fontSize: 14,
                          textScale: setupTextScaleOf(context),
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _morph,
          // The Cloud bar keeps its pill narrower than the bar.
          builder: (context, child) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Spacing.s5 * (1 - _morph.value),
            ),
            child: child,
          ),
          // A small pill, so its tap area runs a little above it.
          child: SetupTapRoom(
            onTap: _toggleServer,
            child: AppButton(
              label: state.isSelfHosting
                  ? LocaleKeys.onboarding_connect_self_host_hide.tr()
                  : LocaleKeys.onboarding_connect_self_host_toggle.tr(),
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              isFullWidth: true,
              animatesLabel: true,
              onPressed: _toggleServer,
            ),
          ),
        ),
        _Reveal(
          progress: ReverseAnimation(_morph),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Spacing.s1),
              _buildSkipButton(context, cubit),
            ],
          ),
        ),
      ],
    );
  }

  /// Pinned actions for the states that are not a pick.
  Widget _buildConnectBottomBar(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    if (state.confirmation != null) {
      return AppButton(
        label: LocaleKeys.onboarding_connect_self_host_continue.tr(),
        size: AppButtonSize.lg,
        isFullWidth: true,
        onPressed: _finishConnectStep,
      );
    }
    if (_showsChoice(state)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: LocaleKeys.onboarding_connect_self_host_continue.tr(),
            size: AppButtonSize.lg,
            isFullWidth: true,
            onPressed: _isChangingServer ? null : _finishConnectStep,
          ),
          const SizedBox(height: Spacing.s3),
          AppButton(
            label: LocaleKeys.onboarding_connect_change_server.tr(),
            variant: AppButtonVariant.ghost,
            // Tall enough to tap without extra room around it.
            isFullWidth: true,
            isLoading: _isChangingServer,
            onPressed: () => unawaited(_changeServer()),
          ),
        ],
      );
    }
    // While the address is being checked the face and its line carry the
    // wait, so the bar only keeps the way out. Without it a user who is
    // offline or has the address wrong has no forward exit and no back.
    return _buildSkipButton(context, cubit);
  }

  Widget _buildHookTestState(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: AppBadge(
            text: LocaleKeys.onboarding_connect_connected_status.tr(
              namedArgs: {'serverUrl': state.serverUrl},
            ),
          ),
        ),
        const SizedBox(height: Spacing.s5),

        SetupFace(
          state: state.isCountingDown ? FaceState.alarmed : FaceState.cheeky,
          gap: Spacing.s4,
        ),

        AppFittedTitle(
          LocaleKeys.onboarding_connect_hook_title.tr(),
          minFontSize: setupTitleMinFontSize,
          style: AppTypography.headline(colors.onCanvas, fontSize: 30),
        ),
        const SizedBox(height: Spacing.s2),
        // An iPhone older than iOS 26 has no AlarmKit, so the test must not
        // ask it to ring through silent mode.
        Text(
          RingClaim.forPhone(state.alarm) == RingClaim.timeSensitive
              ? LocaleKeys.onboarding_connect_hook_subtitle_time_sensitive.tr()
              : LocaleKeys.onboarding_connect_hook_subtitle.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s5),

        if (state.isCountingDown) ...[
          LocalTestCountdownCard(
            seconds: state.countdownSeconds,
            line: LocaleKeys.onboarding_connect_hook_countdown.tr(),
            semanticLabel: LocaleKeys.onboarding_connect_hook_countdown_aria.tr(
              namedArgs: {'seconds': '${state.countdownSeconds}'},
            ),
          ),
        ] else ...[
          // 3-Step Challenge Box
          AppSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppStepBullet(
                  number: 1,
                  text:
                      RingClaim.forPhone(state.alarm) == RingClaim.timeSensitive
                      ? LocaleKeys.onboarding_connect_hook_step1_time_sensitive
                            .tr()
                      : LocaleKeys.onboarding_connect_hook_step1.tr(),
                ),
                const SizedBox(height: 12),
                AppStepBullet(
                  number: 2,
                  text: LocaleKeys.onboarding_connect_hook_step2.tr(),
                ),
                const SizedBox(height: 12),
                AppStepBullet(
                  number: 3,
                  text: LocaleKeys.onboarding_connect_hook_step3.tr(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHookBottomBar(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    if (state.isCountingDown) {
      return AppButton(
        label: LocaleKeys.onboarding_connect_hook_cancel.tr(),
        variant: AppButtonVariant.ghost,
        isFullWidth: true,
        onPressed: cubit.cancelCountdown,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: LocaleKeys.onboarding_connect_hook_button.tr(),
          size: AppButtonSize.lg,
          isFullWidth: true,
          isLoading: state.isCountingDown,
          onPressed: cubit.startLocalTestAlarm,
        ),
        const SizedBox(height: Spacing.s3),
        AppButton(
          label: LocaleKeys.onboarding_connect_dashboard_button.tr(),
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          isFullWidth: true,
          onPressed: () => unawaited(
            cubit.navigateToHome(isReplay: widget.isReplay),
          ),
        ),
        // 12px from the scaffold makes 24 above the home indicator.
        const SizedBox(height: 12),
      ],
    );
  }
}

/// The privacy line inside the Crit Alarm Cloud card, under its button.
///
/// Its room is kept while [line] is null, so the card holds its height and
/// the line fades in where it will sit. Two lines of the small print fit the
/// usual variant. A longer one grows the card.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.line});

  final ConnectPrivacyLine? line;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final current = line;
    final style = AppTypography.small(colors.ink3, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s3),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.textScalerOf(context).scale(12) * 1.5 * 2,
        ),
        child: AnimatedSwitcher(
          duration: context.motion(AppDurations.base),
          switchInCurve: AppCurves.easeOut,
          switchOutCurve: AppCurves.easeOut,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: current == null
              ? const SizedBox(
                  key: ValueKey('connect-privacy-none'),
                  width: double.infinity,
                )
              : Text(
                  current.translationKey.tr(),
                  key: ValueKey(current),
                  style: style,
                ),
        ),
      ),
    );
  }
}

/// A part that only one of the two states has. It grows to its height and
/// fades in as [progress] goes from 0 to 1, and shrinks away as it goes back.
/// At 0 it takes no room and is not there for a screen reader or a tap.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.progress, required this.child});

  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final amount = progress.value.clamp(0.0, 1.0);
        if (amount <= 0) return const SizedBox.shrink();
        final isSettled = amount >= 1;
        return ExcludeSemantics(
          excluding: !isSettled,
          child: IgnorePointer(
            ignoring: !isSettled,
            // Not clipped once it is whole, so a shadow keeps its edge.
            child: ClipRect(
              clipBehavior: isSettled ? Clip.none : Clip.hardEdge,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                heightFactor: amount,
                // The words go before the room does and come after it starts
                // to open, so a part never shows as a crushed line of text.
                child: Opacity(opacity: amount * amount, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One face of a card that is two things in turn. It shows at [opacityAt] of
/// the way across, and only the face that is in front takes taps, focus and
/// a screen reader's attention.
class _MorphFace extends StatelessWidget {
  const _MorphFace({
    required this.morph,
    required this.opacityAt,
    required this.isActiveAt,
    required this.child,
  });

  final Animation<double> morph;
  final double Function(double own) opacityAt;
  final bool Function(double own) isActiveAt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: morph,
      child: child,
      builder: (context, child) {
        final isActive = isActiveAt(morph.value);
        return ExcludeSemantics(
          excluding: !isActive,
          child: ExcludeFocus(
            excluding: !isActive,
            child: IgnorePointer(
              ignoring: !isActive,
              child: Opacity(opacity: opacityAt(morph.value), child: child),
            ),
          ),
        );
      },
    );
  }
}

/// The toasts over the card: no internet, and the last error. A toast comes
/// in and goes out by growing and shrinking, so what is under it moves
/// smoothly, and switching servers (which clears an error) does not make it
/// vanish in one frame.
class _ConnectNotices extends StatefulWidget {
  const _ConnectNotices({required this.isOffline, required this.errorMessage});

  final bool isOffline;
  final String? errorMessage;

  @override
  State<_ConnectNotices> createState() => _ConnectNoticesState();
}

class _ConnectNoticesState extends State<_ConnectNotices> {
  /// Counts the changes, so a toast that comes back while its last run is
  /// still going out is a new child of the switcher, not a duplicate.
  int _run = 0;

  @override
  void didUpdateWidget(_ConnectNotices oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOffline != widget.isOffline ||
        oldWidget.errorMessage != widget.errorMessage) {
      _run++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorMessage;
    return AnimatedSwitcher(
      duration: context.motion(AppDurations.base),
      switchInCurve: AppCurves.easeOut,
      switchOutCurve: AppCurves.easeOut,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      layoutBuilder: (current, previous) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...previous, ?current],
      ),
      child: Column(
        key: ValueKey(_run),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isOffline) ...[
            AppToast(
              key: const ValueKey('connect-offline-toast'),
              faceState: FaceState.concerned,
              message: LocaleKeys.onboarding_connect_offline_notice.tr(),
            ),
            const SizedBox(height: Spacing.s4),
          ],
          if (error != null) ...[
            AppToast(
              key: const ValueKey('connect-error-toast'),
              faceState: FaceState.worried,
              message: error,
            ),
            const SizedBox(height: Spacing.s4),
          ],
        ],
      ),
    );
  }
}
