import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_state.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_examples.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/in_app_notices/domain/day0_card_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/day0_card_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/in_app_notices/presentation/home_asks.dart';
import 'package:critalarm/features/in_app_notices/presentation/missed_alarm_notice_view.dart';
import 'package:critalarm/features/in_app_notices/presentation/notice_return_rule.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/notice_detail_sheet.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/pro_plan_sheet.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/paywall/presentation/widgets/pro_status_badge.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/setup_finish_card.dart';
import 'package:critalarm/features/topics/domain/home_list_rules.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/domain/setup_checklist_store.dart';
import 'package:critalarm/features/topics/domain/setup_finish_glow.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_effect.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/features/topics/presentation/home_card_view.dart';
import 'package:critalarm/features/topics/presentation/home_inbox_view.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_setup_section.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_widgets_sheet.dart';
import 'package:critalarm/features/topics/presentation/widgets/setup_glow.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HomeScreen matching docs/design-system/index.html mobile mockup.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = getIt<HomeCubit>();
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) {
            final cubit = getIt<InAppNoticeCubit>();
            unawaited(cubit.load());
            return cubit;
          },
        ),
        // The setup checklist and the widgets card. Home content: it is
        // fed by the list above and never by the notice slot.
        BlocProvider(create: (_) => getIt<HomeSetupCubit>()),
        // The day-0 card. Decided after the asks, in `runHomeAsk`.
        BlocProvider(create: (_) => getIt<Day0CardCubit>()),
        // The dark card. It follows the list and the setup cubit above.
        BlocProvider(
          create: (context) => getIt<HomeCardCubit>(
            param1: context.read<HomeCubit>(),
            param2: context.read<HomeSetupCubit>(),
          ),
        ),
      ],
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent>
    with RouteAware, WidgetsBindingObserver {
  String? _selectedTopic;

  /// The incident this screen has already handed over for. Kept so backing out
  /// of the alarm screen does not bounce the user straight back into it, while
  /// a new incident still takes over.
  String? _handedOver;

  final FeatureGuideCubit _guides = getIt<FeatureGuideCubit>();
  StreamSubscription<FeatureGuideState>? _guideSub;
  StreamSubscription<FeatureGuideState>? _guideSetupSub;

  /// What this phone can ring through, so a line never promises more. Read
  /// once; the answer is the same for the whole run.
  RingClaim _ringClaim = RingClaim.alarm;

  /// The newest message time of each topic at the last build, or null before
  /// the first list. See [nextGlanceCount].
  MessageTimes? _messageTimes;

  /// Goes up each time a topic gets a newer message while Home is in front.
  /// The hero face glances at the list when it moves.
  int _glance = 0;

  /// The "One topic so far" card was closed on this install.
  bool _isOneTopicClosed = false;

  /// Another screen is on top of Home.
  bool _isCovered = false;

  /// The app is open and at the front.
  bool _isResumed = true;

  /// Bumped on every cover and uncover, so a late "back in view" from an
  /// earlier pop is dropped.
  int _viewChange = 0;

  /// The topic setup made, when setup ended a moment ago and handed over to
  /// this screen. Its row glows once. Null on every other opening of Home.
  String? _glowTopic;

  /// The glow has started. It then runs to its end by itself.
  bool _glowPlays = false;

  /// Lets the glow go once it has run, so a row that is built again later
  /// never plays it a second time.
  Timer? _glowEnds;

  /// Starts the glow once it can be seen, or lets it go. See
  /// [setupGlowStepFor].
  void _updateSetupGlow() {
    final topic = _glowTopic;
    if (!mounted || topic == null || _glowPlays) return;
    final home = context.read<HomeCubit>().state;
    final guide = _guides.state;
    final isOffered = guide.status == FeatureGuideStatus.offering;
    final step = setupGlowStepFor(
      isHomeInFront:
          !_isCovered &&
          !_isRouteElsewhere &&
          isHomeFrontScreen(
            location: _routerLocation(),
            isAppResumed: _isResumed,
          ),
      isGuideOffered: isOffered,
      isGuideRunning: guide.isActive && !isOffered,
      isListLoaded: home.status == HomeStatus.success && !home.isStale,
      hasTopicRow: home.topicItems.any((item) => item.name == topic),
    );
    switch (step) {
      case SetupGlowStep.wait:
        break;
      case SetupGlowStep.play:
        setState(() => _glowPlays = true);
        _glowEnds = Timer(setupGlowTakes(isStill: context.reduceMotion), () {
          if (!mounted) return;
          setState(() {
            _glowTopic = null;
            _glowPlays = false;
          });
        });
      case SetupGlowStep.drop:
        setState(() => _glowTopic = null);
    }
  }

  @override
  void initState() {
    super.initState();
    // Taken once: only the Home that setup hands over to finds a topic here.
    _glowTopic = setupFinishSignal.take();
    WidgetsBinding.instance.addObserver(this);
    final prefs = getIt<SharedPreferences>();
    _isOneTopicClosed = prefs.getBool(oneTopicCardClosedKey) ?? false;
    unawaited(_readRingClaim());
    // The FeatureGuideHost asks for this screen's guide on the first visit.
    // The notices and the asks hold off until no guide is running, and come
    // back once one ends.
    _guideSub = _guides.stream.where((guide) => !guide.isActive).listen((_) {
      if (!mounted) return;
      unawaited(context.read<InAppNoticeCubit>().load());
      unawaited(_runHomeAsk());
    });
    // The setup checklist hears every guide change, the offer included: it
    // holds still while one is up.
    _guideSetupSub = _guides.stream.listen((_) => _tellSetup());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runHomeAsk(isNewOpen: true));
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      _isResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
      unawaited(
        context.read<HomeSetupCubit>().homeChanged(
          context.read<HomeCubit>().state,
        ),
      );
      _tellSetup();
    });
  }

  Future<void> _readRingClaim() async {
    // The host answers "unsupported" when it cannot be reached, which
    // RingClaim reads as the quiet wording on an iPhone.
    final alarm = await getIt<AlarmHost>().authorizationStatus();
    if (mounted) setState(() => _ringClaim = RingClaim.forPhone(alarm));
  }

  /// Reads the phone's checks and the missed alarm entry again. Home does it
  /// on open, on resume, on pull to refresh and when a screen above it goes.
  void _refreshReadiness() {
    if (!mounted) return;
    unawaited(context.read<HomeCardCubit>().refreshReadiness());
  }

  /// Whether Home is the screen in front and the app is resumed.
  bool get _isHomeInFront =>
      !_isCovered &&
      !_isRouteElsewhere &&
      isHomeFrontScreen(location: _routerLocation(), isAppResumed: _isResumed);

  /// Counts a glance when a topic got a newer message since the last build.
  void _trackGlance(HomeState state) {
    if (state.status != HomeStatus.success || state.isStale) return;
    final after = <String, DateTime>{
      for (final topic in state.topicItems) topic.name: ?topic.lastMessageAt,
    };
    final next = nextGlanceCount(
      count: _glance,
      before: _messageTimes,
      after: after,
      isInFront: _isHomeInFront,
      now: DateTime.now(),
    );
    _messageTimes = after;
    if (next != _glance) setState(() => _glance = next);
  }

  /// Tells the setup checklist whether the user is looking at Home. It
  /// ticks rows, celebrates and polls for the first message only while they
  /// are.
  void _tellSetup() {
    if (!mounted) return;
    // The same changes decide whether the glow from setup can be seen.
    _updateSetupGlow();
    unawaited(
      context.read<HomeSetupCubit>().screenChanged(
        // Both have to agree. The route observer only hears about pages
        // on this tab's own navigator, so the router's location is what
        // says an alarm, the new-topic screen, the plans or another tab
        // is on top.
        isInFront: isSetupChecklistInFront(
          isCovered: _isCovered,
          isRouteElsewhere: _isRouteElsewhere,
          // The checklist lives in the dark card now, and the pinned bar
          // does not cover it.
          hasPinnedNotice: false,
          isHomeFront: isHomeFrontScreen(
            location: _routerLocation(),
            isAppResumed: _isResumed,
          ),
        ),
        isGuideActive: _guides.state.isActive,
      ),
    );
  }

  /// The Pro, Reminders and consent sheets and the review popup, when one is
  /// due. Never while a guide is up or about to be: they wait for it to end.
  ///
  /// [isNewOpen] is true when Home just opened or came back to the front,
  /// which is what counts toward the day-0 card's three opens.
  Future<void> _runHomeAsk({bool isNewOpen = false}) async {
    if (!mounted || _guides.state.isActive) return;
    await runHomeAsk(context, isNewOpen: isNewOpen);
  }

  GoRouter? _router;

  /// The router showed something other than Home and has not been back
  /// long enough for that screen to have slid away.
  bool _isRouteElsewhere = false;

  /// The path the router is showing right now, the top of anything pushed
  /// included.
  String _routerLocation() {
    final router = _router;
    if (router == null) return '/';
    final shown = router.routerDelegate.currentConfiguration;
    if (shown.isEmpty) return '/';
    final last = shown.last;
    return last is ImperativeRouteMatch
        ? last.matches.uri.path
        : shown.uri.path;
  }

  /// The router moved. Leaving Home counts at once. Coming back counts once
  /// the screen above has slid away, so a row that turned true over there
  /// ticks where it can be seen.
  void _onRouterMoved() {
    if (!mounted) return;
    final isHome = isHomeFrontScreen(
      location: _routerLocation(),
      isAppResumed: true,
    );
    if (!isHome) {
      _viewChange++;
      _isRouteElsewhere = true;
      _tellSetup();
      return;
    }
    if (!_isRouteElsewhere) return;
    _refreshReadiness();
    // Back from another tab: what happened there (a missed alarm closed on
    // the Reliability screen) shows now, not at the next resume. The card
    // has the same key, so one that is still due does not slide in again.
    if (readsNoticeOnReturn(
      wasElsewhere: _isRouteElsewhere,
      isCovered: _isCovered,
    )) {
      unawaited(context.read<InAppNoticeCubit>().load());
    }
    final change = ++_viewChange;
    unawaited(
      Future<void>.delayed(AppDurations.slow, () {
        if (!mounted || change != _viewChange) return;
        _isRouteElsewhere = false;
        _isCovered = false;
        _tellSetup();
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onRouterMoved);
      _router = router;
      router?.routerDelegate.addListener(_onRouterMoved);
      _isRouteElsewhere = !isHomeFrontScreen(
        location: _routerLocation(),
        isAppResumed: true,
      );
    }
  }

  @override
  void dispose() {
    _glowEnds?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_guideSub?.cancel());
    unawaited(_guideSetupSub?.cancel());
    appRouteObserver.unsubscribe(this);
    _router?.routerDelegate.removeListener(_onRouterMoved);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isResumed = state == AppLifecycleState.resumed;
    _tellSetup();
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshReadiness();
      unawaited(context.read<InAppNoticeCubit>().onAppResumed());
      // Only a resume with Home in front counts as one of the card's opens.
      unawaited(
        _runHomeAsk(
          isNewOpen: countsAsHomeOpen(
            isCovered: _isCovered,
            isRouteElsewhere: _isRouteElsewhere,
            isTabShown: TickerMode.valuesOf(context).enabled,
          ),
        ),
      );
    }
  }

  /// Back from creating a topic, from a topic, from anywhere. Whatever the
  /// user just did could have changed this list, so load it again.
  @override
  void didPopNext() {
    if (!mounted) return;
    unawaited(context.read<HomeCubit>().refresh());
    unawaited(context.read<InAppNoticeCubit>().refresh());
    _refreshReadiness();
    // Home counts as back in view once the screen above has slid away, so a
    // row that turned true over there ticks where it can be seen.
    final change = ++_viewChange;
    unawaited(
      Future<void>.delayed(AppDurations.slow, () {
        if (!mounted || change != _viewChange) return;
        _isCovered = false;
        _isRouteElsewhere = !isHomeFrontScreen(
          location: _routerLocation(),
          isAppResumed: true,
        );
        _tellSetup();
      }),
    );
  }

  @override
  void didPushNext() {
    _viewChange++;
    _isCovered = true;
    _tellSetup();
  }

  void _openWidgetsPaywall() {
    unawaited(context.read<HomeSetupCubit>().widgetsPlansOpened());
    unawaited(
      openPaywallForFeature(
        context,
        AppFeature.widgets,
        LockSource.homeWidgets,
      ),
    );
  }

  void _openDay0Plans() {
    unawaited(context.read<Day0CardCubit>().seePlans());
    unawaited(context.push(hostedPaywallLocation(PaywallSource.homeDay0Card)));
  }

  void _showWidgetsHowTo(HomeWidgetsPlan plan) {
    final setup = context.read<HomeSetupCubit>();
    unawaited(setup.widgetsHowToOpened());
    unawaited(
      showHomeWidgetsSheet(
        context: context,
        platform: setup.platform,
        plan: plan,
        onSeePro: () {
          if (!mounted) return;
          unawaited(
            openPaywallForFeature(
              context,
              AppFeature.widgets,
              LockSource.homeWidgets,
            ),
          );
        },
      ),
    );
  }

  /// While anything is ringing, the app is the alarm. The list is no use to
  /// someone being screamed at, so hand them the screen with the stop control
  /// on it. Only once per incident, so leaving it is allowed.
  void _handOverIfRinging(HomeState state) {
    final id = state.ringingIncidentId;
    if (id == null) {
      if (_handedOver != null) _handedOver = null;
      return;
    }
    if (id == _handedOver) return;
    _handedOver = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.push('/incidents/$id'));
    });
  }

  /// [row] with the one-time glow over it when [topicName] is the topic
  /// setup just made. Every other row is handed back as it is.
  Widget _glowIfFromSetup(String topicName, Widget row) =>
      topicName == _glowTopic
      ? SetupGlow(isPlaying: _glowPlays, child: row)
      : row;

  /// Pull a row right to mark it read, left to pin or mute it.
  Widget _swipe(
    HomeCubit home,
    HomeTopicItem topic, {
    required bool enabled,
    required Widget child,
  }) {
    final key = ValueKey('topic_row_${topic.name}');
    final row = _glowIfFromSetup(topic.name, child);
    if (!enabled) return KeyedSubtree(key: key, child: row);

    final markRead = LocaleKeys.home_swipe_mark_read.tr();
    final pin = topic.isPinned
        ? LocaleKeys.home_swipe_unpin.tr()
        : LocaleKeys.home_swipe_pin.tr();
    final mute = topic.isMuted
        ? LocaleKeys.home_swipe_unmute.tr()
        : LocaleKeys.home_swipe_mute.tr();

    // The same three actions for VoiceOver and TalkBack, which cannot swipe
    // a row open: they show up in the actions rotor on the row.
    return Semantics(
      key: key,
      customSemanticsActions: {
        CustomSemanticsAction(label: markRead): () =>
            unawaited(home.markRead(topic.name)),
        CustomSemanticsAction(label: pin): () =>
            unawaited(home.togglePin(topic.name)),
        CustomSemanticsAction(label: mute): () =>
            unawaited(home.toggleMute(topic.name)),
      },
      child: AppSwipeActions(
        groupTag: 'home_topics',
        start: [
          AppSwipeAction(
            label: markRead,
            glyph: GlyphType.check,
            isPrimary: true,
            onPressed: () => unawaited(home.markRead(topic.name)),
          ),
        ],
        end: [
          AppSwipeAction(
            label: pin,
            glyph: GlyphType.pin,
            isPrimary: true,
            onPressed: () => unawaited(home.togglePin(topic.name)),
          ),
          AppSwipeAction(
            label: mute,
            glyph: topic.isMuted ? GlyphType.bell : GlyphType.bellOff,
            onPressed: () => unawaited(home.toggleMute(topic.name)),
          ),
        ],
        child: row,
      ),
    );
  }

  /// Carries out what the card's button asked for.
  Future<void> _runEffect(HomeCardEffect effect) async {
    if (!mounted) return;
    switch (effect) {
      case OpenPath(:final path):
        openAppPath(context, path);
      case OpenRoute(:final name):
        unawaited(context.pushNamed<void>(name));
      case RunReliabilityFix(:final fix):
        await getIt<ReliabilityFixRunner>().run(fix);
        _refreshReadiness();
      case RefreshHome():
        unawaited(context.read<HomeCubit>().refresh());
      case NoEffect():
        break;
    }
  }

  /// The card's button.
  Future<void> _onCardAction(HomeCardAction action) async {
    final card = context.read<HomeCardCubit>();
    if (action is SeeMissed) return _seeMissed(card);
    await _runEffect(card.actionFor(action));
  }

  /// "See why" opens the missed alarm sheet, which can also close the entry.
  Future<void> _seeMissed(HomeCardCubit card) async {
    final feed = getIt<MissedAlarmFeed>();
    final fact = await feed.read();
    if (fact == null || !mounted) return;
    final notice = fact.notice;
    final next = card.actionFor(const SeeMissed());
    await showNoticeDetailSheet(
      context: context,
      face: missedAlarmFace(notice.reason),
      title: notice.count > 1
          ? LocaleKeys.notices_missed_alarm_title_many.tr(
              namedArgs: {'count': '${notice.count}'},
            )
          : LocaleKeys.notices_missed_alarm_title.tr(),
      body: missedAlarmReasonKey(notice.reason).tr(),
      actionLabel: missedAlarmButtonKey(notice.reason).tr(),
      dismissLabel: LocaleKeys.home_card_close_this.tr(),
      onAction: () => unawaited(_runEffect(next)),
      onDismiss: () => unawaited(feed.dismiss(notice.incidentIds)),
    );
  }

  void _openReliability() => openAppPath(context, AppLinkRoutes.reliability);

  void _closeOneTopic() {
    setState(() => _isOneTopicClosed = true);
    unawaited(getIt<SharedPreferences>().setBool(oneTopicCardClosedKey, true));
  }

  @override
  Widget build(BuildContext context) {
    final size = AppSize.of(context);

    return BlocConsumer<HomeCubit, HomeState>(
      listener: (context, state) {
        _handOverIfRinging(state);
        _trackGlance(state);
        _updateSetupGlow();
        unawaited(context.read<HomeSetupCubit>().homeChanged(state));
      },
      builder: (context, state) =>
          BlocBuilder<FeatureGuideCubit, FeatureGuideState>(
            bloc: _guides,
            builder: (context, guide) =>
                BlocBuilder<InAppNoticeCubit, InAppNoticeState>(
                  builder: (context, notice) =>
                      BlocBuilder<HomeSetupCubit, HomeSetupState>(
                        builder: (context, setup) =>
                            BlocBuilder<HomeCardCubit, HomeCardState>(
                              builder: (context, card) => _build(
                                context,
                                size,
                                state,
                                guide,
                                notice,
                                setup,
                                card.model,
                              ),
                            ),
                      ),
                ),
          ),
    );
  }

  /// The card for the moment setup finishes, or [model] as it is.
  static HomeCardModel _withFinish(HomeCardModel model, HomeSetupState setup) {
    final isFinishing =
        (setup.phase == HomeSetupPhase.checklist ||
            setup.phase == HomeSetupPhase.celebration) &&
        setup.checklist.isComplete;
    return isFinishing ? setupFinishCard() : model;
  }

  Widget _build(
    BuildContext context,
    AppSize size,
    HomeState real,
    FeatureGuideState guide,
    InAppNoticeState notice,
    HomeSetupState setup,
    HomeCardModel realCard,
  ) {
    // While the guide runs, the list gets an example topic that is ringing,
    // so the user sees what trouble looks like before it happens. Someone
    // with no topics yet also gets two calm ones. They all go when the guide
    // does.
    final showExamples =
        guide.showsHomeExamples && real.status == HomeStatus.success;
    final card = showExamples
        ? FeatureGuideExamples.troubleCard()
        : _withFinish(realCard, setup);
    final state = !showExamples
        ? real
        : real.copyWith(
            topicItems: [
              FeatureGuideExamples.troubleTopic(),
              ...(real.isEmpty
                  ? FeatureGuideExamples.homeTopics()
                  : real.topicItems),
            ],
          );
    // A deleted topic leaves the pane pointing at a name the list no
    // longer has, so the selection is read back off the list every build
    // rather than trusted.
    final selected = state.topicItems.any((t) => t.name == _selectedTopic)
        ? _selectedTopic
        : null;

    final home = context.read<HomeCubit>();
    final now = DateTime.now();
    final rows = <Widget>[
      for (final topic in state.topicItems)
        _swipe(
          home,
          topic,
          // Guide rows are examples, not topics, so there is nothing to pin.
          // Old rows from an unreachable server are look-only.
          enabled: !showExamples && !state.isStale,
          child: _row(
            home,
            topic,
            now: now,
            isSelected: size.isExpanded && topic.name == selected,
            isExample: showExamples,
            isExpanded: size.isExpanded,
          ),
        ),
    ];

    // The setup content shows only over a list that loaded, and never beside
    // a running guide's example rows.
    final showsSetup =
        real.status == HomeStatus.success &&
        !real.isStale &&
        (!guide.isActive || guide.status == FeatureGuideStatus.offering);
    final setupState = showsSetup ? setup : const HomeSetupState();
    final showsDay0Card = showsSetup && context.watch<Day0CardCubit>().state;
    final cream = !showsSetup
        ? null
        : creamCardFor(
            widgets: setupState.phase == HomeSetupPhase.widgetsCard,
            day0: showsDay0Card,
          );

    // The one bar floating above the tab bar. A running guide holds it back.
    final oneTopicDue =
        showsSetup &&
        !showExamples &&
        _sheetShows(state) &&
        showsOneTopicCard(
          topicCount: state.topicItems.length,
          isClosed: _isOneTopicClosed,
          isSetupDone: getIt<SetupChecklistStore>().isDone,
          cardKind: card.kind,
        );
    final pinned = guide.isActive
        ? null
        : pinnedBarFor(
            hostedEnding: notice.noticeType == InAppNoticeType.proEnding,
            accountBackup: notice.noticeType == InAppNoticeType.accountBackup,
            oneTopic: oneTopicDue,
          );
    final noticeBar = pinned == null ? null : _pinnedBar(pinned, notice);

    final screen = SeverityScope(
      severity: card.severity,
      child: AppScreenScaffold(
        onFaceRefresh: () async {
          final noticeCubit = context.read<InAppNoticeCubit>();
          final homeCubit = context.read<HomeCubit>();
          final shell = context.read<ShellCubit>();
          _refreshReadiness();
          await shell.refresh();
          await noticeCubit.refresh();
          return homeCubit.refresh();
        },
        // Search is not up here any more. It lives next to the compose
        // button on the floating bar, so it is reachable from every tab
        // rather than only this one.
        topBar: AppTopBar(
          title: LocaleKeys.topics_list_title.tr(),
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [ProStatusBadge(), RefreshActivityIndicator()],
          ),
        ),
        // Narrower than the topics card and wider than the tab bar, so the
        // three step in towards the bottom.
        bottomBar: switch (noticeBar) {
          final bar? => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: bar,
          ),
          null => null,
        },
        detail: state.topicItems.isEmpty
            ? null
            : (selected == null
                  ? AppEmptyState(
                      title: LocaleKeys.home_detail_empty_title.tr(),
                      description: LocaleKeys.home_detail_empty_body.tr(),
                    )
                  : TopicDetailScreen(
                      key: ValueKey(selected),
                      topicName: selected,
                      isPane: true,
                    )),
        slivers: [
          // The hero and the sheet are one box, so the sheet paints over
          // the part of the hero's disc that reaches down behind it.
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Spacing.s3),
                FeatureGuideAnchor(
                  id: FeatureGuideAnchorId.homeStage,
                  child: _HeroBlock(
                    model: card,
                    glance: _glance,
                    isPane: size.isExpanded,
                    onAction: showExamples ? null : _onCardAction,
                    onTapBody: showExamples ? null : _openReliability,
                  ),
                ),
                const SizedBox(height: Spacing.s4),
                // With no server saved there is nothing to list and nothing
                // to say that the card above is not already saying, so the
                // sheet does not draw at all. A failed load is said by the
                // card too.
                if (_sheetShows(state))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: FeatureGuideAnchor(
                      id: FeatureGuideAnchorId.topicList,
                      child: _OnSurface(
                        child: _sheet(
                          context,
                          state,
                          rows,
                          cream: cream,
                          setup: setupState,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // One short throw of confetti when the checklist finishes, over the
    // whole screen and dead to the touch.
    final content = Stack(
      fit: StackFit.passthrough,
      children: [
        screen,
        if (setupState.phase == HomeSetupPhase.celebration)
          const Positioned.fill(child: HomeSetupConfetti()),
      ],
    );

    // The canvas behind the screen is the ambient one. It gets the profile
    // for the card, and morphs to the next one when the card changes.
    return AmbientRouteProfile(
      path: '/',
      profile: homeAmbientProfile(
        card,
        context.appColors,
        spot: heroDiscSpotOf(context),
      ),
      child: content,
    );
  }

  /// Whether the white sheet is drawn at all.
  static bool _sheetShows(HomeState state) =>
      state.hasServer && (state.status != HomeStatus.failure || state.isStale);

  Widget _row(
    HomeCubit home,
    HomeTopicItem topic, {
    required DateTime now,
    required bool isSelected,
    required bool isExample,
    required bool isExpanded,
  }) {
    final row = AppInboxRow(
      name: topic.name,
      message: topic.preview ?? LocaleKeys.home_card_row_no_message.tr(),
      time: inboxTimeText(
        state: topic.rowKind,
        lastMessageAt: topic.lastMessageAt,
        now: now,
      ),
      kind: inboxRowKindFor(
        state: topic.rowKind,
        isMuted: topic.isMuted,
        unreadCount: topic.unreadCount,
      ),
      unreadCount: topic.unreadCount,
      hasCriticalDelivery: topic.ringsThroughSilent,
      criticalLabel: topic.ringsThroughSilent
          ? inboxBellLabel(_ringClaim)
          : null,
      isPinned: topic.isPinned,
      onTap: () {
        // Opening a topic reads it.
        if (!isExample) unawaited(home.markRead(topic.name));
        if (isExpanded) {
          AppHaptics.selection();
          setState(() => _selectedTopic = topic.name);
        } else if (!isExample) {
          unawaited(context.push('/topics/${topic.name}'));
        }
      },
    );
    if (!isSelected) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.cobaltTint.withValues(alpha: 0.6),
        borderRadius: Radii.mdAll,
      ),
      child: row,
    );
  }

  Widget _sheet(
    BuildContext context,
    HomeState state,
    List<Widget> rows, {
    required HomeCreamCard? cream,
    required HomeSetupState setup,
  }) {
    final colors = context.appColors;
    // Loading: the sheet holds placeholder rows until the list answers.
    if (state.topicItems.isEmpty && state.status != HomeStatus.success) {
      return const _LoadingSheet();
    }
    if (state.isEmpty) return _EmptyTopics(onTool: _newTopic);

    if (state.isStale) {
      final at = state.lastKnownGoodAt;
      return AppInboxSheet(
        children: [
          if (at != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Text(
                LocaleKeys.home_card_stale_caption
                    .tr(
                      namedArgs: {'time': DateFormat.Hm().format(at.toLocal())},
                    )
                    .toUpperCase(),
                style: AppTypography.mono(colors.ink3, fontSize: 11),
              ),
            ),
          // The rows are the user's own, just old, so they stay. Dimmed and
          // dead to the touch, because opening one would show numbers from
          // then, not now.
          for (final row in rows)
            Opacity(opacity: 0.45, child: IgnorePointer(child: row)),
        ],
      );
    }

    return SlidableAutoCloseBehavior(
      child: AppInboxSheet(
        children: [
          if (cream != null) _creamCard(cream, setup),
          ...rows,
        ],
      ),
    );
  }

  void _newTopic([ToolTemplate? tool]) => unawaited(
    context.push(
      tool == null ? '/topics/new' : '/topics/new?tool=${tool.id}',
    ),
  );

  /// The one cream card at the top of the sheet.
  Widget _creamCard(HomeCreamCard which, HomeSetupState setup) {
    final Widget card;
    switch (which) {
      case HomeCreamCard.widgets:
        final needsPro = setup.widgetsPlan == HomeWidgetsPlan.needsPro;
        card = AppCreamCard(
          title: LocaleKeys.onboarding_welcome_widgets_title.tr(),
          body: needsPro ? LocaleKeys.home_widgets_needs_pro.tr() : null,
          actionLabel: needsPro
              ? LocaleKeys.home_widgets_plans_button.tr()
              : LocaleKeys.home_widgets_how_button.tr(),
          onAction: needsPro
              ? _openWidgetsPaywall
              : () => _showWidgetsHowTo(setup.widgetsPlan),
          isOnSheet: true,
          onClose: () =>
              unawaited(context.read<HomeSetupCubit>().widgetsCardDismissed()),
          closeLabel: LocaleKeys.home_widgets_dismiss_button.tr(),
        );
      case HomeCreamCard.day0:
        card = AppCreamCard(
          title: LocaleKeys.home_day0_title.tr(),
          body: LocaleKeys.home_day0_free_line.tr(),
          actionLabel: LocaleKeys.home_day0_plans_button.tr(),
          onAction: _openDay0Plans,
          isOnSheet: true,
          onClose: () => unawaited(context.read<Day0CardCubit>().dismiss()),
          closeLabel: LocaleKeys.home_day0_dismiss_button.tr(),
        );
    }
    return Padding(padding: const EdgeInsets.all(4), child: card);
  }

  /// The one bar floating above the tab bar.
  Widget _pinnedBar(HomePinnedBar which, InAppNoticeState notice) {
    final cubit = context.read<InAppNoticeCubit>();
    switch (which) {
      case HomePinnedBar.hostedEnding:
        final endsAt = notice.proEndsAt!;
        return AppPinnedNoticeBar(
          face: FaceState.watching,
          title: LocaleKeys.notices_pro_ending_pill.tr(
            namedArgs: {'weekday': DateFormat('EEEE').format(endsAt)},
          ),
          linkLabel: LocaleKeys.notices_why.tr(),
          onTap: () => unawaited(
            showProPlanSheet(
              context,
              ProEndingView(sheet: ProPlanSheet.ending, endsAt: endsAt),
              onDismiss: () => unawaited(cubit.dismissCurrent()),
            ),
          ),
          onDismiss: () => unawaited(cubit.dismissCurrent()),
        );
      case HomePinnedBar.accountBackup:
        return AppPinnedNoticeBar(
          face: FaceState.watching,
          title: LocaleKeys.notices_account_backup_title.tr(),
          linkLabel: LocaleKeys.notices_why.tr(),
          onTap: () => unawaited(
            showNoticeDetailSheet(
              context: context,
              face: FaceState.watching,
              title: LocaleKeys.notices_account_backup_title.tr(),
              body: LocaleKeys.notices_account_backup_body.tr(),
              actionLabel: LocaleKeys.notices_account_backup_button.tr(),
              onAction: () => openAppPath(context, '/settings/account'),
              onDismiss: () => unawaited(cubit.dismissCurrent()),
            ),
          ),
          onDismiss: () => unawaited(cubit.dismissCurrent()),
        );
      case HomePinnedBar.oneTopic:
        return AppPinnedNoticeBar(
          face: FaceState.watching,
          title: LocaleKeys.home_card_one_topic_title.tr(),
          linkLabel: LocaleKeys.home_card_one_topic_button.tr(),
          onTap: _newTopic,
          onDismiss: _closeOneTopic,
        );
    }
  }
}

