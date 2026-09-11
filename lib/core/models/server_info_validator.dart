import 'dart:convert';
import 'package:critalarm/core/models/server_info.dart';
import 'package:crypto/crypto.dart';

/// Validation logic for server URLs, `/v1/info` payloads, semver compatibility,
/// and relay topic hash derivation.
abstract final class ServerInfoValidation {
  /// Validates a server URL string.
  ///
  /// Returns `true` if [url] is non-empty, has an `http` or `https` scheme,
  /// and contains a non-empty host (with optional port).
  static bool isValidServerUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  /// Normalizes a base URL by trimming whitespace and removing trailing
  /// slashes.
  static String normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Checks if [version] has a supported major version.
  ///
  /// Server API contract §6 specifies:
  /// "GET /v1/info.version is semver. App refuses servers with a major version
  /// it does not know."
  /// Currently v0.x ([supportedMajor] = 0) is supported. Future major
  /// versions (e.g. 1.x, 2.x) are rejected.
  static bool isSemverCompatible(String? version, {int supportedMajor = 0}) {
    if (version == null) return false;
    final trimmed = version.trim();
    final match = RegExp(r'^v?(\d+)\.').firstMatch(trimmed);
    if (match == null) return false;
    final major = int.tryParse(match.group(1)!);
    return major == supportedMajor;
  }

  /// Validates operational mode according to API contract §3.4:
  /// `selfhosted`, `relay`, or `hosted`.
  static bool isValidMode(String? mode) {
    if (mode == null) return false;
    return ServerModes.validModes.contains(mode.trim().toLowerCase());
  }

  /// Derives topic hash per API contract §4.1:
  /// `sha256(base_url + "/" + topic)` as a lowercase hex string.
  ///
  /// Normalizes [baseUrl] by stripping trailing slashes and normalizes [topic]
  /// by stripping leading slashes.
  static String deriveTopicHash({
    required String baseUrl,
    required String topic,
  }) {
    final cleanBase = normalizeBaseUrl(baseUrl);
    final cleanTopic = topic.trim().replaceAll(RegExp('^/+'), '');
    final input = '$cleanBase/$cleanTopic';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Validates a complete [ServerInfo] model payload.
  static bool isValidServerInfo(
    ServerInfo info, {
    int supportedMajor = 0,
  }) {
    return isSemverCompatible(info.version, supportedMajor: supportedMajor) &&
        isValidServerUrl(info.baseUrl) &&
        isValidServerUrl(info.relayUrl) &&
        isValidMode(info.mode);
  }
}
