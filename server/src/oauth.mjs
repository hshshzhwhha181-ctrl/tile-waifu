// Real OAuth2 (Yandex ID, Google, VK ID — all with PKCE S256) + Telegram Login Widget + poll store.
import { randomBytes, createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { ApiError, sendHtml, sendJson, escapeHtml, now } from './util.mjs';

const b64u = (buf) => Buffer.from(buf).toString('base64url');
const STATE_TTL_MS = 10 * 60 * 1000;

export function providerConfig(env = process.env) {
  return {
    yandex: { id: env.YANDEX_CLIENT_ID || '', secret: env.YANDEX_CLIENT_SECRET || '' },
    google: { id: env.GOOGLE_CLIENT_ID || '', secret: env.GOOGLE_CLIENT_SECRET || '' },
    vk: { id: env.VK_CLIENT_ID || '', secret: env.VK_CLIENT_SECRET || '' },
    telegram: { token: env.TELEGRAM_BOT_TOKEN || '', bot: (env.TELEGRAM_BOT_NAME || '').replace(/^@/, '') },
  };
}

export function oauthFlags(cfg) {
  return {
    yandex: !!(cfg.yandex.id && cfg.yandex.secret),
    google: !!(cfg.google.id && cfg.google.secret),
    vk: !!cfg.vk.id, // VK ID + PKCE: the secret is optional
    telegram: !!cfg.telegram.token,
  };
}

/** Telegram Login Widget check. Returns the cleaned fields or throws ApiError. */
export function verifyTelegram(fields, botToken) {
  if (!botToken) throw new ApiError(503, 'provider_not_configured', 'Вход через Telegram не настроен на сервере');
  if (!fields || typeof fields !== 'object') throw new ApiError(400, 'bad_request', 'Нет данных Telegram');
  const hash = String(fields.hash || '');
  const data = Object.keys(fields)
    .filter((k) => k !== 'hash' && fields[k] !== undefined && fields[k] !== null && typeof fields[k] !== 'object')
    .sort()
    .map((k) => `${k}=${fields[k]}`)
    .join('\n');
  const secret = createHash('sha256').update(botToken).digest();
  const calc = createHmac('sha256', secret).update(data).digest('hex');
  const a = Buffer.from(calc, 'utf8'), b = Buffer.from(hash.toLowerCase(), 'utf8');
  if (!hash || a.length !== b.length || !timingSafeEqual(a, b)) throw new ApiError(401, 'bad_signature', 'Подпись Telegram неверна');
  const authDate = Number(fields.auth_date);
  if (!Number.isFinite(authDate) || now() - authDate > 86400) throw new ApiError(401, 'expired', 'Данные Telegram устарели — войдите заново');
  if (!fields.id) throw new ApiError(400, 'bad_request', 'Нет id пользователя Telegram');
  return fields;
}

export function telegramProfile(f) {
  const name = [f.first_name, f.last_name].filter(Boolean).join(' ') || f.username || 'Telegram';
  return { uid: String(f.id), profile: { name, username: f.username || '', photo: f.photo_url || '' } };
}

const AUTH_URL = {
  yandex: 'https://oauth.yandex.ru/authorize',
  google: 'https://accounts.google.com/o/oauth2/v2/auth',
  vk: 'https://id.vk.com/authorize',
};

async function postForm(url, params, headers = {}) {
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json', ...headers },
    body: new URLSearchParams(params).toString(),
    signal: AbortSignal.timeout(10000),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || j.error) throw new Error(`${url}: ${r.status} ${j.error || ''} ${j.error_description || ''}`.trim());
  return j;
}