/// The hero: the face and the dark card. It redraws each second while the
/// card shows a clock.
class _HeroBlock extends StatefulWidget {
  const _HeroBlock({
    required this.model,
    required this.glance,
    required this.isPane,
    required this.onAction,
    required this.onTapBody,
  });

  final HomeCardModel model;
  final int glance;
  final bool isPane;

  /// Null for an example card, whose button opens nothing.
  final Future<void> Function(HomeCardAction action)? onAction;
  final VoidCallback? onTapBody;

  @override
  State<_HeroBlock> createState() => _HeroBlockState();
}

class _HeroBlockState extends State<_HeroBlock> {
  Timer? _clock;

  bool get _ticks =>
      widget.model.numeral is Elapsed || widget.model.numeral is Remaining;

  @override
  void initState() {
    super.initState();
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant _HeroBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClock();
  }

  void _syncClock() {
    if (_ticks) {
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _clock?.cancel();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final view = homeCardViewFor(model, now: DateTime.now());
    final action = model.action;
    final onAction = widget.onAction;
    return AppHeroScene(
      face: model.face,
      tone: view.heroTone,
      gaze: view.gaze,
      isLive: view.isLive,
      isPane: widget.isPane,
      glance: widget.glance,
      card: AppStatusCard(
        label: view.label,
        numeral: view.numeral,
        numeralTone: view.numeralTone,
        foot: view.foot,
        footTone: view.footTone,
        pips: view.pips,
        actionLabel: view.actionLabel,
        onAction: action == null
            ? null
            : () => unawaited(onAction?.call(action) ?? Future<void>.value()),
        onTap: model.tapsReliability ? widget.onTapBody : null,
        // A clock changes every second, which is no news.
        popsOnChange: !view.ticks,
        liveRegion: view.isLive,
      ),
    );
  }
}

/// Placeholder rows while the list has not answered.
class _LoadingSheet extends StatelessWidget {
  const _LoadingSheet();

