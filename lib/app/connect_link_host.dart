import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/popup_route_tracker.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/core/links/connect_link_holder.dart';
import 'package:critalarm/core/telemetry/connect_link_analytics.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_link_coordinator.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_sheet_rules.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/connect_link_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/connect_link_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens the connect sheet when a connect link has been tapped and the app
/// can show one.
///
/// The link waits in [ConnectLinkHolder] until then. Every change that can
/// let it through asks again: a route change, an alarm starting or ending, a
/// sheet closing, a Feature Guide ending, the app coming back to the front.
/// The rule itself is [canShowConnectSheetNow].
///
/// An alarm that starts while the sheet is up closes it, so nothing stands
/// between the person and the alarm.
class ConnectLinkHost extends StatefulWidget {
  const ConnectLinkHost({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<ConnectLinkHost> createState() => _ConnectLinkHostState();
}

class _ConnectLinkHostState extends State<ConnectLinkHost>
    with WidgetsBindingObserver {
  late final ConnectLinkCoordinator _coordinator = ConnectLinkCoordinator(
    links: getIt<ConnectLinkHolder>(),
    readSituation: _readSituation,
    showSheet: _present,
    checkAgain: _stillAllowed,
  );

  StreamSubscription<bool>? _alarmSub;
  StreamSubscription<dynamic>? _guideSub;

  /// The sheet that is up, so an alarm can close it.
  Route<dynamic>? _sheetRoute;
  BuildContext? _sheetContext;
  bool _closedByAlarm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_ask);
    appPopupRoutes.changes.addListener(_ask);
    _alarmSub = getIt<AlarmFocus>().stream.listen(_onAlarm);
    _guideSub = getIt<FeatureGuideCubit>().stream.listen((_) => _ask());
    // A link can be waiting from a cold start. Ask once the first frame is
    // up, because the sheet needs the navigator's overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _coordinator.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.router.routerDelegate.removeListener(_ask);
    appPopupRoutes.changes.removeListener(_ask);
    unawaited(_alarmSub?.cancel());
    unawaited(_guideSub?.cancel());
    unawaited(_coordinator.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ask();
  }

  /// After the frame, not now: the router tells its listeners before the
  /// navigator has swapped its pages, and a sheet pushed at that point would
  /// sit on a page that is leaving.
  void _ask() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_coordinator.check());
    });
  }

  void _onAlarm(bool on) {
    if (!on) {
      _ask();
      return;
    }
    _closeForAlarm();
  }

  BuildContext? get _overlayContext =>
      widget.router.routerDelegate.navigatorKey.currentState?.overlay?.context;

  /// The page on top. The router's own address stays on the page underneath
  /// after a push, so it is read off the top page instead.
  Uri get _location {
    final delegate = widget.router.routerDelegate;
    if (delegate.currentConfiguration.isEmpty) return Uri();
    return delegate.state.uri;
  }

  bool get _onConnectStep =>
      _location.path == OnboardingEntryPoint.connectServer;

  /// The part of the rule that can change while the setup answer is being
  /// read, asked once more right before the sheet opens: an alarm, a screen
  /// that owns the display, another sheet, no overlay to open in.
  bool _stillAllowed() {
    final context = _overlayContext;
    return !getIt<AlarmFocus>().on &&
        !isConnectSheetBlockedPath(_location.path) &&
        !appPopupRoutes.isUp &&
        !getIt<FeatureGuideCubit>().state.isActive &&
        context != null &&
        context.mounted;
  }

  Future<ConnectSheetSituation> _readSituation() async {
    final done =
        (await getIt<GetOnboardingCompletedUsecase>()(
          const NoParams(),
        )).getOrNull() ??
        false;
    final context = _overlayContext;
    return ConnectSheetSituation(
      setupDone: done,
      onConnectStep: _onConnectStep,
      alarmOn: getIt<AlarmFocus>().on,
      blockedScreen: isConnectSheetBlockedPath(_location.path),
      // No overlay yet reads as a sheet being up: there is nowhere to open.
      sheetUp:
          appPopupRoutes.isUp ||
          getIt<FeatureGuideCubit>().state.isActive ||
          context == null ||
          !context.mounted,
    );
  }

  Future<ConnectSheetEnd> _present(ConnectLink link) async {
    final context = _overlayContext;
    if (context == null || !context.mounted) return ConnectSheetEnd.interrupted;
    final onStep = _onConnectStep;
    final isReplay = isOnboardingReplayUri(_location);
    final cubit = ConnectLinkCubit(
      link,
      connectToServer: getIt<ConnectToServerUsecase>(),
      readConnection: getIt<GetConnectionUsecase>(),
      readServerMode: () => getIt<AccountRepository>().readServerMode(),
      events: getIt<ConnectLinkAnalytics>(),
      // Topics, incidents and the no-server card on Home load again, and
      // the reminders are planned again, the same as after a Cloud connect.
      afterConnected: () async => appAccountIdentityChanges.bump(),
    );
    _closedByAlarm = false;
    var wasConnecting = false;
    try {
      unawaited(cubit.open());
      await showConnectLinkSheet(
        context,
        cubit: cubit,
        onShown: (sheetContext) {
          _sheetContext = sheetContext;
          _sheetRoute = ModalRoute.of(sheetContext);
        },
      );
      wasConnecting = cubit.state.isConnecting;
      // A sheet that went away mid-connect still lets the connect finish.
      if (wasConnecting) {
        await cubit.stream.firstWhere((state) => !state.isConnecting);
      }
      if (_closedByAlarm) {
        cubit.interrupted();
        return wasConnecting || cubit.state.isConnected
            ? ConnectSheetEnd.interruptedWhileConnecting
            : ConnectSheetEnd.interrupted;
      }
      if (!cubit.state.isConnected) {
        cubit.notNow();
        return ConnectSheetEnd.left;
      }
      // Where the manual flow goes: on from the connect step. Anywhere
      // else the person stays where they were.
      if (onStep) {
        await finishOnboardingStepOn(
          widget.router,
          OnboardingStepId.connect,
          isReplay: isReplay,
        );
      }
      return ConnectSheetEnd.connected;
    } finally {
      _sheetRoute = null;
      _sheetContext = null;
      await cubit.close();
    }
  }

  /// Takes the sheet down, and only the sheet.
  void _closeForAlarm() {
    final route = _sheetRoute;
    final sheetContext = _sheetContext;
    if (route == null || sheetContext == null || !sheetContext.mounted) return;
    _closedByAlarm = true;
    if (route.isCurrent) {
      Navigator.of(sheetContext).pop();
    } else if (route.isActive) {
      Navigator.of(sheetContext).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
