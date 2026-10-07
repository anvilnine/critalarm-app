import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/model/permission_step_view.dart';
import 'package:critalarm/features/onboarding/presentation/model/permission_step_views.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/permission_preview_frame.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/permission_step_dots.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_face.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The permissions step of setup (/onboarding).
///
/// A stepper that only shows the steps this phone actually has, and only the
/// ones the user has not already answered. The cubit hands it one step at a
/// time and a view says what that step looks like, so nothing in here knows
/// which platform it is on. Until the cubit has read the statuses there is
/// no step, and the screen shows the waiting face rather than a prompt it
/// may be about to skip.
///
/// Nothing here blocks: "Not now" or a refused prompt moves straight to the
/// next step, because Apple's own guidance forbids holding the app hostage
/// over one, and AlarmKit never prompts twice. Home's health banner asks
/// again later.
class OnboardingPermissionsScreen extends StatelessWidget {
  const OnboardingPermissionsScreen({
    super.key,
    this.initialStep = NotificationPermissionStep.initial,
    this.replayForDemo = false,
    this.standalone = false,
    this.cameBack = false,
    this.replaySkips = 0,
  });

  /// The query parameter that opens a replay on a later step. Read in a
  /// developer build only.
  static const replaySkipParam = 'skip';

  /// How many steps a replay passes over before it rests, from [uri]. Zero
  /// in a store build, outside a replay and for anything but a small count.
  static int replaySkipsFrom(Uri uri) {
    if (!buildHasOnboardingDeveloperTools || !isOnboardingReplayUri(uri)) {
      return 0;
    }
    final skips = int.tryParse(uri.queryParameters[replaySkipParam] ?? '');
    return skips == null || skips < 0 || skips > 5 ? 0 : skips;
  }

  final NotificationPermissionStep initialStep;

  /// Opened from the developer menu to look at the screens. Every step shows,
  /// even the ones already granted.
  final bool replayForDemo;

  /// Opened from Health to ask for a permission the user was never asked.
  /// Not part of onboarding: it asks what is left, then closes.
  final bool standalone;

  /// Opened by Back from a later step. Every step shows again, and one the
  /// user already allowed shows as allowed, with nothing asked twice.
  final bool cameBack;

  /// Steps a developer replay passes over, so a later step can be opened
  /// directly. Nothing is asked for on the way.
  final int replaySkips;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<NotificationPermissionsCubit>(
          param1: initialStep,
          param2: (
            replayForDemo: replayForDemo,
            standalone: standalone,
            cameBack: cameBack,
          ),
        );
        unawaited(
          cubit.refresh().then((_) {
            for (var i = 0; i < replaySkips && !cubit.isClosed; i++) {
              if (cubit.state.steps.length - cubit.state.currentIndex <= 1) {
                break;
              }
              cubit.skipStep();
            }
          }),
        );
        return cubit;
      },
      child: _OnboardingPermissionsView(
        standalone: standalone,
        cameBack: cameBack,
      ),
    );
  }
}

class _OnboardingPermissionsView extends StatefulWidget {
  const _OnboardingPermissionsView({
    required this.standalone,
    required this.cameBack,
  });

  final bool standalone;
  final bool cameBack;

  @override
  State<_OnboardingPermissionsView> createState() =>
      _OnboardingPermissionsViewState();
}

