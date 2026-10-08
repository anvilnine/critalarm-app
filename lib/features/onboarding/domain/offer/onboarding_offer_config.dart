import 'dart:convert';

import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:flutter/foundation.dart';

/// The four switches of the `offer` setup step.
///
/// Where the step sits is not one of them: that is its place in the flow
/// list. The step holds no words and no prices of its own, so neither does
/// this.
@immutable
class OnboardingOfferConfig {
  const OnboardingOfferConfig({
    required this.enabled,
    required this.cloudProduct,
    required this.selfHostedProduct,
    required this.layoutKey,
  });

  /// What ships inside the app: the step is off.
  static const bundled = OnboardingOfferConfig(
    enabled: false,
    cloudProduct: PaywallProduct.pro,
    selfHostedProduct: PaywallProduct.pro,
    layoutKey: 'plain',
  );

  /// The field names of the JSON value, remote and developer alike.
  static const enabledField = 'enabled';
  static const cloudProductField = 'cloud_product';
  static const selfHostedProductField = 'self_hosted_product';
  static const layoutField = 'layout';

  /// What a product field says when nothing is offered.
  static const noProduct = 'none';

  /// The layout key becomes an analytics parameter, so it stays short and
  /// plain. Whether a layout with that key is built is asked later.
  static final _layoutPattern = RegExp(r'^[a-z0-9_]{1,40}$');

  final bool enabled;

  /// What a phone on Crit Alarm Cloud is offered. Null for nothing.
  final PaywallProduct? cloudProduct;

  /// What a phone on a self-hosted server is offered: the Pro pack or
  /// nothing. Null for nothing.
  final PaywallProduct? selfHostedProduct;

  /// A `PaywallLayoutId.key`, as written. It may name a layout this build
  /// does not have.
  final String layoutKey;

  /// Reads the JSON text of a remote or developer value. A field that is
  /// left out takes its bundled default. Null when the text is empty, is
  /// not a JSON object, or holds a field with a value it cannot have: the
  /// whole value is then set aside and the next source is asked, so a typo
  /// never shows an offer nobody meant.
  static OnboardingOfferConfig? tryParse(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final enabled = decoded[enabledField] ?? bundled.enabled;
    if (enabled is! bool) return null;

    final layout = decoded[layoutField] ?? bundled.layoutKey;
    if (layout is! String || !_layoutPattern.hasMatch(layout)) return null;

    final cloud = _product(
      decoded[cloudProductField],
      fallback: bundled.cloudProduct,
      allowed: const {PaywallProduct.pro, PaywallProduct.hosted},
    );
    final selfHosted = _product(
      decoded[selfHostedProductField],
      fallback: bundled.selfHostedProduct,
      allowed: const {PaywallProduct.pro},
    );
    if (cloud == null || selfHosted == null) return null;

    return OnboardingOfferConfig(
      enabled: enabled,
      cloudProduct: cloud.product,
      selfHostedProduct: selfHosted.product,
      layoutKey: layout,
    );
  }

  /// One product field. Null when the value is not one it can have.
  static ({PaywallProduct? product})? _product(
    Object? value, {
    required PaywallProduct? fallback,
    required Set<PaywallProduct> allowed,
  }) {
    if (value == null) return (product: fallback);
    if (value == noProduct) return (product: null);
    for (final product in allowed) {
      if (product.key == value) return (product: product);
    }
    return null;
  }

  /// The JSON text [tryParse] reads back.
  String encode() => jsonEncode({
    enabledField: enabled,
    cloudProductField: cloudProduct?.key ?? noProduct,
    selfHostedProductField: selfHostedProduct?.key ?? noProduct,
    layoutField: layoutKey,
  });

  @override
  bool operator ==(Object other) =>
      other is OnboardingOfferConfig &&
      enabled == other.enabled &&
      cloudProduct == other.cloudProduct &&
      selfHostedProduct == other.selfHostedProduct &&
      layoutKey == other.layoutKey;

  @override
  int get hashCode =>
      Object.hash(enabled, cloudProduct, selfHostedProduct, layoutKey);

  @override
  String toString() => 'OnboardingOfferConfig(${encode()})';
}

/// Which source the offer switches came from.
enum OnboardingOfferOrigin { developer, remote, bundled }

/// The switches in use, and the source that gave them.
@immutable
class ChosenOnboardingOffer {
  const ChosenOnboardingOffer(this.config, this.origin);

  final OnboardingOfferConfig config;
  final OnboardingOfferOrigin origin;
}

/// Picks the offer switches the same way a flow is picked: the developer
/// value, then the remote value, then what ships inside the app. A value
/// that does not read is passed over, so the bundled one, with the step
/// off, is where a bad value ends.
ChosenOnboardingOffer chooseOnboardingOffer({
  required String? developerJson,
  required String? remoteJson,
}) {
  final developer = OnboardingOfferConfig.tryParse(developerJson);
  if (developer != null) {
    return ChosenOnboardingOffer(developer, OnboardingOfferOrigin.developer);
  }
  final remote = OnboardingOfferConfig.tryParse(remoteJson);
  if (remote != null) {
    return ChosenOnboardingOffer(remote, OnboardingOfferOrigin.remote);
  }
  return const ChosenOnboardingOffer(
    OnboardingOfferConfig.bundled,
    OnboardingOfferOrigin.bundled,
  );
}
