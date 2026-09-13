// A real HTTP front door for the in-app mock server, so the iOS Notification
// Service Extension has something to fetch.
//
// The extension resolves a `relay_content: none` push with
// `GET /v1/incidents/{id}` (api.md §3.2). Nothing else in the repo serves that
// over a socket: `MockServer` answers an `http.Client` inside the app. This
// binds it to a port and forwards every request to the same handler, so the
// extension sees the same fixtures the app's tests do.
//
//   fvm dart run scripts/push/mock_server.dart [port]
//
// Stop it with Ctrl-C to watch the extension fall back to the placeholder.
import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/api/mock_server.dart';
import 'package:http/http.dart' as http;

/// The incident the fixtures in `scripts/push/*.apns` point at.
const incidentId = 'inc_alarmed_proddb';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8787 : int.parse(args.first);
  // The newest message is the one the extension shows. Give it an emoji tag
  // and a click URL so both paths are visible in the delivered notification.
  // Priority 5 on an open critical topic joins the incident (api.md §1.7), so
  // the id stays the one the fixtures use.
  final mock = MockServer()
    ..seedAlarmed()
    ..publishMessage(
      'prod-db',
      title: 'Database down',
      message: 'db01 is unreachable from every region, page the on-call',
      priority: 5,
      tags: const ['rotating_light', 'db01'],
      click: 'https://status.example.com/db01',
    );

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout
    ..writeln('mock server on http://127.0.0.1:$port')
    ..writeln('incident: GET /v1/incidents/$incidentId');

  await for (final request in server) {
    final body = await utf8.decoder.bind(request).join();
    final proxied = http.Request(request.method, request.uri)..body = body;
    final response = await mock.handleHttpRequest(proxied);

    stdout.writeln(
      '${request.method} ${request.uri.path} -> ${response.statusCode}',
    );

    request.response
      ..statusCode = response.statusCode
      ..headers.contentType = ContentType.json
      ..write(response.body);
    await request.response.close();
  }
}