async function getJson(url, headers) {
  const r = await fetch(url, { headers: { Accept: 'application/json', ...headers }, signal: AbortSignal.timeout(10000) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`${url}: ${r.status}`);
  return j;
}

/** code → { uid, profile } for each provider. */
async function exchange(p, cfg, { code, verifier, redirectUri, query, srvState }) {
  if (p === 'yandex') {
    const tok = await postForm('https://oauth.yandex.ru/token', {
      grant_type: 'authorization_code', code, client_id: cfg.yandex.id, client_secret: cfg.yandex.secret, code_verifier: verifier,
    });
    const info = await getJson('https://login.yandex.ru/info?format=json', { Authorization: `OAuth ${tok.access_token}` });
    return {
      uid: String(info.id),
      profile: { name: info.display_name || info.real_name || info.login, login: info.login, email: info.default_email || '',
        photo: info.default_avatar_id ? `https://avatars.yandex.net/get-yapic/${info.default_avatar_id}/islands-200` : '' },
    };
  }
  if (p === 'google') {
    const tok = await postForm('https://oauth2.googleapis.com/token', {
      grant_type: 'authorization_code', code, client_id: cfg.google.id, client_secret: cfg.google.secret,
      redirect_uri: redirectUri, code_verifier: verifier,
    });
    const info = await getJson('https://openidconnect.googleapis.com/v1/userinfo', { Authorization: `Bearer ${tok.access_token}` });
    return { uid: String(info.sub), profile: { name: info.name || info.given_name || 'Google', email: info.email_verified ? info.email || '' : '', photo: info.picture || '' } };
  }
  if (p === 'vk') {
    const params = {
      grant_type: 'authorization_code', code, code_verifier: verifier, client_id: cfg.vk.id,
      device_id: String(query.get('device_id') || ''), redirect_uri: redirectUri, state: srvState,
    };
    const tok = await postForm('https://id.vk.com/oauth2/auth', params);
    const info = await postForm('https://id.vk.com/oauth2/user_info', { client_id: cfg.vk.id, access_token: tok.access_token });
    const u = info.user || {};
    return {
      uid: String(u.user_id || tok.user_id),
      profile: { name: [u.first_name, u.last_name].filter(Boolean).join(' ') || 'VK', email: u.email || '', photo: u.avatar || '' },
    };
  }
  throw new Error('unknown provider');
}

function page(title, text, ok = true) {
  return `<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)}</title><style>body{font-family:system-ui,sans-serif;background:#1b1426;color:#f6e9ff;display:flex;
align-items:center;justify-content:center;min-height:100vh;margin:0}.c{background:#2a1f3d;padding:32px 40px;border-radius:18px;
text-align:center;max-width:420px;box-shadow:0 8px 40px #0008}h1{color:${ok ? '#ffb3d9' : '#ff8080'};font-size:24px}</style></head>
<body><div class="c"><h1>${escapeHtml(title)}</h1><p>${escapeHtml(text)}</p></div></body></html>`;
}

export class OAuth {
  constructor({ users, publicUrl, env = process.env, log = () => {} }) {
    this.users = users; this.publicUrl = publicUrl.replace(/\/+$/, ''); this.env = env; this.log = log;
    this.flows = new Map(); // server state → {p, clientState, linkUserId, verifier, created}
    this.results = new Map(); // client state → {created, result|null}
    this.sweeper = setInterval(() => this._sweep(), 60000);
    this.sweeper.unref?.();
  }
  get cfg() { return providerConfig(this.env); }
  get flags() { return oauthFlags(this.cfg); }
  close() { clearInterval(this.sweeper); }

  _sweep() {
    const t = Date.now();
    for (const [k, v] of this.flows) if (t - v.created > STATE_TTL_MS) this.flows.delete(k);
    for (const [k, v] of this.results) if (t - v.created > STATE_TTL_MS) this.results.delete(k);
  }

  _complete(clientState, result) {
    if (clientState) this.results.set(clientState, { created: Date.now(), result });
  }

  /** GET /api/v1/auth/poll?state= */
  poll(state) {
    const s = String(state || '');
    const e = this.results.get(s);
    if (!e || !e.result) return { ok: true, pending: true };
    this.results.delete(s);
    return e.result;
  }

  _finishLogin(provider, uid, profile, linkUser) {
    const { user, switched } = this.users.linkOrLogin(provider, uid, profile, linkUser);
    const token = this.users.createSession(user.id);
    return { ok: true, token, user: this.users.pub(user), provider, linked: true, switched };
  }

  /** GET /auth/{p}/start */
  start(p, url, res) {
    const clientState = String(url.searchParams.get('state') || '');
    if (!/^[\w\-.~]{6,128}$/.test(clientState)) throw new ApiError(400, 'bad_state', 'Нужен параметр state (6–128 символов)');
    const linkTok = url.searchParams.get('link');
    const linkUser = linkTok ? this.users.byToken(linkTok) : null;
    if (p === 'telegram') return this._telegramPage(clientState, linkTok, res);
    if (!this.flags[p]) {
      this._complete(clientState, { ok: false, error: 'provider_not_configured', msg: 'Этот способ входа не настроен на сервере' });
      throw new ApiError(503, 'provider_not_configured', 'Этот способ входа не настроен на сервере');
    }
    const cfg = this.cfg[p];
    const srvState = b64u(randomBytes(24));
    const verifier = b64u(randomBytes(48));
    const challenge = b64u(createHash('sha256').update(verifier).digest());
    this.flows.set(srvState, { p, clientState, linkUserId: linkUser?.id ?? null, verifier, created: Date.now() });
    this.results.set(clientState, { created: Date.now(), result: null });
    const q = new URLSearchParams({
      response_type: 'code', client_id: cfg.id, redirect_uri: this.redirectUri(p), state: srvState,
      code_challenge: challenge, code_challenge_method: 'S256',
    });
    if (p === 'google') { q.set('scope', 'openid email profile'); q.set('prompt', 'select_account'); }
    if (p === 'vk') q.set('scope', 'email');
    if (p === 'yandex') q.set('force_confirm', 'no');
    res.writeHead(302, { Location: `${AUTH_URL[p]}?${q}`, 'Cache-Control': 'no-store' });
    res.end();
  }

  redirectUri(p) { return `${this.publicUrl}/auth/${p}/callback`; }

  /** GET /auth/{p}/callback */
  async callback(p, url, res) {
    const srvState = String(url.searchParams.get('state') || '');
    const flow = this.flows.get(srvState);
    if (!flow || flow.p !== p) return sendHtml(res, 400, page('Ошибка входа', 'Сессия входа устарела. Вернитесь в игру и попробуйте ещё раз.', false));
    this.flows.delete(srvState);
    const err = url.searchParams.get('error');
    const code = url.searchParams.get('code');
    if (err || !code) {
      this._complete(flow.clientState, { ok: false, error: 'oauth_denied', msg: 'Вход отменён' });
      return sendHtml(res, 400, page('Вход отменён', 'Вернитесь в игру и попробуйте ещё раз.', false));
    }
    try {
      const { uid, profile } = await exchange(p, this.cfg, { code, verifier: flow.verifier, redirectUri: this.redirectUri(p), query: url.searchParams, srvState });
      const linkUser = flow.linkUserId ? this.users.get(flow.linkUserId) : null;
      this._complete(flow.clientState, this._finishLogin(p, uid, profile, linkUser));
      this.log(`[oauth] ${p} ok uid=${uid}`);
      sendHtml(res, 200, page('Вход выполнен — вернитесь в игру', 'Это окно можно закрыть. Игра подхватит вход автоматически.'));
    } catch (e) {
      console.error(`[oauth] ${p} exchange failed:`, e.message);
      this._complete(flow.clientState, { ok: false, error: 'oauth_failed', msg: 'Не удалось завершить вход через провайдера' });
      sendHtml(res, 502, page('Ошибка входа', 'Провайдер не подтвердил вход. Вернитесь в игру и попробуйте ещё раз.', false));
    }
  }

  /** POST /auth/telegram/verify (JSON) */
  telegramVerify(body, linkUser) {
    const f = verifyTelegram(body, this.cfg.telegram.token);
    const { uid, profile } = telegramProfile(f);
    return this._finishLogin('telegram', uid, profile, linkUser);
  }

  /** Desktop flow helper: page with the Telegram widget (domain must be set via BotFather /setdomain). */
  _telegramPage(clientState, linkTok, res) {
    const { token, bot } = this.cfg.telegram;
    if (!token || !bot) {
      this._complete(clientState, { ok: false, error: 'provider_not_configured', msg: 'Вход через Telegram не настроен на сервере' });
      throw new ApiError(503, 'provider_not_configured', 'Вход через Telegram не настроен (TELEGRAM_BOT_TOKEN / TELEGRAM_BOT_NAME)');
    }
    this.results.set(clientState, { created: Date.now(), result: null });
    const cb = `${this.publicUrl}/auth/telegram/callback?state=${encodeURIComponent(clientState)}${linkTok ? `&link=${encodeURIComponent(linkTok)}` : ''}`;
    sendHtml(res, 200, `<!doctype html><html lang="ru"><head><meta charset="utf-8"><title>Вход через Telegram</title>
<style>body{font-family:system-ui,sans-serif;background:#1b1426;color:#f6e9ff;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}
.c{background:#2a1f3d;padding:32px 40px;border-radius:18px;text-align:center}</style></head><body><div class="c"><h1>Tile Waifu</h1>
<p>Войдите через Telegram:</p><script async src="https://telegram.org/js/telegram-widget.js?22" data-telegram-login="${escapeHtml(bot)}"
data-size="large" data-auth-url="${escapeHtml(cb)}" data-request-access="write"></script></div></body></html>`);
  }

  /** GET /auth/telegram/callback?state&link&<widget fields> (redirect mode of the widget) */
  telegramCallback(url, res) {
    const q = Object.fromEntries(url.searchParams);
    const clientState = q.state || '';
    const linkTok = q.link;
    delete q.state; delete q.link;
    try {
      const linkUser = linkTok ? this.users.byToken(linkTok) : null;
      this._complete(clientState, this.telegramVerify(q, linkUser));
      sendHtml(res, 200, page('Вход выполнен — вернитесь в игру', 'Это окно можно закрыть. Игра подхватит вход автоматически.'));
    } catch (e) {
      const ae = e instanceof ApiError ? e : new ApiError(500, 'internal', 'Ошибка');
      this._complete(clientState, { ok: false, error: ae.code, msg: ae.msg });
      sendHtml(res, ae.status, page('Ошибка входа', ae.msg, false));
    }
  }
}

export { sendJson };
