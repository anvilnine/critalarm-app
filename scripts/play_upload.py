#!/usr/bin/env python3
"""Upload an Android app bundle to Google Play.

Called by scripts/release-android.sh. Usable on its own if you already have a
bundle you want to push.

Only the Python standard library plus the openssl command, which macOS ships.
No pip install, no fastlane, no Ruby. The one thing stdlib cannot do is sign an
RS256 JWT, so that single step shells out to openssl.

What it does, in the order Play requires:

  1. Sign a JWT with the service account key and trade it for an access token.
  2. Open an "edit", which is Play's transaction. Nothing is visible until the
     edit is committed, and an edit that is never committed changes nothing.
  3. Upload the .aab. Play answers with the version code it read out of it.
  4. Point a track at that version code.
  5. Commit.

Usage:
  play_upload.py --aab build/app/outputs/bundle/release/app-release.aab \\
                 --package app.critalarm \\
                 --key ../secrets/play-publisher.json \\
                 --track internal
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

TOKEN_URL = "https://oauth2.googleapis.com/token"
API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def die(message):
    sys.stderr.write("play-upload: %s\n" % message)
    raise SystemExit(1)


def say(message):
    sys.stdout.write("\n\033[1m==> %s\033[0m\n" % message)
    sys.stdout.flush()


def b64url(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def access_token(service_account):
    """Trade a signed JWT for an access token, the two legged OAuth flow."""
    email = service_account.get("client_email")
    private_key = service_account.get("private_key")
    if not email or not private_key:
        die("the key file has no client_email or private_key. "
            "It should be the JSON Google Cloud hands you for a service account.")

    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {
        "iss": email,
        "scope": SCOPE,
        "aud": TOKEN_URL,
        "iat": now,
        # Google caps this at an hour. An upload takes minutes, so an hour is
        # plenty and a shorter window only risks expiring mid transfer.
        "exp": now + 3600,
    }
    signing_input = (
        b64url(json.dumps(header, separators=(",", ":")).encode())
        + b"."
        + b64url(json.dumps(claims, separators=(",", ":")).encode())
    )

    # openssl wants the key on disk. Write it with owner only permissions and
    # delete it in the finally, so it never outlives this call.
    handle, path = tempfile.mkstemp(suffix=".pem")
    try:
        os.fchmod(handle, 0o600)
        with os.fdopen(handle, "w") as f:
            f.write(private_key)
        signed = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", path],
            input=signing_input,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if signed.returncode != 0:
            die("openssl could not sign the token: %s"
                % signed.stderr.decode().strip())
    finally:
        os.unlink(path)

    jwt = signing_input + b"." + b64url(signed.stdout)
    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": jwt.decode(),
    }).encode()

    try:
        with urllib.request.urlopen(
            urllib.request.Request(TOKEN_URL, data=body)
        ) as response:
            return json.load(response)["access_token"]
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        if "invalid_grant" in detail:
            die("Google refused the key.\n"
                "  Usually this means the service account is not linked in Play "
                "Console, or the machine clock is wrong.\n"
                "  %s" % detail)
        die("could not get an access token: %s %s" % (error.code, detail))


def call(token, method, url, payload=None, raw=None, content_type=None):
    headers = {"Authorization": "Bearer " + token}
    data = raw
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    if content_type:
        headers["Content-Type"] = content_type

    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request) as response:
            text = response.read().decode()
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        die("%s %s failed: %s\n  %s" % (method, url.split("?")[0], error.code, detail))


def upload_bundle(token, package, edit_id, aab_path):
    size = os.path.getsize(aab_path)
    url = "%s/applications/%s/edits/%s/bundles?uploadType=media" % (
        UPLOAD, package, edit_id)
    headers = {
        "Authorization": "Bearer " + token,
        "Content-Type": "application/octet-stream",
        "Content-Length": str(size),
    }
    with open(aab_path, "rb") as handle:
        request = urllib.request.Request(
            url, data=handle, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(request) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")
            if "APK specifies a version code that has already been used" in detail \
                    or "already been used" in detail:
                die("Play already has this version code.\n"
                    "  Bump the build number in pubspec.yaml and build again, "
                    "or run release-android.sh with --bump.\n  %s" % detail)
            die("the upload failed: %s\n  %s" % (error.code, detail))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aab", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--track", default="internal")
    parser.add_argument(
        "--status", default="completed", choices=["draft", "completed"],
        help="completed makes the build live on the track. draft leaves it for "
             "a human to roll out in Play Console.")
    parser.add_argument(
        "--validate-only", action="store_true",
        help="do everything except commit, then throw the edit away. Nothing "
             "reaches the track.")
    args = parser.parse_args()

    if not os.path.isfile(args.aab):
        die("no bundle at %s" % args.aab)
    if not os.path.isfile(args.key):
        die("no service account key at %s" % args.key)

    with open(args.key) as handle:
        service_account = json.load(handle)

    say("Signing in as %s" % service_account.get("client_email", "?"))
    token = access_token(service_account)

    say("Opening an edit")
    edit = call(token, "POST", "%s/applications/%s/edits" % (API, args.package))
    edit_id = edit["id"]

    try:
        say("Uploading %s (%.1f MB)"
            % (os.path.basename(args.aab), os.path.getsize(args.aab) / 1e6))
        bundle = upload_bundle(token, args.package, edit_id, args.aab)
        version_code = bundle["versionCode"]
        print("   version code %s" % version_code)

        say("Pointing the %s track at version code %s" % (args.track, version_code))
        call(
            token, "PUT",
            "%s/applications/%s/edits/%s/tracks/%s"
            % (API, args.package, edit_id, args.track),
            payload={
                "track": args.track,
                "releases": [{
                    "versionCodes": [str(version_code)],
                    "status": args.status,
                }],
            },
        )

        if args.validate_only:
            call(token, "DELETE",
                 "%s/applications/%s/edits/%s" % (API, args.package, edit_id))
            say("Validated and thrown away. Nothing reached the %s track."
                % args.track)
            return

        say("Committing")
        call(token, "POST",
             "%s/applications/%s/edits/%s:commit" % (API, args.package, edit_id))
        say("Version code %s is on the %s track" % (version_code, args.track))
        print("\nPlay processes the bundle before testers can install it, "
              "usually a few minutes.")
        print("Internal testing needs no review.\n")
    except SystemExit:
        # An uncommitted edit changes nothing, but leaving it open clutters the
        # account, so clean up before the error propagates.
        try:
            call(token, "DELETE",
                 "%s/applications/%s/edits/%s" % (API, args.package, edit_id))
        except SystemExit:
            pass
        raise


if __name__ == "__main__":
    main()
