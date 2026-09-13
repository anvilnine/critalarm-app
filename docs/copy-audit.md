# Copy audit

Every user-facing string in the app, checked against the `ui-microcopy` rules and the voice in
`docs/design-system/NOTES.md` plus the mockup copy in `docs/design-system/index.html`.

Source of truth for the strings is `assets/translations/en.json`. Keys below are the JSON paths.
The Dart accessor for `onboarding_connect.title` is `LocaleKeys.onboarding_connect_title.tr()`.

## Fact constraints applied

These five rules beat any wording preference. Every proposed line respects them.

1. Never claim the app rings through the iOS silent switch or Do Not Disturb. The Critical Alerts
   entitlement is tied to the signing identity and is not granted yet. Promise the acknowledge
   loop instead, which is true on both platforms.
2. "Crit Alarm Cloud" is coming soon until hosted sign-in ships. No string may read as if a user
   can sign in today.
3. The critical toggle copy has to say two things: it is off by default, and what turning it on
   does.
4. Permission-denied copy says what will not work. It never says the app is broken.
5. Keep numbers, paths, commands, tokens and endpoints exact. Plain language is for the prose
   around them.

## Problem classes

| Class | What it means |
|---|---|
| `unsafe-claim` | Breaks a fact constraint above. |
| `explains-the-build` | Tells the user how the feature works inside, or that it is unfinished. |
| `two-ideas` | Two separate thoughts in one string. Split it or move half. |
| `wrong-screen` | True, but it belongs on a different screen. |
| `jargon` | Platform or vendor vocabulary on a user screen. |
| `marketing` | Sells instead of stating. |
| `filler` | Words that carry nothing. |
| `leak` | A developer name, vendor name or placeholder that should never ship. |
| `case` | Title Case where the rest of the app uses sentence case. |
| `missing-fact` | A constraint above requires a fact this string does not carry. |
| `ok` | No change. |

Only rows with a class other than `ok` are listed. Everything not listed stays exactly as it is.

---

## Group 1: onboarding

| Key | Current | Class | Proposed |
|---|---|---|---|
| `onboarding_connect.subtitle` | One HTTP endpoint per topic. Point your scripts, cron, or monitoring tools at Crit Alarm. | `two-ideas`, `wrong-screen` | Enter the address of your Crit Alarm server and its admin token. Both are printed when the server starts. |
| `onboarding_connect.url_helper` | Defaults to https://api.critalarm.app. Change this if you run your own instance. | `filler` | Change this if you run your own server. |
| `onboarding_connect.qr_notice` | QR scanner placeholder - paste token instead | `explains-the-build` | Scanning is not ready yet. Paste the token instead. |
| `onboarding_connect.cloud_description` | Hosted sign-in coming soon. For now, enter your self-hosted server URL and admin token above. | `filler` | Hosted sign-in is coming. For now, connect your own server. |
| `onboarding_connect.cloud_button` | Sign in with Crit Alarm Cloud | `unsafe-claim` | Crit Alarm Cloud is not open yet |
| `onboarding_connect.version_incompatible` | Server version {version} is incompatible. Crit Alarm requires v0.x. | `filler` | This app needs a v0.x server. Yours is {version}. |
| `onboarding_connect.ring_title` | Never miss a critical page | `marketing` | Try it now |
| `onboarding_connect.ring_body` | Critical Alerts play through your silent switch and Do Not Disturb. When your server triggers a priority-5 page, Crit Alarm rings continuously until you acknowledge it. | `unsafe-claim`, `two-ideas` | A critical page rings and repeats every 30 s. It stops when you acknowledge it. |
| `onboarding_connect.ring_toast_sent` | Test alarm sent to | `filler` | Test alarm sent to |
| `onboarding_connect.ring_toast_failed` | Failed to trigger test alarm | `filler` | Could not send the test alarm. |
| `onboarding_connect.dashboard_button` | Go to Dashboard | `case` | Go to your topics |
| `onboarding_permissions.badge` | Rings through silent & DND | `unsafe-claim` | Repeats until you acknowledge |
| `onboarding_permissions.subtitle` | Crit Alarm wakes your screen and rings continuously until acknowledged, bypassing your silent switch and Do Not Disturb when critical incidents occur. | `unsafe-claim`, `two-ideas` | A critical page wakes the screen and repeats every 30 s until you acknowledge it. |
| `onboarding_permissions.post_notifications` | Android 13+ POST_NOTIFICATIONS: alerts you immediately when a service goes down. | `jargon`, `explains-the-build` | Notifications, so a page can reach you. |
| `onboarding_permissions.full_screen_intent` | Android 14+ USE_FULL_SCREEN_INTENT: wakes the display for urgent priority-5 emergencies. | `jargon`, `explains-the-build` | Full-screen alerts, so a critical page wakes the screen. |
| `onboarding_permissions.denied_description` | Critical alerts won't wake the screen, and notifications will be silent or missing. | `ok` (constraint 4 already met) | Without this, a critical page will not wake the screen and may not reach you at all. |

