const http = require('node:http');
const crypto = require('node:crypto');
const url = require('node:url');

const PORT = parseInt(process.env.PORT || '4100', 10);

// In-memory state
const state = {
  accounts: new Map(), // accountId -> { id, tier, caps }
  devices: new Map(), // deviceId -> { deviceId, accountId, deviceToken, pushToken, appVersion }
  tokens: new Map(), // tokenString -> { type: 'device'|'topic'|'admin', accountId, topicName }
  topics: new Map(), // topicName -> { name, critical, repeat_interval_s, max_ring_s, desk_timer_s, relay_content, created_at, accountId, tokens: Set }
  incidents: new Map(), // incidentId -> { id, topic, state, opened_at, acked_at, closed_at, last_message_at, messages: [], desk_timer_fires_at, accountId }
  messages: new Map(), // topicName -> [ message ]
  subscriptions: new Map(), // `${deviceId}:${topicHash}` -> { deviceId, topicHash, accountId }
};

// Seed initial state
const SEED_ACCOUNT_ID = 'acc_default';
const SEED_DEVICE_ID = 'dev_default';
const SEED_DEVICE_TOKEN = 'dv_default_token';
const SEED_TOPIC_TOKEN = 'tk_prod_token';
const SEED_ADMIN_TOKEN = 'ad_default_admin_token';

state.accounts.set(SEED_ACCOUNT_ID, {
  id: SEED_ACCOUNT_ID,
  tier: 'free',
  caps: { devices: 1, critical_topics: 1, p4_daily: 50 },
});

state.devices.set(SEED_DEVICE_ID, {
  deviceId: SEED_DEVICE_ID,
  accountId: SEED_ACCOUNT_ID,
  deviceToken: SEED_DEVICE_TOKEN,
  pushToken: 'push_default',
  appVersion: '1.0.0',
});

state.tokens.set(SEED_DEVICE_TOKEN, {
  type: 'device',
  accountId: SEED_ACCOUNT_ID,
});

state.tokens.set(SEED_ADMIN_TOKEN, {
  type: 'admin',
  accountId: null, // access all
});

const nowSeconds = () => Math.floor(Date.now() / 1000);

const seedTopic = {
  name: 'prod',
  critical: false,
  repeat_interval_s: 30,
  max_ring_s: 1800,
  desk_timer_s: 600,
  relay_content: 'none',
  created_at: nowSeconds(),
  accountId: SEED_ACCOUNT_ID,
  tokens: new Set([SEED_TOPIC_TOKEN]),
};

state.topics.set('prod', seedTopic);
state.tokens.set(SEED_TOPIC_TOKEN, {
  type: 'topic',
  accountId: SEED_ACCOUNT_ID,
  topicName: 'prod',
});
state.messages.set('prod', []);

function parseBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
    });
    req.on('end', () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch (_) {
        resolve(data);
      }
    });
  });
}

