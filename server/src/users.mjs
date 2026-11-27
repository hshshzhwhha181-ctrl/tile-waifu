// Users, sessions, passwords and provider identities.
import { scrypt as scryptCb, randomBytes, timingSafeEqual, createHash, randomInt } from 'node:crypto';
import { promisify } from 'node:util';
import { ApiError, now } from './util.mjs';
import { tx } from './db.mjs';

const scrypt = promisify(scryptCb);
export const PROVIDERS = ['yandex', 'google', 'vk', 'telegram'];
export const SESSION_TTL = 90 * 24 * 3600;
const SCRYPT_N = 16384, SCRYPT_R = 8, SCRYPT_P = 1, KEYLEN = 64;

export async function hashPassword(password) {
  const salt = randomBytes(16);
  const key = await scrypt(String(password).normalize('NFKC'), salt, KEYLEN, { N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P });
  return `scrypt$${SCRYPT_N}$${SCRYPT_R}$${SCRYPT_P}$${salt.toString('base64')}$${key.toString('base64')}`;
}

export async function verifyPassword(password, stored) {
  if (!stored || typeof stored !== 'string') {
    // burn comparable time so missing users are not distinguishable by latency
    await scrypt('x', 'dummy-salt-dummy', KEYLEN, { N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P });
    return false;
  }
  const parts = stored.split('$');
  if (parts.length !== 6 || parts[0] !== 'scrypt') return false;
  const [, N, r, p, saltB64, keyB64] = parts;
  const expected = Buffer.from(keyB64, 'base64');
  const key = await scrypt(String(password).normalize('NFKC'), Buffer.from(saltB64, 'base64'), expected.length,
    { N: Number(N), r: Number(r), p: Number(p), maxmem: 256 * 1024 * 1024 });
  return key.length === expected.length && timingSafeEqual(key, expected);
}

const sha256 = (s) => createHash('sha256').update(s).digest('hex');