## Group 2: topics

| Key | Current | Class | Proposed |
|---|---|---|---|
| `home.stage_sub_no_topics` | Create a topic to get started. | `wrong-screen` (receives the idea moved off the connect screen) | Create one, then point a script, cron job or monitor at its endpoint. |
| `topic_detail.critical_toggle_title` | Ring through silent mode | `unsafe-claim` | Ring me for this topic |
| `topic_detail.critical_toggle_subtitle` | Critical delivery | `missing-fact` | Off by default. Turn it on and a critical page repeats every 30 s until you acknowledge it. |
| `create_topic.critical_toggle_title` | Ring through silent mode | `unsafe-claim` | Ring me for this topic |
| `create_topic.critical_toggle_subtitle` | Repeats every 30 s until acknowledged | `missing-fact` | Off by default. Turn it on and a critical page repeats every 30 s until you acknowledge it. |
| `create_topic.name_helper` | Lowercase, digits, hyphens. This becomes the URL. | `ok` | Lowercase, digits, hyphens. This becomes the URL. |
| `create_topic.name_error_invalid` | Invalid name. Use 1-64 lowercase, digits, and hyphens. | `filler` | Use 1 to 64 lowercase letters, digits and hyphens. Try prod-db. |
| `create_topic.name_error_empty` | Topic name cannot be empty | `filler` | Give the topic a name. |
| `create_topic.token_warning` | Save this token now. It will not be shown again. | `ok` | Save this token now. It will not be shown again. |

## Group 3: incidents

| Key | Current | Class | Proposed |
|---|---|---|---|
| `critical_alarm.acknowledged_message` | Acknowledged at {time} by Z | `leak` (hardcoded developer name) | Acknowledged at {time} |
| `critical_alarm.stage_sub_ringing` | Ringing 2 min 14 s. Repeats every 30 s. | `ok` | Ringing 2 min 14 s. Repeats every 30 s. |
| `lock_screen.ringing_pill` | Ringing through silent mode. Tap to acknowledge. | `unsafe-claim` | Ringing. Tap to acknowledge. |
| `lock_screen.back_aria_label` | Back to Home | `case` | Back |

## Group 4: settings, permissions, paywall