function sendJson(res, status, obj) {
  const payload = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function sendError(res, httpStatus, code, error) {
  sendJson(res, httpStatus, {
    code: code || httpStatus * 100 + 1,
    http: httpStatus,
    error,
  });
}

function getBearerToken(req) {
  const auth = req.headers['authorization'];
  if (!auth) return null;
  const match = auth.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}

function authenticate(req) {
  const token = getBearerToken(req);
  if (!token) return null;
  // If token is unknown but starts with dv_, lazily create an account for mock flexibility
  if (!state.tokens.has(token)) {
    if (token.startsWith('dv_')) {
      const accountId = `acc_${token.slice(3, 11)}`;
      state.tokens.set(token, { type: 'device', accountId });
      state.accounts.set(accountId, {
        id: accountId,
        tier: 'free',
        caps: { devices: 1, critical_topics: 1, p4_daily: 50 },
      });
      return { token, type: 'device', accountId };
    }
    return null;
  }
  return { token, ...state.tokens.get(token) };
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Title, X-Priority, X-Tags, X-Click, X-Markdown');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Route: GET /v1/info
  if (method === 'GET' && pathname === '/v1/info') {
    sendJson(res, 200, {
      name: 'critalarm',
      version: '0.1.0',
      base_url: `http://localhost:${PORT}`,
      relay_url: `http://localhost:${PORT}/relay`,
      relay_content: 'none',
      mode: 'relay',
    });
    return;
  }

  // Route: POST /relay/v1/devices (registration, no auth)
  if (method === 'POST' && pathname === '/relay/v1/devices') {
    const body = await parseBody(req);
    const deviceId = body.device_id;
    if (!deviceId) {
      sendError(res, 400, 40001, 'device_id is required');
      return;
    }

    // Re-registration of known device without dv_ token is 401
    const auth = authenticate(req);
    if (state.devices.has(deviceId) && (!auth || auth.type !== 'device')) {
      sendError(res, 401, 40101, 're-registration requires device token');
      return;
    }

    const deviceToken = `dv_${crypto.randomBytes(16).toString('hex')}`;
    const accountId = `acc_${crypto.randomBytes(8).toString('hex')}`;
    const caps = { devices: 1, critical_topics: 1, p4_daily: 50 };

    state.accounts.set(accountId, { id: accountId, tier: 'free', caps });
    state.devices.set(deviceId, {
      deviceId,
      accountId,
      deviceToken,
      pushToken: body.push_token,
      appVersion: body.app_version,
    });
    state.tokens.set(deviceToken, { type: 'device', accountId });

    sendJson(res, 201, {
      device_token: deviceToken,
      account_id: accountId,
      tier: 'free',
      caps,
    });
    return;
  }

  // Route: PATCH /relay/v1/devices/{device_id}
  const patchDeviceMatch = pathname.match(/^\/relay\/v1\/devices\/([^/]+)$/);
  if (method === 'PATCH' && patchDeviceMatch) {
    const auth = authenticate(req);
    if (!auth || (auth.type !== 'device' && auth.type !== 'admin')) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }
    const deviceId = patchDeviceMatch[1];
    const body = await parseBody(req);
    const existing = state.devices.get(deviceId);
    if (existing) {
      if (body.push_token) existing.pushToken = body.push_token;
      if (body.app_version) existing.appVersion = body.app_version;
    }
    sendJson(res, 200, {
      account_id: auth.accountId || SEED_ACCOUNT_ID,
      tier: 'free',
      caps: { devices: 1, critical_topics: 1, p4_daily: 50 },
    });
    return;
  }

  // Route: POST /relay/v1/devices/{device_id}/subscriptions
  const subMatch = pathname.match(/^\/relay\/v1\/devices\/([^/]+)\/subscriptions$/);
  if (method === 'POST' && subMatch) {
    const auth = authenticate(req);
    if (!auth || (auth.type !== 'device' && auth.type !== 'admin')) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }
    const deviceId = subMatch[1];
    const body = await parseBody(req);
    const topicHash = body.topic_hash;
    state.subscriptions.set(`${deviceId}:${topicHash}`, {
      deviceId,
      topicHash,
      accountId: auth.accountId,
    });
    res.writeHead(204);
    res.end();
    return;
  }

  // Route: DELETE /relay/v1/devices/{device_id}/subscriptions/{topic_hash}
  const unsubMatch = pathname.match(/^\/relay\/v1\/devices\/([^/]+)\/subscriptions\/([^/]+)$/);
  if (method === 'DELETE' && unsubMatch) {
    const auth = authenticate(req);
    if (!auth || (auth.type !== 'device' && auth.type !== 'admin')) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }
    const deviceId = unsubMatch[1];
    const topicHash = unsubMatch[2];
    state.subscriptions.delete(`${deviceId}:${topicHash}`);
    res.writeHead(204);
    res.end();
    return;
  }

  // Route: /v1/topics...
  if (pathname.startsWith('/v1/topics')) {
    const auth = authenticate(req);
    if (!auth || (auth.type !== 'device' && auth.type !== 'admin')) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }

    // GET /v1/topics
    if (method === 'GET' && pathname === '/v1/topics') {
      const callerTopics = [];
      for (const topic of state.topics.values()) {
        if (auth.type === 'admin' || topic.accountId === auth.accountId) {
          callerTopics.push({
            name: topic.name,
            critical: topic.critical,
            repeat_interval_s: topic.repeat_interval_s,
            max_ring_s: topic.max_ring_s,
            desk_timer_s: topic.desk_timer_s,
            relay_content: topic.relay_content,
            created_at: topic.created_at,
          });
        }
      }
      sendJson(res, 200, callerTopics);
      return;
    }

    // POST /v1/topics
    if (method === 'POST' && pathname === '/v1/topics') {
      const body = await parseBody(req);
      const name = body.name;
      if (!name || typeof name !== 'string') {
        sendError(res, 400, 40001, 'invalid topic name');
        return;
      }
      const token = `tk_${crypto.randomBytes(16).toString('hex')}`;
      const newTopic = {
        name,
        critical: false, // Must default to false!
        repeat_interval_s: 30,
        max_ring_s: 1800,
        desk_timer_s: 600,
        relay_content: 'none',
        created_at: nowSeconds(),
        accountId: auth.accountId,
        tokens: new Set([token]),
      };
      state.topics.set(name, newTopic);
      state.tokens.set(token, {
        type: 'topic',
        accountId: auth.accountId,
        topicName: name,
      });
      if (!state.messages.has(name)) {
        state.messages.set(name, []);
      }

      sendJson(res, 201, {
        name: newTopic.name,
        critical: newTopic.critical,
        repeat_interval_s: newTopic.repeat_interval_s,
        max_ring_s: newTopic.max_ring_s,
        desk_timer_s: newTopic.desk_timer_s,
        relay_content: newTopic.relay_content,
        created_at: newTopic.created_at,
        token,
      });
      return;
    }

    // POST /v1/topics/{name}/tokens
    const tokensMatch = pathname.match(/^\/v1\/topics\/([^/]+)\/tokens$/);
    if (method === 'POST' && tokensMatch) {
      const topicName = tokensMatch[1];
      const topic = state.topics.get(topicName);
      if (!topic || (auth.type !== 'admin' && topic.accountId !== auth.accountId)) {
        sendError(res, 404, 40401, 'topic not found');
        return;
      }
      const token = `tk_${crypto.randomBytes(16).toString('hex')}`;
      topic.tokens.add(token);
      state.tokens.set(token, {
        type: 'topic',
        accountId: auth.accountId,
        topicName,
      });
      sendJson(res, 201, { token });
      return;
    }

    // PATCH /v1/topics/{name}
    const topicMatch = pathname.match(/^\/v1\/topics\/([^/]+)$/);
    if (method === 'PATCH' && topicMatch) {
      const topicName = topicMatch[1];
      const topic = state.topics.get(topicName);
      if (!topic || (auth.type !== 'admin' && topic.accountId !== auth.accountId)) {
        sendError(res, 404, 40401, 'topic not found');
        return;
      }
      const body = await parseBody(req);
      if (typeof body.critical === 'boolean') topic.critical = body.critical;
      if (typeof body.repeat_interval_s === 'number') topic.repeat_interval_s = body.repeat_interval_s;
      if (typeof body.max_ring_s === 'number') topic.max_ring_s = body.max_ring_s;
      if (typeof body.desk_timer_s === 'number') topic.desk_timer_s = body.desk_timer_s;

      sendJson(res, 200, {
        name: topic.name,
        critical: topic.critical,
        repeat_interval_s: topic.repeat_interval_s,
        max_ring_s: topic.max_ring_s,
        desk_timer_s: topic.desk_timer_s,
        relay_content: topic.relay_content,
        created_at: topic.created_at,
      });
      return;
    }

    // DELETE /v1/topics/{name}
    if (method === 'DELETE' && topicMatch) {
      const topicName = topicMatch[1];
      const topic = state.topics.get(topicName);
      if (!topic || (auth.type !== 'admin' && topic.accountId !== auth.accountId)) {
        sendError(res, 404, 40401, 'topic not found');
        return;
      }
      for (const tok of topic.tokens) {
        state.tokens.delete(tok);
      }
      state.topics.delete(topicName);
      res.writeHead(204);
      res.end();
      return;
    }
  }

  // Route: /v1/incidents...
  if (pathname.startsWith('/v1/incidents')) {
    const auth = authenticate(req);
    if (!auth || (auth.type !== 'device' && auth.type !== 'admin')) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }

    // GET /v1/incidents
    if (method === 'GET' && pathname === '/v1/incidents') {
      const limit = parseInt(parsedUrl.query.limit || '20', 10);
      const stateFilter = parsedUrl.query.state;
      const topicFilter = parsedUrl.query.topic;

      const results = [];
      for (const inc of state.incidents.values()) {
        if (auth.type !== 'admin' && inc.accountId !== auth.accountId) continue;
        if (stateFilter && inc.state !== stateFilter) continue;
        if (topicFilter && inc.topic !== topicFilter) continue;
        results.push({
          id: inc.id,
          topic: inc.topic,
          state: inc.state,
          opened_at: inc.opened_at,
          acked_at: inc.acked_at,
          closed_at: inc.closed_at,
          last_message_at: inc.last_message_at,
          messages: inc.messages,
          desk_timer_fires_at: inc.desk_timer_fires_at,
        });
        if (results.length >= limit) break;
      }
      sendJson(res, 200, results);
      return;
    }

    // POST /v1/incidents/{id}/ack
    const ackMatch = pathname.match(/^\/v1\/incidents\/([^/]+)\/ack$/);
    if (method === 'POST' && ackMatch) {
      const id = ackMatch[1];
      const inc = state.incidents.get(id);
      if (!inc || (auth.type !== 'admin' && inc.accountId !== auth.accountId)) {
        sendError(res, 404, 40401, 'incident not found');
        return;
      }
      if (inc.state !== 'open') {
        sendError(res, 409, 40901, 'incident is not open');
        return;
      }
      const topic = state.topics.get(inc.topic);
      const deskTimerS = topic ? topic.desk_timer_s : 600;
      inc.state = 'acked';
      inc.acked_at = nowSeconds();
      inc.desk_timer_fires_at = inc.acked_at + deskTimerS;

      sendJson(res, 200, {
        id: inc.id,
        topic: inc.topic,
        state: inc.state,
        opened_at: inc.opened_at,
        acked_at: inc.acked_at,
        closed_at: inc.closed_at,
        last_message_at: inc.last_message_at,
        messages: inc.messages,
        desk_timer_fires_at: inc.desk_timer_fires_at,
      });
      return;
    }

    // POST /v1/incidents/{id}/close
    const closeMatch = pathname.match(/^\/v1\/incidents\/([^/]+)\/close$/);
    if (method === 'POST' && closeMatch) {
      const id = closeMatch[1];
      const inc = state.incidents.get(id);
      if (!inc || (auth.type !== 'admin' && inc.accountId !== auth.accountId)) {
        sendError(res, 404, 40401, 'incident not found');
        return;
      }
      if (inc.state !== 'acked') {
        sendError(res, 409, 40901, 'incident is not acked');
        return;
      }
      inc.state = 'closed';
      inc.closed_at = nowSeconds();

      sendJson(res, 200, {
        id: inc.id,
        topic: inc.topic,
        state: inc.state,
        opened_at: inc.opened_at,
        acked_at: inc.acked_at,
        closed_at: inc.closed_at,
        last_message_at: inc.last_message_at,
        messages: inc.messages,
        desk_timer_fires_at: inc.desk_timer_fires_at,
      });
      return;
    }

    // GET /v1/incidents/{id}
    const getIncMatch = pathname.match(/^\/v1\/incidents\/([^/]+)$/);
    if (method === 'GET' && getIncMatch) {
      const id = getIncMatch[1];
      const inc = state.incidents.get(id);
      if (!inc || (auth.type !== 'admin' && inc.accountId !== auth.accountId)) {
        sendError(res, 404, 40401, 'incident not found');
        return;
      }
      sendJson(res, 200, {
        id: inc.id,
        topic: inc.topic,
        state: inc.state,
        opened_at: inc.opened_at,
        acked_at: inc.acked_at,
        closed_at: inc.closed_at,
        last_message_at: inc.last_message_at,
        messages: inc.messages,
        desk_timer_fires_at: inc.desk_timer_fires_at,
      });
      return;
    }
  }

  // Route: POST /v1/test?topic={topic}
  if (method === 'POST' && pathname === '/v1/test') {
    const auth = authenticate(req);
    if (!auth || (auth.type !== 'device' && auth.type !== 'admin')) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }
    const topicName = parsedUrl.query.topic;
    if (!topicName || !state.topics.has(topicName)) {
      sendError(res, 404, 40401, 'topic not found');
      return;
    }
    const topic = state.topics.get(topicName);
    if (auth.type !== 'admin' && topic.accountId !== auth.accountId) {
      sendError(res, 404, 40401, 'topic not found');
      return;
    }
    if (!topic.critical) {
      sendError(res, 409, 40902, 'topic is not critical');
      return;
    }

    // Publishes priority-5 message and opens incident
    const now = nowSeconds();
    const msgId = `m_${crypto.randomBytes(4).toString('hex')}`;
    let incident = null;
    // Check if an open incident exists for this topic
    for (const inc of state.incidents.values()) {
      if (inc.topic === topicName && inc.state === 'open') {
        incident = inc;
        break;
      }
    }
    if (!incident) {
      const incId = `inc_${crypto.randomBytes(4).toString('hex')}`;
      incident = {
        id: incId,
        topic: topicName,
        state: 'open',
        opened_at: now,
        acked_at: null,
        closed_at: null,
        last_message_at: now,
        messages: [],
        desk_timer_fires_at: null,
        accountId: topic.accountId,
      };
      state.incidents.set(incId, incident);
    }

    const messageObj = {
      id: msgId,
      time: now,
      expires: now + 86400,
      event: 'message',
      topic: topicName,
      title: 'Crit Alarm test',
      message: 'Test alarm triggered',
      priority: 5,
      tags: ['test'],
      incident_id: incident.id,
    };
    incident.last_message_at = now;
    incident.messages.push(messageObj);

    if (!state.messages.has(topicName)) state.messages.set(topicName, []);
    state.messages.get(topicName).push(messageObj);

    sendJson(res, 200, { incident_id: incident.id });
    return;
  }

  // Route: GET /{topic}/json?poll=1[&since=...]
  const pollMatch = pathname.match(/^\/([^/]+)\/json$/);
  if (method === 'GET' && pollMatch) {
    const topicName = pollMatch[1];
    if (parsedUrl.query.poll !== '1') {
      sendError(res, 501, 50101, 'streaming not supported in v1');
      return;
    }

    // Check auth
    const token = getBearerToken(req);
    const tokenMeta = token ? state.tokens.get(token) : null;
    // Allow topic token or admin token
    if (!tokenMeta || (tokenMeta.type !== 'topic' && tokenMeta.type !== 'admin')) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }
    if (tokenMeta.type === 'topic' && tokenMeta.topicName !== topicName) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }

    const msgs = state.messages.get(topicName) || [];
    // Convert to NDJSON
    const ndjson = msgs.map((m) => JSON.stringify(m)).join('\n') + (msgs.length > 0 ? '\n' : '');
    res.writeHead(200, {
      'Content-Type': 'application/x-ndjson; charset=utf-8',
      'Content-Length': Buffer.byteLength(ndjson),
    });
    res.end(ndjson);
    return;
  }

  // Route: POST /{topic} (publish message)
  const publishMatch = pathname.match(/^\/([^/]+)$/);
  if (method === 'POST' && publishMatch) {
    const topicName = publishMatch[1];
    const token = getBearerToken(req);
    const tokenMeta = token ? state.tokens.get(token) : null;
    if (!tokenMeta || (tokenMeta.type !== 'topic' && tokenMeta.type !== 'admin')) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }
    if (tokenMeta.type === 'topic' && tokenMeta.topicName !== topicName) {
      sendError(res, 401, 40101, 'unauthorized');
      return;
    }

    const topic = state.topics.get(topicName);
    if (!topic) {
      sendError(res, 404, 40401, 'topic not found');
      return;
    }

    const body = await parseBody(req);
    const priority = body.priority !== undefined ? parseInt(body.priority, 10) : 3;
    const now = nowSeconds();
    const msgId = `m_${crypto.randomBytes(4).toString('hex')}`;

    let incidentId = null;
    if (priority === 5 && topic.critical) {
      // Priority-5 on critical topic opens or joins incident
      let incident = null;
      for (const inc of state.incidents.values()) {
        if (inc.topic === topicName && inc.state === 'open') {
          incident = inc;
          break;
        }
      }
      if (!incident) {
        const incId = `inc_${crypto.randomBytes(4).toString('hex')}`;
        incident = {
          id: incId,
          topic: topicName,
          state: 'open',
          opened_at: now,
          acked_at: null,
          closed_at: null,
          last_message_at: now,
          messages: [],
          desk_timer_fires_at: null,
          accountId: topic.accountId,
        };
        state.incidents.set(incId, incident);
      }
      incidentId = incident.id;
    }

    const messageObj = {
      id: msgId,
      time: now,
      expires: now + 86400,
      event: 'message',
      topic: topicName,
      title: body.title || null,
      message: body.message || 'triggered',
      priority,
      tags: body.tags || [],
    };
    if (incidentId) {
      messageObj.incident_id = incidentId;
      const inc = state.incidents.get(incidentId);
      if (inc) {
        inc.last_message_at = now;
        inc.messages.push(messageObj);
      }
    }

    if (!state.messages.has(topicName)) state.messages.set(topicName, []);
    state.messages.get(topicName).push(messageObj);

    sendJson(res, 200, messageObj);
    return;
  }

  // Fallback 404
  sendError(res, 404, 40401, 'not found');
});

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`Crit Alarm mock server listening on http://localhost:${PORT}`);
  });
}

module.exports = { server, state };
