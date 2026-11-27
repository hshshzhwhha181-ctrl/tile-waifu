// REST API router (PROTOCOL.md).
import { ApiError, VERSION, now, int, readJson, sendJson, clientIp, RateLimiter } from './util.mjs';
import { tx } from './db.mjs';
import { PROVIDERS, hashPassword, verifyPassword, validateNick, validateAvatar, validateEmail } from './users.mjs';

export class Api {
  constructor({ db, users, oauth, pvp, sandbox }) {
    this.db = db; this.users = users; this.oauth = oauth; this.pvp = pvp; this.sandbox = sandbox;
    this.authLimiter = new RateLimiter(Number(process.env.RATE_LIMIT_AUTH || 60), 60000);
    this.apiLimiter = new RateLimiter(Number(process.env.RATE_LIMIT_API || 600), 60000);
    this.q = {
      saveGet: db.prepare('SELECT save_json, version, updated_at FROM player_saves WHERE user_id = ?'),
      saveUpsert: db.prepare(`INSERT INTO player_saves (user_id, save_json, version, updated_at) VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET save_json = excluded.save_json, version = excluded.version, updated_at = excluded.updated_at`),
      setRp: db.prepare('UPDATE users SET rp = ? WHERE id = ?'),
      raidGet: db.prepare('SELECT stage_idx, damage FROM leaderboard_raid WHERE user_id = ?'),
      raidUpsert: db.prepare(`INSERT INTO leaderboard_raid (user_id, stage_idx, damage, updated_at) VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET stage_idx = excluded.stage_idx, damage = excluded.damage, updated_at = excluded.updated_at`),
      raidRank: db.prepare('SELECT COUNT(*) AS n FROM leaderboard_raid WHERE stage_idx > ? OR (stage_idx = ? AND damage > ?)'),
      raidTop: db.prepare(`SELECT r.user_id, u.nick, u.avatar, r.damage AS value, u.wins, u.losses, r.stage_idx
        FROM leaderboard_raid r JOIN users u ON u.id = r.user_id ORDER BY r.stage_idx DESC, r.damage DESC, r.updated_at ASC LIMIT ?`),
      pvpTop: db.prepare(`SELECT u.id AS user_id, u.nick, u.avatar, u.pvp_elo AS value, u.wins, u.losses, COALESCE(r.stage_idx, 0) AS stage_idx
        FROM users u LEFT JOIN leaderboard_raid r ON r.user_id = u.id WHERE u.wins + u.losses > 0
        ORDER BY u.pvp_elo DESC, u.wins DESC, u.id ASC LIMIT ?`),
      pvpRank: db.prepare('SELECT COUNT(*) AS n FROM users WHERE wins + losses > 0 AND pvp_elo > ?'),
      updAvatar: db.prepare('UPDATE users SET avatar = ? WHERE id = ?'),
      upgrade: db.prepare('UPDATE users SET email = ?, password_hash = ? WHERE id = ?'),
    };
  }

  bearer(req) {
    const h = String(req.headers.authorization || '');
    const m = /^Bearer\s+(\S+)$/i.exec(h);
    return m ? m[1] : null;
  }
  authUser(req, required = true) {
    const u = this.users.byToken(this.bearer(req));
    if (!u && required) throw new ApiError(401, 'unauthorized', 'Требуется вход (токен недействителен или устарел)');
    return u;
  }
  session(user, extra = {}) {
    return { ok: true, token: this.users.createSession(user.id), user: this.users.pub(this.users.get(user.id)), ...extra };
  }