export function normNick(nick) {
  return String(nick ?? '').normalize('NFC').replace(/[\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim();
}

export const nickKey = (nick) => normNick(nick).toLowerCase().replace(/ё/g, 'е');

export function validateNick(nick) {
  const n = normNick(nick);
  if (n.length < 2 || n.length > 20) throw new ApiError(400, 'bad_nick', 'Ник должен быть от 2 до 20 символов');
  return n;
}

export function validateAvatar(avatar) {
  const a = String(avatar ?? '').trim();
  if (!a || a.length > 64 || !/^[\w.\-:/]+$/u.test(a)) throw new ApiError(400, 'bad_avatar', 'Некорректный аватар');
  return a;
}

export function validateEmail(email) {
  const e = String(email ?? '').trim().toLowerCase();
  if (!e) return '';
  if (e.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) throw new ApiError(400, 'bad_email', 'Некорректный e-mail');
  return e;
}

export class Users {
  constructor(db) {
    this.db = db;
    this.q = {
      byId: db.prepare('SELECT * FROM users WHERE id = ?'),
      byNick: db.prepare('SELECT * FROM users WHERE nick_lc = ?'),
      byLogin: db.prepare("SELECT * FROM users WHERE nick_lc = ? OR (email <> '' AND email = ?) ORDER BY password_hash IS NULL LIMIT 1"),
      byEmail: db.prepare("SELECT id FROM users WHERE email <> '' AND email = ?"),
      insert: db.prepare('INSERT INTO users (nick, nick_lc, email, password_hash, avatar, created_at) VALUES (?, ?, ?, ?, ?, ?)'),
      setNick: db.prepare('UPDATE users SET nick = ?, nick_lc = ? WHERE id = ?'),
      providers: db.prepare('SELECT DISTINCT provider FROM oauth_identities WHERE user_id = ? ORDER BY provider'),
      sessIns: db.prepare('INSERT INTO sessions (token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)'),
      sessGet: db.prepare('SELECT user_id, expires_at FROM sessions WHERE token = ?'),
      sessDel: db.prepare('DELETE FROM sessions WHERE token = ?'),
      identGet: db.prepare('SELECT * FROM oauth_identities WHERE provider = ? AND provider_uid = ?'),
      identIns: db.prepare('INSERT INTO oauth_identities (provider, provider_uid, user_id, profile_json, created_at) VALUES (?, ?, ?, ?, ?)'),
      identUpd: db.prepare('UPDATE oauth_identities SET profile_json = ? WHERE id = ?'),
    };
  }

  get(id) {
    return this.q.byId.get(id) || null;
  }

  providers(userId) {
    return this.q.providers.all(userId).map((r) => r.provider);
  }

  /** Public user object as described in PROTOCOL.md. */
  pub(row) {
    if (!row) return null;
    const providers = this.providers(row.id);
    return {
      id: Number(row.id), nick: row.nick, email: row.email || '', avatar: row.avatar, rp: Number(row.rp),
      pvp_elo: Number(row.pvp_elo), wins: Number(row.wins), losses: Number(row.losses),
      guest: !row.password_hash && providers.length === 0, providers, created_at: Number(row.created_at),
    };
  }

  isGuest(row) {
    return !row.password_hash && this.providers(row.id).length === 0;
  }

  nickFree(nick, exceptId = 0) {
    const r = this.q.byNick.get(nickKey(nick));
    return !r || Number(r.id) === Number(exceptId);
  }

  setNick(id, nick) {
    this.q.setNick.run(nick, nickKey(nick), id);
  }

  emailFree(email, exceptId = 0) {
    if (!email) return true;
    const r = this.q.byEmail.get(String(email).toLowerCase());
    return !r || Number(r.id) === Number(exceptId);
  }

  /** A free nick derived from `base` (or «Гость-NNNN»). */
  uniqueNick(base) {
    let b = normNick(base);
    if (b.length > 15) b = b.slice(0, 15).trim();
    if (b.length >= 2 && this.nickFree(b)) return b;
    const stem = b.length >= 2 ? b : 'Гость';
    for (let i = 0; i < 40; i++) {
      const digits = i < 20 ? randomInt(1000, 10000) : randomInt(100000, 1000000);
      const n = `${stem}-${digits}`;
      if (this.nickFree(n)) return n;
    }
    return `${stem}-${randomBytes(4).toString('hex')}`;
  }

  create({ nick, email = '', passwordHash = null, avatar = 'mc' }) {
    const r = this.q.insert.run(nick, nickKey(nick), email, passwordHash, avatar, now());
    return this.get(Number(r.lastInsertRowid));
  }

  createSession(userId) {
    const token = randomBytes(32).toString('base64url');
    const t = now();
    this.q.sessIns.run(sha256(token), userId, t + SESSION_TTL, t);
    return token;
  }

  /** Returns the user row for a raw token, or null. */
  byToken(token) {
    if (!token || typeof token !== 'string' || token.length > 200) return null;
    const s = this.q.sessGet.get(sha256(token));
    if (!s) return null;
    if (Number(s.expires_at) < now()) {
      this.q.sessDel.run(sha256(token));
      return null;
    }
    return this.get(s.user_id);
  }

  deleteSession(token) {
    if (token) this.q.sessDel.run(sha256(token));
  }

  findLogin(login) {
    const l = String(login ?? '').trim();
    if (!l) return null;
    return this.q.byLogin.get(nickKey(l), l.toLowerCase()) || null;
  }

  /**
   * Provider identity → user. With `linkUser` the identity is attached to that user; if the identity already
   * belongs to someone else, we log into that account instead (the classic «войти с другого устройства» case).
   * Returns { user, switched }.
   */
  linkOrLogin(provider, providerUid, profile, linkUser) {
    if (!PROVIDERS.includes(provider)) throw new ApiError(400, 'bad_provider', 'Неизвестный провайдер');
    const uid = String(providerUid ?? '').trim();
    if (!uid || uid.length > 128) throw new ApiError(400, 'bad_provider_uid', 'Некорректный идентификатор провайдера');
    const pj = JSON.stringify(profile || {});
    return tx(this.db, () => {
      const ident = this.q.identGet.get(provider, uid);
      if (ident) {
        this.q.identUpd.run(pj, ident.id);
        const user = this.get(ident.user_id);
        return { user, switched: !!linkUser && Number(linkUser.id) !== Number(ident.user_id) };
      }
      let user = linkUser ? this.get(linkUser.id) : null;
      if (!user) {
        let avatar = 'mc';
        try { if (profile?.avatar) avatar = validateAvatar(profile.avatar); } catch { /* keep default */ }
        let email = '';
        try { email = validateEmail(profile?.email); } catch { email = ''; }
        if (email && !this.emailFree(email)) email = '';
        user = this.create({ nick: this.uniqueNick(profile?.name || provider), email, avatar });
      }
      this.q.identIns.run(provider, uid, user.id, pj, now());
      return { user: this.get(user.id), switched: false };
    });
  }
}
