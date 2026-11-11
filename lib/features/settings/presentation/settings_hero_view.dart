import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/own_server.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

/// A button on the account and plan card at the top of Settings.
enum SettingsHeroAction {
  /// Opens the Cloud paywall. Only where Cloud is not held.
  seeCloud,

  /// Opens the store's own subscription page. Cloud held, on a build and a
  /// platform that has the customer centre.
  manage,

  /// Opens the Pro paywall. Only while Pro is known not to be owned.
  seePro,
}

/// What the line under the plan name says.
enum SettingsHeroLine {
  /// "Signed in with Apple", from the account's providers.
  signedIn,

  /// Accounts exist on this server and nobody is signed in.
  signedOut,

  /// A server of the user's own: no accounts, no limits, no charge.
  ownServer,

  /// Settings are not read yet. No line, so "Not signed in" never flashes
  /// for a person who is signed in.
  none,
}

/// What the account and plan card at the top of Settings shows, as plain
/// values. It follows the same rules the plan card and the Pro row follow on
/// the Account and plan page, so the two never disagree. Pure, so it is unit
/// tested; the widget only translates it.
@immutable
class SettingsHeroView {
  const SettingsHeroView({
    required this.planKey,
    required this.line,
    required this.actions,
    required this.ownsPro,
  });

  /// [serverMode] is null until the server has been read. [loaded] is false
  /// until the plan has been read, and the name stays blank until then, so
  /// "Plan unavailable" never flashes on a slow start. [planKnown] is whether
  /// the server said what the plan is. [proState] is null until the phone has
  /// been asked, and no Pro button shows until then, so a person who owns Pro
  /// is never offered it for a moment.
  factory SettingsHeroView.from({
    required ServerMode? serverMode,
    required bool loaded,
    required bool holdsHosted,
    required bool planKnown,
    required HoldingState? proState,
    required bool signedIn,
    required bool canManage,
  }) {
    final ownServer = isOwnServerMode(serverMode);
    final offersPro =
        proState == HoldingState.notHeld || proState == HoldingState.unknown;
    final String? planKey;
    if (ownServer) {
      planKey = LocaleKeys.settings_server_self_hosted;
    } else if (holdsHosted) {
      // A purchase the store confirmed counts as Cloud before the server
      // has registered it, as on the plan card.
      planKey = LocaleKeys.settings_plan_pro;
    } else if (!loaded) {
      planKey = null;
    } else if (!planKnown) {
      planKey = LocaleKeys.account_plan_unavailable;
    } else {
      planKey = LocaleKeys.settings_plan_free;
    }
    final line = ownServer
        ? SettingsHeroLine.ownServer
        : !loaded
        ? SettingsHeroLine.none
        : signedIn
        ? SettingsHeroLine.signedIn
        : SettingsHeroLine.signedOut;
    return SettingsHeroView(
      planKey: planKey,
      line: line,
      actions: [
        if (!ownServer && !holdsHosted) SettingsHeroAction.seeCloud,
        if (!ownServer && holdsHosted && canManage) SettingsHeroAction.manage,
        if (offersPro) SettingsHeroAction.seePro,
      ],
      ownsPro: proState == HoldingState.held,
    );
  }

  /// A `LocaleKeys` key for the plan name, or null while it is not read.
  final String? planKey;

  final SettingsHeroLine line;

  /// The buttons under the name, in order. Empty draws none.
  final List<SettingsHeroAction> actions;

  /// Pro is owned, so the card carries the Pro badge.
  final bool ownsPro;
}
