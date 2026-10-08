import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/push/device_token_relay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final home = Uri.parse('https://relay.example.com');

  DeviceTokenRelayTrust trust({
    required String relay,
    String? token = 'dv_1',
    String? issuer,
    Uri? session,
  }) => deviceTokenRelayTrust(
    identity: DeviceIdentity(
      deviceId: 'dev_1',
      deviceToken: token,
      tokenRelay: issuer,
    ),
    sessionRelay: session,
    relay: Uri.parse(relay),
  );

  test('a phone with no identity or no token holds nothing back', () {
    expect(
      deviceTokenRelayTrust(identity: null, sessionRelay: home, relay: home),
      DeviceTokenRelayTrust.noToken,
    );
    expect(
      trust(token: null, relay: 'https://other.example.net'),
      DeviceTokenRelayTrust.noToken,
    );
    expect(
      trust(token: '  ', relay: 'https://other.example.net'),
      DeviceTokenRelayTrust.noToken,
    );
  });

  test('the relay saved beside the token is the issuer', () {
    expect(
      trust(issuer: '$home', relay: '$home'),
      DeviceTokenRelayTrust.issuer,
    );
    expect(
      trust(issuer: '$home', relay: 'https://other.example.net'),
      DeviceTokenRelayTrust.otherRelay,
    );
  });

  test('the saved issuer wins over the saved session', () {
    expect(
      trust(
        issuer: '$home',
        session: Uri.parse('https://other.example.net'),
        relay: 'https://other.example.net',
      ),
      DeviceTokenRelayTrust.otherRelay,
    );
  });

  test('a token with no saved issuer was issued by the relay of the saved '
      'session', () {
    expect(trust(session: home, relay: '$home'), DeviceTokenRelayTrust.issuer);
    expect(
      trust(session: home, relay: 'https://other.example.net'),
      DeviceTokenRelayTrust.otherRelay,
    );
  });

  test('a token with no saved issuer and no saved session has no known '
      'issuer', () {
    expect(trust(relay: '$home'), DeviceTokenRelayTrust.unknownIssuer);
  });

  test('the same relay written another way is still the issuer', () {
    for (final written in [
      'https://relay.example.com/',
      'HTTPS://Relay.Example.com',
      'https://relay.example.com:443',
      ' https://relay.example.com ',
    ]) {
      expect(
        trust(issuer: '$home', relay: written.trim()),
        DeviceTokenRelayTrust.issuer,
        reason: written,
      );
    }
  });

  test('anything else is another relay', () {
    for (final written in [
      'http://relay.example.com',
      'https://relay.example.com:8443',
      'https://relay.example.com/v2',
      'https://relay.example.com.',
      'https://user@relay.example.com',
      'https://relay.example.com?x=1',
      'https://relay.example.com.other.example.net',
    ]) {
      expect(
        trust(issuer: '$home', relay: written),
        DeviceTokenRelayTrust.otherRelay,
        reason: written,
      );
    }
  });
}
