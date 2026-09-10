# Crit Alarm Mock Server

In-repo plain Node mock server implementing the Crit Alarm and relay contracts for client development and testing.

## How to Start

Ensure Node 22+ is installed, then run:

```bash
node mock-server/server.js
```

Or from the `mock-server/` directory:

```bash
npm start
```

By default, the server listens on `http://localhost:4100`. You can override the port by setting the `PORT` environment variable:

```bash
PORT=4101 node mock-server/server.js
```

## What is Seeded

On startup, the server seeds an in-memory state with:
- **Account:** `acc_default` (tier: `free`, caps: `devices: 1`, `critical_topics: 1`, `p4_daily: 50`)
- **Device:** `dev_default` with device token `dv_default_token`
- **Topic:** `prod` owned by `acc_default`:
  - `critical: false` (defaults to false per product commitment)
  - `repeat_interval_s: 30`
  - `max_ring_s: 1800`
  - `desk_timer_s: 600`
  - `relay_content: "none"`
  - Topic token: `tk_prod_token`
- **Admin Token:** `ad_default_admin_token` (unrestricted access)

## What is Faked

- **In-memory Storage:** All state (accounts, devices, topics, tokens, incidents, messages, subscriptions) is held in memory and resets when the process stops.
- **Dynamic Account Scoping:** Any unknown token starting with `dv_` automatically provisions a distinct virtual account (`acc_<slice>`). Requests across accounts isolate topic access and return `404` (never `403`), matching contract privacy specifications.
- **Priority-5 Publish:** Publishing a message with `priority: 5` to a topic with `critical: true` opens or joins an open incident, groups the message under the incident, and returns `incident_id` in the publish response.
- **Relay and APNs/FCM:** Push notification delivery to Apple APNs or Google FCM is simulated in-memory; device tokens and registrations follow the contract without hitting live push gateways.