class _OnboardingPermissionsViewState extends State<_OnboardingPermissionsView>
    with WidgetsBindingObserver {
  /// The face every onboarding screen shares, so it flies between them.
  static const _faceHeroTag = 'onboarding-face';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAmbientStep(context.read<NotificationPermissionsCubit>().state);
    });
  }

  /// Tells the canvas which step is on screen. The steps only move forward,
  /// so the shapes always drift the same way, however many steps this phone
  /// has. With no step yet the canvas is left where the route put it.
  void _syncAmbientStep(NotificationPermissionsState state) {
    final ambient = OnboardingAmbientScope.maybeOf(context);
    if (ambient == null) return;
    // The small face beside the tracker is worried while the step on screen
    // is one the user refused.
    final current = state.current;
    final isRefused =
        state.isDenied ||
        (current != null && state.promptSpent.contains(current));
    ambient.setFaceMood(isRefused ? TravellingFaceMood.worried : null);
    if (state.isDenied) {
      ambient.setStep(OnboardingAmbientStep.denied);
      return;
    }
    final view = _viewOf(state);
    if (view == null) return;
    ambient.setStep(view.ambient, AmbientDirection.right);
  }

  PermissionStepView? _viewOf(NotificationPermissionsState state) {
    final step = state.current;
    if (step == null) return null;
    // An iPhone below iOS 26 must never be told it rings through silent
    // mode. RingClaim says which words apply on this phone.
    return permissionStepViewFor(
      step,
      claim: RingClaim.forPhone(state.alarm),
      promptSpent: state.promptSpent.contains(step),
      notificationsGranted: state.notificationsGranted,
    );
  }

  /// The step the user has just allowed, held on screen for one beat with
  /// its glad face before the next step draws. Null the rest of the time.
  PermissionStepView? _allowedView;
  Timer? _beatTimer;
  NotificationPermissionsState? _previous;

  /// The view of the step [next] has just moved on from because the user
  /// allowed it, or null when nothing was allowed.
  PermissionStepView? _justAllowed(NotificationPermissionsState next) {
    final before = _previous;
    final step = before?.current;
    if (before == null || step == null) return null;
    final movedOn = next.current != step || next.canNavigate;
    final allowedNow =
        next.granted.contains(step) && !before.granted.contains(step);
    return movedOn && allowedNow ? _viewOf(before) : null;
  }

  /// Runs [then] after the glad beat for [allowed], or at once when there
  /// is nothing to show or the phone asks for reduced motion.
  void _afterBeat(PermissionStepView? allowed, VoidCallback then) {
    final beat = context.motion(AppDurations.base);
    if (allowed == null || beat == Duration.zero) {
      then();
      return;
    }
    _beatTimer?.cancel();
    setState(() => _allowedView = allowed);
    _beatTimer = Timer(beat, () {
      if (!mounted) return;
      setState(() => _allowedView = null);
      then();
    });
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from system Settings. Re-read the answer rather than making the user
  /// find a retry button to tell the app what it can look up itself.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(context.read<NotificationPermissionsCubit>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<
      NotificationPermissionsCubit,
      NotificationPermissionsState
    >(
      listenWhen: (prev, curr) {
        final listens =
            (!prev.canNavigate && curr.canNavigate) ||
            prev.current != curr.current ||
            prev.isDenied != curr.isDenied;
        // Kept so the listener can tell a step that was allowed from one
        // that was skipped.
        if (listens) _previous = prev;
        return listens;
      },
      listener: (context, state) {
        final allowed = _justAllowed(state);
        if (state.canNavigate) {
          context.read<NotificationPermissionsCubit>().navigationHandled();
          _afterBeat(allowed, () {
            if (widget.standalone) {
              _close(context);
            } else {
              unawaited(
                finishOnboardingStep(context, OnboardingStepId.permissions),
              );
            }
          });
          return;
        }
        _afterBeat(allowed, () => _syncAmbientStep(state));
      },
      builder: (context, state) {
        final cubit = context.read<NotificationPermissionsCubit>();
        final allowedView = _allowedView;
        final view = allowedView ?? _viewOf(state);
        // Came back to a step that is already allowed: it shows as allowed,
        // with no prompt drawn and a button that only moves on.
        final isAnswered =
            widget.cameBack &&
            allowedView == null &&
            state.granted.contains(state.current);
        final preview = isAnswered ? null : view?.preview;
        final badge = isAnswered
            ? LocaleKeys.onboarding_permissions_allowed_badge.tr()
            : view?.badge;
        final hint = preview?.hint;
        // While the connect running behind the user says something in the
        // top corner, the dots give it the corner.
        final cornerIsTaken = OnboardingAmbientScope.hasQuietLineOf(context);

        return AppScreenScaffold(
          // On its own the screen sits over Health, not over the onboarding
          // canvas, so it paints its own background.
          backgroundColor: widget.standalone ? null : Colors.transparent,
          withGhosts: false,
          withFades: false,
          hasTabBar: false,
          topBar: AppTopBar(
            title: setupTopBarTitle(context),
            leading: widget.standalone
                ? AppIconButton(
                    glyph: GlyphType.close,
                    ariaLabel: LocaleKeys.common_back.tr(),
                    onPressed: () => _close(context),
                  )
                : null,
            // Counts the steps this phone draws, so it is right with two
            // steps and with three. One step has nothing to count and
            // draws no dots. Up here they never push the buttons around.
            trailing: view != null && !state.isDenied && state.steps.length > 1
                ? AnimatedOpacity(
                    opacity: cornerIsTaken ? 0 : 1,
                    duration: context.motion(AppDurations.base),
                    child: PermissionStepDots(
                      count: state.steps.length,
                      // The dot stays on the allowed step for its beat.
                      index: allowedView == null
                          ? state.currentIndex
                          : state.steps.indexOf(
                              _previous?.current ?? state.steps.first,
                            ),
                    ),
                  )
                : null,
          ),
          bottomBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: state.isDenied
                ? [
                    AppButton(
                      label: LocaleKeys
                          .onboarding_permissions_denied_open_settings
                          .tr(),
                      size: AppButtonSize.lg,
                      isFullWidth: true,
                      onPressed: cubit.openSettings,
                    ),
                    const SizedBox(height: Spacing.s3),
                    // Never a wall. A user who says no still gets into the
                    // app; the health banner keeps asking afterwards.
                    AppButton(
                      label: LocaleKeys.onboarding_permissions_denied_skip.tr(),
                      variant: AppButtonVariant.paper,
                      isFullWidth: true,
                      onPressed: cubit.continueWithout,
                    ),
                  ]
                : [
                    if (view != null)
                      AppButton(
                        label: isAnswered
                            ? LocaleKeys.onboarding_welcome_continue.tr()
                            : view.button,
                        size: AppButtonSize.lg,
                        isFullWidth: true,
                        isLoading: state.isRequesting,
                        onPressed: allowedView != null
                            ? null
                            : cubit.allowCurrentStep,
                      ),
                    // The way forward is there before the first step is: a
                    // status read that hangs must not hold the user here.
                    // An allowed step has the one button: it already only
                    // moves on.
                    if (view == null || (view.canSkip && !isAnswered)) ...[
                      const SizedBox(height: Spacing.s3),
                      AppButton(
                        label: LocaleKeys.onboarding_permissions_not_now.tr(),
                        variant: AppButtonVariant.paper,
                        isFullWidth: true,
                        onPressed: state.isRequesting || allowedView != null
                            ? null
                            : view == null
                            ? cubit.continueWithout
                            : cubit.skipStep,
                      ),
                    ],
                  ],
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s5,
                Spacing.s4,
                Spacing.s5,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: state.isDenied
                    ? AppEmptyState(
                        // Softer than an error: nothing broke.
                        faceState: FaceState.concerned,
                        title: LocaleKeys.onboarding_permissions_denied_title
                            .tr(),
                        description: LocaleKeys
                            .onboarding_permissions_denied_description
                            .tr(),
                      )
                    : view == null
                    // The statuses are still being read. The face sits
                    // where a step's face will, so nothing jumps when the
                    // first step arrives.
                    ? Center(
                        child: AppWaitingFace(
                          message: LocaleKeys.onboarding_permissions_checking
                              .tr(),
                          faceSize: SetupFace.waitingSizeOf(context),
                          heroTag: _faceHeroTag,
                        ),
                      )
                    : Column(
                        children: [
                          // Glad for one beat after the user allows.
                          SetupFace(
                            state: allowedView != null || isAnswered
                                ? view.grantedFace
                                : view.face,
                          ),
                          if (badge != null) ...[
                            const SizedBox(height: Spacing.s3),
                            AppBadge(
                              text: badge,
                              faceState: isAnswered
                                  ? view.grantedFace
                                  : view.face,
                            ),
                          ],
                          const SizedBox(height: Spacing.s4),
                          // One title style for every task screen in setup.
                          AppFittedTitle(
                            view.title,
                            minFontSize: setupTitleMinFontSize,
                            style: AppTypography.headline(
                              colors.onCanvas,
                              fontSize: 30,
                            ),
                          ),
                          const SizedBox(height: Spacing.s2),
                          Text(
                            view.subtitle,
                            textAlign: TextAlign.center,
                            style: AppTypography.body(colors.onCanvasMuted),
                          ),

                          // A step with no prompt coming has no prompt to
                          // draw.
                          if (preview != null) ...[
                            const SizedBox(height: Spacing.s5),
                            PermissionPreviewFrame(
                              semanticLabel: hint == null
                                  ? preview.title
                                  : '${preview.title}. $hint',
                              onTap: state.isRequesting || allowedView != null
                                  ? null
                                  : cubit.allowCurrentStep,
                              child: preview.child,
                            ),
                            // Only a Settings switch needs telling what to
                            // do. A drawn dialog shows its own Allow.
                            if (hint != null) ...[
                              const SizedBox(height: Spacing.s3),
                              Text(
                                hint,
                                textAlign: TextAlign.center,
                                style: AppTypography.small(
                                  colors.onCanvasMuted,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/permissions');
    }
  }
}