| Key | Current | Class | Proposed |
|---|---|---|---|
| `settings.critical_rings_title` | Critical rings through quiet hours | `ok` (quiet hours are the app's own setting, not the OS switch) | Critical rings through quiet hours |
| `settings.critical_rings_subtitle` | and through the silent switch | `unsafe-claim` | and repeats until you acknowledge |
| `settings.disconnect_dialog_content` | Are you sure you want to disconnect? You will stop receiving critical alarms until you reconnect. | `filler` | You will stop receiving pages until you connect again. |
| `settings.server_disconnected_description` | No server connected. Connect to a server to receive critical alerts. | `filler` | Connect a server to start receiving pages. |
| `settings.analytics_subtitle` | Shares anonymous feature usage and screen views to improve app stability. | `explains-the-build` | Which screens you open. No topic names, no message content. |
| `settings.crash_reports_subtitle` | Sends anonymized stack traces and device info when an unexpected error occurs. | `jargon` | What the app was doing when it crashed, plus your device model. |
| `settings.about_license_value` | GPL-3.0 License | `filler` (label already says License) | GPL-3.0 |
| `settings.redo_onboarding_subtitle` | Review permissions and server setup | `ok` | Review permissions and server setup |
| `device_permissions.title` | Device Permissions | `case` | Device permissions |
| `device_permissions.stage_sub_required` | Permissions required for alarm delivery through DND. | `unsafe-claim`, `jargon` | Some pages will not reach you until these are on. |
| `device_permissions.stage_sub_all_granted` | All permissions active. Ready to wake you at 3am. | `ok` | All set. Ready to wake you at 3am. |
| `device_permissions.capabilities_header` | Critical Alarm Capabilities | `case`, `jargon` | What Crit Alarm needs |
| `device_permissions.item_notifications_description` | Allows Crit Alarm to deliver alert banners and play sound. | `explains-the-build` | Off means no page reaches you. |
| `device_permissions.item_full_screen_intent_description` | Allows critical alerts to turn on and display over the lock screen even when phone is sleeping. | `explains-the-build` | Off means a critical page will not wake the screen. |
| `device_permissions.item_battery_optimization_description` | Prevents Android from killing background alarm sync and delayed delivery. | `jargon`, `explains-the-build` | Off means pages can arrive late. |
| `device_permissions.item_battery_optimization_title` | Battery optimization exemption | `jargon` | Run in the background |
| `device_permissions.note` | Crit Alarm relies on direct system level access so critical alerts break through silent switches, lock screens, and battery restrictions. | `unsafe-claim`, `explains-the-build` | (delete, set to empty string) |
| `device_permissions.badge_not_set` | Not Set | `case` | Not set |
| `paywall.present_paywall_button` | Present RevenueCat Paywall | `leak` (vendor name, debug control) | See all plans |
| `paywall.stage_sub_pro_active` | Your device is fully protected. Unlimited critical alarms unlocked. | `marketing` | Unlimited critical topics. |
| `paywall.stage_sub_pro` | Never miss a 3am page. Full repeat loop and escalation. | `marketing` | Unlimited critical topics, and a call when nobody answers. |
| `paywall.feature_bypass_silent` | Bypasses silent mode and Do Not Disturb | `unsafe-claim` | Rings until you acknowledge |
| `paywall.feature_escalate_call` | Escalates to phone call after 5 minutes | `filler` | Calls you after 5 min |
| `paywall.self_hosted_note` | Running on your own infrastructure? Self-hosted server includes all critical alerts 100% free. | `marketing` | Self-hosting? Every critical alert is free. |
| `paywall.active_title` | Crit Alarm Pro is Active | `case` | Crit Alarm Pro is active |
| `paywall.active_subtitle` | Thank you for supporting Crit Alarm! | `marketing` | Thanks for paying for this. |
| `paywall.manage_subscription_button` | Manage Subscription | `case` | Manage subscription |
| `paywall.select_plan_header` | Select Plan | `case` | Pick a plan |
| `paywall.badge_best_value` | Best Value | `case` | Best value |
| `paywall.restore_purchases_button` | Restore Purchases | `case` | Restore purchases |
| `paywall.error_subscription_failed` | Subscription operation failed. Please try again. | `jargon`, `filler` | That did not go through. Try again. |
| `paywall.feedback_no_active_restored` | No active Pro subscriptions found to restore | `filler` | Nothing to restore on this account. |
| `paywall.feedback_restored` | Crit Alarm Pro restored successfully | `filler` | Crit Alarm Pro restored. |
| `paywall.feedback_purchases_restored` | Purchases restored successfully | `filler` | Purchases restored. |

---

## What was left in Dart on purpose

Two kinds of string stayed out of `en.json`, because neither is app copy.

**Server and incident content.** Incident titles, bodies and meta lines, and the mock message
payloads in `topic_detail_cubit.dart` and `lock_screen_state.dart`. Text like
`Primary database down` and `pg_isready failed 3 times in 90 s.` stands in for what the user's
own server will send over the API. The app never writes it, so it is fixture data, not copy.

**Machine strings.** Storage keys, route paths, method channel names, RevenueCat product ids,
URLs, hostnames and semver values.

## Found, but not fixed here (needs code, not copy)

`home.stage_word_warning` is `1 warning` and `home.stage_sub_warning` is
`{count} topics. 1 warning.`. The warning count is hardcoded to 1 while the topic count next to
it is a real placeholder. `home_cubit.dart` already has `warningTopics`, so the number is
available. Fixing it properly needs `easy_localization`'s `.plural()` so that 1 reads `1 warning`
and 2 reads `2 warnings`, plus a second named argument at the call site. That is a code change,
so this pass left both strings alone.

## Known duplicates worth merging later

Not changed in this pass, because merging them changes code rather than copy.

- `home.meta_*` and `topics_list.meta_*` hold the same eight values twice.
- `onboarding_welcome.server_url_error_*` duplicates `onboarding_connect.server_url_error_*`.
  `onboarding_welcome_screen.dart` is only a typedef onto the permissions screen, so the
  `onboarding_welcome` group is dead and can be deleted once the typedef goes.
- `topic_detail.critical_toggle_*` and `create_topic.critical_toggle_*` now carry identical text.
  A shared `critical_toggle` group would be better.