  @override
  Widget build(BuildContext context) => AppInboxSheet(
    children: [
      for (var i = 0; i < 3; i++)
        const AppSkeleton(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBone.text(width: 120),
                SizedBox(height: 8),
                AppSkeletonBone.text(),
              ],
            ),
          ),
        ),
    ],
  );
}

/// No topics yet: the dashed card, the tools a first topic is usually for,
/// and the button.
class _EmptyTopics extends StatelessWidget {
  const _EmptyTopics({required this.onTool});

  final void Function([ToolTemplate? tool]) onTool;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppEmptyState(
          title: LocaleKeys.home_card_empty_title.tr(),
          description: LocaleKeys.home_card_empty_body.tr(),
          buttonLabel: LocaleKeys.home_card_empty_button.tr(),
          onButtonPressed: onTool,
          showFace: false,
          radius: Radii.md,
        ),
        const SizedBox(height: Spacing.s4),
        Text(
          LocaleKeys.home_card_empty_tools.tr(),
          style: AppTypography.small(
            colors.onCanvasMuted,
            fontSize: 12,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final template in ToolTemplate.values)
              if (template.label case final label?)
                AppTopicChip(
                  text: label,
                  hitSlop: 4,
                  onTap: () => onTool(template),
                ),
          ],
        ),
      ],
    );
  }
}

/// The sheet is white in every state, but text that follows the canvas (the
/// buttons on a cream card) would turn white on a blue or red canvas. This
/// gives it the sheet's own ink.
class _OnSurface extends StatelessWidget {
  const _OnSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where((ext) => ext is! AppColors),
          colors.copyWith(onCanvas: colors.ink, onCanvasMuted: colors.ink2),
        ],
      ),
      child: child,
    );
  }
}