  /** Returns true if handled. */
  async handle(req, res, url) {
    const p = url.pathname, method = req.method;
    const ip = clientIp(req);
    if (!this.apiLimiter.hit(ip)) throw new ApiError(429, 'rate_limited', 'Слишком много запросов, подождите минуту');
    const isAuth = p.startsWith('/api/v1/auth/') && p !== '/api/v1/auth/poll' || p === '/auth/telegram/verify';
    if (isAuth && method === 'POST' && !this.authLimiter.hit(ip)) throw new ApiError(429, 'rate_limited', 'Слишком много попыток входа, подождите минуту');

    const route = `${method} ${p}`;
    switch (route) {
      case 'GET /api/v1/health':
        return sendJson(res, 200, { ok: true, version: VERSION, online_players: this.pvp.online, db: 'sqlite', oauth: this.oauth.flags, sandbox: this.sandbox });

      case 'POST /api/v1/auth/guest': {
        const b = await readJson(req);
        let avatar = 'mc';
        if (b.avatar !== undefined && b.avatar !== '') avatar = validateAvatar(b.avatar);
        let nick = null;
        if (b.nick) { try { nick = validateNick(b.nick); } catch { nick = null; } }
        const user = this.users.create({ nick: this.users.uniqueNick(nick || ''), avatar });
        return sendJson(res, 200, this.session(user));
      }

      case 'POST /api/v1/auth/register': {
        const b = await readJson(req);
        const nick = validateNick(b.nick);
        const email = validateEmail(b.email);
        const pw = String(b.password ?? '');
        if (pw.length < 6) throw new ApiError(400, 'weak_password', 'Пароль должен быть не короче 6 символов');
        if (pw.length > 200) throw new ApiError(400, 'bad_password', 'Слишком длинный пароль');
        const cur = this.authUser(req, false);
        const upgradeId = cur && !cur.password_hash ? Number(cur.id) : 0;
        if (!this.users.nickFree(nick, upgradeId)) throw new ApiError(409, 'nick_taken', 'Этот ник уже занят');
        if (!this.users.emailFree(email, upgradeId)) throw new ApiError(409, 'email_taken', 'Этот e-mail уже зарегистрирован');
        const hash = await hashPassword(pw);
        const user = tx(this.db, () => {
          if (!this.users.nickFree(nick, upgradeId)) throw new ApiError(409, 'nick_taken', 'Этот ник уже занят');
          if (!this.users.emailFree(email, upgradeId)) throw new ApiError(409, 'email_taken', 'Этот e-mail уже зарегистрирован');
          if (upgradeId) { this.users.setNick(upgradeId, nick); this.q.upgrade.run(email, hash, upgradeId); return this.users.get(upgradeId); }
          return this.users.create({ nick, email, passwordHash: hash, avatar: b.avatar ? validateAvatar(b.avatar) : 'mc' });
        });
        return sendJson(res, 200, this.session(user, { upgraded: !!upgradeId }));
      }

      case 'POST /api/v1/auth/login': {
        const b = await readJson(req);
        const user = this.users.findLogin(b.login);
        const ok = await verifyPassword(String(b.password ?? ''), user?.password_hash);
        if (!user || !ok) throw new ApiError(401, 'bad_credentials', 'Неверный логин или пароль');
        return sendJson(res, 200, this.session(user));
      }

      case 'POST /api/v1/auth/logout':
        this.users.deleteSession(this.bearer(req));
        return sendJson(res, 200, { ok: true });

      case 'POST /api/v1/auth/oauth/sandbox': {
        if (!this.sandbox) throw new ApiError(403, 'sandbox_disabled', 'Тестовый вход отключён на этом сервере');
        const b = await readJson(req);
        const provider = String(b.provider || '');
        if (!PROVIDERS.includes(provider)) throw new ApiError(400, 'bad_provider', 'provider: yandex | google | vk | telegram');
        const linkUser = this.authUser(req, false);
        const uid = b.provider_uid ? String(b.provider_uid) : `sandbox-${linkUser ? linkUser.id : Math.random().toString(36).slice(2, 12)}`;
        const profile = { name: b.name ? String(b.name) : `${provider}-тест`, sandbox: true };
        if (b.avatar) profile.avatar = String(b.avatar);
        const r = this.oauth._finishLogin(provider, uid, profile, linkUser);
        return sendJson(res, 200, r);
      }

      case 'GET /api/v1/auth/poll':
        return sendJson(res, 200, this.oauth.poll(url.searchParams.get('state')));

      case 'POST /auth/telegram/verify': {
        const b = await readJson(req);
        return sendJson(res, 200, this.oauth.telegramVerify(b, this.authUser(req, false)));
      }

      case 'GET /api/v1/me':
        return sendJson(res, 200, { ok: true, user: this.users.pub(this.authUser(req)) });

      case 'PATCH /api/v1/me': {
        const u = this.authUser(req);
        const b = await readJson(req);
        tx(this.db, () => {
          if (b.nick !== undefined) {
            const nick = validateNick(b.nick);
            if (!this.users.nickFree(nick, u.id)) throw new ApiError(409, 'nick_taken', 'Этот ник уже занят');
            this.users.setNick(u.id, nick);
          }
          if (b.avatar !== undefined) this.q.updAvatar.run(validateAvatar(b.avatar), u.id);
        });
        return sendJson(res, 200, { ok: true, user: this.users.pub(this.users.get(u.id)) });
      }

      case 'GET /api/v1/save': {
        const u = this.authUser(req);
        const r = this.q.saveGet.get(u.id);
        return sendJson(res, 200, { ok: true, save: r ? JSON.parse(r.save_json) : null, version: r ? Number(r.version) : 0, updated_at: r ? Number(r.updated_at) : 0 });
      }

      case 'PUT /api/v1/save': {
        const u = this.authUser(req);
        const b = await readJson(req);
        if (!b.save || typeof b.save !== 'object' || Array.isArray(b.save)) throw new ApiError(400, 'bad_save', 'Поле save должно быть объектом');
        const base = int(b.version, 0);
        const json = JSON.stringify(b.save);
        const out = tx(this.db, () => {
          const r = this.q.saveGet.get(u.id);
          const cur = r ? Number(r.version) : 0;
          if (r && base < cur && b.force !== true) {
            return { conflict: true, version: cur, save: JSON.parse(r.save_json), updated_at: Number(r.updated_at) };
          }
          const version = Math.max(cur, base) + 1, t = now();
          this.q.saveUpsert.run(u.id, json, version, t);
          if (typeof b.save.rp === 'number' && Number.isFinite(b.save.rp)) this.q.setRp.run(Math.max(0, Math.trunc(b.save.rp)), u.id);
          return { version, updated_at: t };
        });
        if (out.conflict) {
          throw new ApiError(409, 'conflict', 'На сервере более новое сохранение', { version: out.version, save: out.save, updated_at: out.updated_at });
        }
        return sendJson(res, 200, { ok: true, version: out.version, updated_at: out.updated_at });
      }

      case 'GET /api/v1/leaderboard': {
        const board = url.searchParams.get('board') === 'raid' ? 'raid' : 'pvp';
        const limit = Math.min(100, Math.max(1, int(url.searchParams.get('limit'), 50)));
        const me = this.authUser(req, false);
        const rows = (board === 'raid' ? this.q.raidTop : this.q.pvpTop).all(limit).map((r, i) => ({
          rank: i + 1, user_id: Number(r.user_id), nick: r.nick, avatar: r.avatar, value: Number(r.value),
          wins: Number(r.wins), losses: Number(r.losses), stage_idx: Number(r.stage_idx),
        }));
        let mine = null;
        if (me) {
          if (board === 'raid') {
            const r = this.q.raidGet.get(me.id);
            if (r) mine = { rank: Number(this.q.raidRank.get(r.stage_idx, r.stage_idx, r.damage).n) + 1, value: Number(r.damage) };
          } else if (Number(me.wins) + Number(me.losses) > 0) {
            mine = { rank: Number(this.q.pvpRank.get(me.pvp_elo).n) + 1, value: Number(me.pvp_elo) };
          }
        }
        return sendJson(res, 200, { ok: true, board, rows, me: mine });
      }

      case 'POST /api/v1/raid/score': {
        const u = this.authUser(req);
        const b = await readJson(req);
        const stage = int(b.stage_idx, -1), dmg = int(b.damage, -1);
        if (stage < 0 || stage > 100000 || dmg < 0 || dmg > 1e15) throw new ApiError(400, 'bad_score', 'Некорректные stage_idx / damage');
        const out = tx(this.db, () => {
          const r = this.q.raidGet.get(u.id);
          const improved = !r || stage > Number(r.stage_idx) || (stage === Number(r.stage_idx) && dmg > Number(r.damage));
          if (improved) this.q.raidUpsert.run(u.id, stage, dmg, now());
          const best = improved ? { stage_idx: stage, damage: dmg } : { stage_idx: Number(r.stage_idx), damage: Number(r.damage) };
          const rank = Number(this.q.raidRank.get(best.stage_idx, best.stage_idx, best.damage).n) + 1;
          return { ok: true, best, improved, rank };
        });
        return sendJson(res, 200, out);
      }
    }

    const m = /^\/auth\/(yandex|google|vk|telegram)\/(start|callback)$/.exec(p);
    if (m && method === 'GET') {
      if (m[2] === 'start') return this.oauth.start(m[1], url, res);
      if (m[1] === 'telegram') return this.oauth.telegramCallback(url, res);
      return this.oauth.callback(m[1], url, res);
    }
    throw new ApiError(404, 'not_found', 'Неизвестный адрес API');
  }
}
