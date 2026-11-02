import 'package:critalarm/core/store/services/store_links.dart';
import 'package:critalarm/core/store/services/store_review.dart';
import 'package:in_app_review/in_app_review.dart';

/// [StoreReview] through `in_app_review`: the Play in-app review flow and
/// the App Store rating prompt.
final class InAppStoreReview implements StoreReview {
  InAppStoreReview([InAppReview? review])
    : _review = review ?? InAppReview.instance;

  final InAppReview _review;

  @override
  Future<bool> isAvailable() => _review.isAvailable();

  @override
  Future<void> request() => _review.requestReview();
}

/// [StoreLinks] through `in_app_review`, which opens the Play listing by
/// package name and the App Store listing by [appStoreId].
final class InAppStoreLinks implements StoreLinks {
  InAppStoreLinks({required this.appStoreId, InAppReview? review})
    : _review = review ?? InAppReview.instance;

  /// The App Store's numeric id for the app. Blank until the listing has
  /// one.
  final String appStoreId;
  final InAppReview _review;

  @override
  Future<void> listing() => _review.openStoreListing(appStoreId: appStoreId);
}
