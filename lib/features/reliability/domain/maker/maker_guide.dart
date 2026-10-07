import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:flutter/foundation.dart';

/// The route name of the guide page. `AppRoute.makerGuide` is this value.
/// It lives here so the Reliability screen can tell a fix that opens the
/// guide from any other route.
const makerGuideRouteName = 'makerGuide';

/// One step of a guide. The words live in `en.json` under [textKey], so a
/// wrong step is a one-line fix there. Everything else about the step is
/// recorded here, beside it.
@immutable
final class MakerStep {
  const MakerStep({
    required this.textKey,
    required this.writtenFor,
    required this.sources,
    required this.isConfirmed,
    this.note,
  });

  /// A `LocaleKeys` key.
  final String textKey;

  /// The Android or skin versions the words were written for. For whoever
  /// edits the step, it is not drawn.
  final String writtenFor;

  /// Pages that state the step, as URLs.
  final List<String> sources;

  /// True only when a page named in [sources] was read and states the step.
  /// It does not mean anyone tried it on a phone. Nothing here has been.
  final bool isConfirmed;

  /// What is unconfirmed when [isConfirmed] is false, or what differs by
  /// version when it is true.
  final String? note;
}

const _appDetailsDoc =
    'https://developer.android.com/reference/android/provider/Settings'
    '#ACTION_APPLICATION_DETAILS_SETTINGS';

/// How to reach a settings page, as a candidate for the native side to try.
enum MakerIntentKind {
  /// An activity of another app, named by [MakerIntentCandidate.package] and
  /// [MakerIntentCandidate.component].
  component,

  /// A system action, named by [MakerIntentCandidate.action].
  action,

  /// This app's own page in the system settings. Every phone has it.
  appDetails,
}

/// One settings page to try opening. Sent to the native side as a map.
@immutable
final class MakerIntentCandidate {
  const MakerIntentCandidate.component({
    required String this.package,
    required String this.component,
    required this.sources,
    this.isConfirmed = false,
    this.note,
  }) : kind = MakerIntentKind.component,
       action = null;

  const MakerIntentCandidate.action({
    required String this.action,
    required this.sources,
    this.isConfirmed = false,
    this.note,
  }) : kind = MakerIntentKind.action,
       package = null,
       component = null;

  /// The app's own page. A documented Android action, so it is confirmed.
  const MakerIntentCandidate.appDetails()
    : kind = MakerIntentKind.appDetails,
      package = null,
      component = null,
      action = null,
      sources = const [_appDetailsDoc],
      isConfirmed = true,
      note = null;

  final MakerIntentKind kind;
  final String? package;
  final String? component;
  final String? action;
  final List<String> sources;

  /// True only when a page named in [sources] states that this opens the
  /// page it is used for. A class name seen in a library is not that.
  final bool isConfirmed;
  final String? note;

  /// The map the native `MakerSettingsLauncher` reads.
  Map<String, String> toMap() => {
    'kind': kind.name,
    'package': ?package,
    'component': ?component,
    'action': ?action,
  };

  @override
  bool operator ==(Object other) =>
      other is MakerIntentCandidate &&
      other.kind == kind &&
      other.package == package &&
      other.component == component &&
      other.action == action;

  @override
  int get hashCode => Object.hash(kind, package, component, action);

  @override
  String toString() =>
      'MakerIntentCandidate(${kind.name}, ${package ?? action ?? ''}'
      '${component == null ? '' : '/$component'})';
}

/// Everything one family's page needs.
@immutable
final class MakerGuide {
  const MakerGuide({
    required this.family,
    required this.nameKey,
    required this.steps,
    required this.intents,
    required this.moreUrl,
  });

  final MakerFamily family;

  /// A `LocaleKeys` key: the family's name, such as "Xiaomi, Redmi, Poco".
  final String nameKey;

  /// Three to five, in the order to do them.
  final List<MakerStep> steps;

  /// Settings pages to try, nearest first. The app's own page is added last
  /// by `makerIntentOrder`, so it is not listed here.
  final List<MakerIntentCandidate> intents;

  /// The maker's page on dontkillmyapp.com.
  final String moreUrl;
}
