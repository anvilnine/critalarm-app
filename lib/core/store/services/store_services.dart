import 'package:critalarm/core/platform/store_kind.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/store/services/google_sign_in_sheet.dart';
import 'package:critalarm/core/store/services/manage_subscription.dart';
import 'package:critalarm/core/store/services/sign_in_options.dart';
import 'package:critalarm/core/store/services/sound_pack_source.dart';
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/store/services/store_links.dart';
import 'package:critalarm/core/store/services/store_review.dart';

/// Everything a store decides, for one store.
///
/// `lib/app/di.dart` picks one set by [StoreKind] and registers each part
/// in `get_it`. Feature code asks for the part it needs and never learns
/// which store it is talking to.
abstract interface class StoreServices {
  /// The store this set is for.
  StoreKind get store;

  /// Where the alarm push token comes from.
  PushTokenProvider get pushTokens;

  /// Cloud and the Pro pack: what is on sale, buying, restoring.
  StoreBilling get billing;

  /// The store's place to see or cancel the plan.
  ManageSubscription get manageSubscription;

  /// Which sign-in providers this build shows.
  SignInOptions get signInOptions;

  /// Google's sign-in sheet.
  GoogleSignInSheet get googleSignIn;

  /// The store's "rate this app" popup.
  StoreReview get review;

  /// This app's pages in the store app.
  StoreLinks get links;

  /// Where the sound packs come from.
  SoundPackSource get soundPacks;
}
