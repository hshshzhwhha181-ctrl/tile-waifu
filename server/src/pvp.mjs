// WebSocket PvP: matchmaking (ELO window), private rooms, match relay, bot fallback, ELO + pvp_matches.
import { randomInt } from 'node:crypto';
import { now } from './util.mjs';
import { tx } from './db.mjs';
import { makeBot, BotDriver } from './bot.mjs';

const SHAPES = ['rect', 'heart', 'diamond', 'butterfly', 'ring', 'pyramid'];
const EMOTES = ['laugh', 'angry', 'heart', 'cool'];
const DURATION_S = 180;
const clampInt = (v, lo, hi) => { const n = Math.trunc(Number(v)); return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : lo; };

export function makeBoardCfg(seed) {
  const cols = 6, rows = 7, layers = 3, fill = 0.7;
  return { shape: SHAPES[seed % SHAPES.length], cols, rows, layers, fill, faces: 10, gold: 2, ice: 0, seed };
}
function estimateTiles(cfg) {
  const n = Math.round(cfg.cols * cfg.rows * cfg.layers * cfg.fill);
  return n - (n % 6);
}
const expected = (ra, rb) => 1 / (1 + 10 ** ((rb - ra) / 400));
function eloDelta(k, ra, rb, s) {
  let d = Math.round(k * (s - expected(ra, rb)));
  if (s === 1 && d < 1) d = 1;
  if (s === 0 && d > -1) d = -1;
  return d;
}

export class Pvp {
  constructor({ db, users, botWaitMs = 6000, log = () => {} }) {
    this.db = db; this.users = users; this.botWaitMs = botWaitMs; this.log = log;
    this.conns = new Set();
    this.queue = new Map(); // conn → {conn, uid, elo, since}
    this.rooms = new Map(); // code → {host, created}
    this.matches = new Map();
    const row = db.prepare('SELECT MAX(id) AS m FROM pvp_matches').get();
    this.nextMatchId = Number(row?.m || 0) + 1;
    this.qUpd = db.prepare('UPDATE users SET pvp_elo = MAX(100, pvp_elo + ?), wins = wins + ?, losses = losses + ? WHERE id = ?');
    this.qIns = db.prepare(`INSERT INTO pvp_matches (id, p1_id, p2_id, p2_bot_nick, seed, winner_id, p1_score, p2_score,
      p1_elo_delta, p2_elo_delta, mode, reason, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`);
    this.tick = setInterval(() => this._tick(), 250);
    this.heartbeat = setInterval(() => this._heartbeat(), 25000);
    this.tick.unref?.(); this.heartbeat.unref?.();
  }

  get online() { return this.conns.size; }

  close() {
    clearInterval(this.tick); clearInterval(this.heartbeat);
    for (const m of [...this.matches.values()]) this._stopMatch(m);
    for (const c of this.conns) c.terminate();
  }

  accept(conn, user) {
    conn.user = user;
    conn.st = { match: null, room: null };
    conn.rl = { start: Date.now(), n: 0 };
    this.conns.add(conn);
    conn.send({ t: 'welcome', user: this.users.pub(user) });
    conn.on('message', (text) => this._onMessage(conn, text));
    conn.on('close', () => this._onClose(conn));
  }

  _err(conn, code, msg) { conn.send({ t: 'error', code, msg }); }

  _onClose(conn) {
    this.conns.delete(conn);
    this.queue.delete(conn);
    this._dropRoom(conn);
    const m = conn.st.match;
    if (m && !m.ended) this._end(m, 1 - this._idx(m, conn), 'forfeit');
  }

  _onMessage(conn, text) {
    const t = Date.now();
    if (t - conn.rl.start > 1000) conn.rl = { start: t, n: 0 };
    if (++conn.rl.n > 40) return this._err(conn, 'rate_limited', 'Слишком много сообщений');
    let msg;
    try { msg = JSON.parse(text); } catch { return this._err(conn, 'bad_message', 'Некорректный JSON'); }
    if (!msg || typeof msg !== 'object' || typeof msg.t !== 'string') return this._err(conn, 'bad_message', 'Нет поля t');
    try {
      this._handle(conn, msg);
    } catch (e) {
      console.error('[pvp] handler error', e);
      this._err(conn, 'internal', 'Внутренняя ошибка');
    }
  }

  _handle(conn, msg) {
    const m = conn.st.match;
    switch (msg.t) {
      case 'ping': return conn.send({ t: 'pong', ts: Date.now() });
      case 'matchmake_join': {
        if (m) return this._err(conn, 'in_match', 'Вы уже в матче');
        this._dropRoom(conn);
        const u = this.users.get(conn.user.id) || conn.user;
        conn.user = u;
        if (!this.queue.has(conn)) this.queue.set(conn, { conn, uid: Number(u.id), elo: Number(u.pvp_elo), since: Date.now() });
        return conn.send({ t: 'queued', elo: Number(u.pvp_elo), eta_s: Math.max(1, Math.round(this.botWaitMs / 1000)) });
      }
      case 'matchmake_cancel':
        this.queue.delete(conn);
        return conn.send({ t: 'queue_left' });
      case 'room_create': {
        if (m) return this._err(conn, 'in_match', 'Вы уже в матче');
        this.queue.delete(conn);
        this._dropRoom(conn);
        let code;
        do { code = String(randomInt(0, 1000000)).padStart(6, '0'); } while (this.rooms.has(code));
        this.rooms.set(code, { host: conn, created: Date.now() });
        conn.st.room = code;
        return conn.send({ t: 'room_created', code });
      }
      case 'room_join': {
        if (m) return this._err(conn, 'in_match', 'Вы уже в матче');
        const code = String(msg.code ?? '').trim();
        const room = this.rooms.get(code);
        if (!room || !room.host.open || room.host.st.match) return this._err(conn, 'room_not_found', 'Комната не найдена');
        if (Number(room.host.user.id) === Number(conn.user.id)) return this._err(conn, 'own_room', 'Нельзя войти в свою же комнату');
        this.rooms.delete(code);
        room.host.st.room = null;
        this.queue.delete(conn); this.queue.delete(room.host);
        this._dropRoom(conn);
        return this._start(room.host, conn, 'room');
      }
      case 'leave':
        if (this.queue.delete(conn)) conn.send({ t: 'queue_left' });
        if (conn.st.room) { this._dropRoom(conn); conn.send({ t: 'room_left' }); }
        if (m && !m.ended) this._end(m, 1 - this._idx(m, conn), 'forfeit');
        return;
      case 'progress':
      case 'sabotage':
      case 'emote':
      case 'match_finish':
        if (!m || m.ended) return this._err(conn, 'not_in_match', 'Вы не в матче');
        return this._inMatch(conn, m, msg);
      default:
        return this._err(conn, 'unknown_type', `Неизвестный тип: ${msg.t}`);
    }
  }

  _dropRoom(conn) {
    if (conn.st?.room) { this.rooms.delete(conn.st.room); conn.st.room = null; }
  }

  _idx(m, conn) { return m.p[0].conn === conn ? 0 : 1; }

  _tick() {
    const t = Date.now();
    const entries = [...this.queue.values()].sort((a, b) => a.since - b.since);
    const used = new Set();
    for (let i = 0; i < entries.length; i++) {
      const a = entries[i];
      if (used.has(a)) continue;
      const wa = 100 + 50 * Math.floor((t - a.since) / 1000);
      for (let j = i + 1; j < entries.length; j++) {
        const b = entries[j];
        if (used.has(b) || a.uid === b.uid) continue;
        const wb = 100 + 50 * Math.floor((t - b.since) / 1000);
        if (Math.abs(a.elo - b.elo) <= Math.min(wa, wb)) {
          used.add(a); used.add(b);
          this.queue.delete(a.conn); this.queue.delete(b.conn);
          this._start(a.conn, b.conn, 'ranked');
          break;
        }
      }
    }
    for (const e of entries) {
      if (used.has(e) || !this.queue.has(e.conn)) continue;
      if (t - e.since >= this.botWaitMs) {
        this.queue.delete(e.conn);
        this._start(e.conn, null, 'ranked');
      }
    }
    for (const [code, r] of this.rooms) if (t - r.created > 15 * 60000 || r.host.closed) this.rooms.delete(code);
  }

  _heartbeat() {
    for (const c of this.conns) {
      if (!c.alive) { c.terminate(); continue; }
      c.alive = false;
      c.ping();
    }
  }

  _player(conn) {
    const u = this.users.get(conn.user.id) || conn.user;
    conn.user = u;
    return { id: Number(u.id), nick: u.nick, avatar: u.avatar, elo: Number(u.pvp_elo), bot: false, conn,
      tiles_left: 0, tiles_total: 0, score: 0, combo: 0, lastSab: 0, lastEmote: 0 };
  }

  _start(c1, c2, mode) {
    const seed = randomInt(1, 2 ** 31 - 1);
    const cfg = makeBoardCfg(seed);
    const p1 = this._player(c1);
    let p2;
    if (c2) p2 = this._player(c2);
    else {
      const b = makeBot(p1.elo);
      const tiles = estimateTiles(cfg);
      p2 = { ...b, conn: null, tiles_left: tiles, tiles_total: tiles, score: 0, combo: 0, lastSab: 0, lastEmote: 0 };
    }
    const m = { id: this.nextMatchId++, seed, cfg, mode, p: [p1, p2], ended: false, startedAt: Date.now(), bot: null };
    this.matches.set(m.id, m);
    for (const [me, op] of [[p1, p2], [p2, p1]]) {
      if (!me.conn) continue;
      me.conn.st.match = m;
      me.conn.send({
        t: 'match_start', match_id: m.id, seed, board_cfg: cfg, duration_s: DURATION_S,
        you: { id: me.id, nick: me.nick, avatar: me.avatar, pvp_elo: me.elo },
        opponent: { id: op.id, nick: op.nick, avatar: op.avatar, pvp_elo: op.elo, bot: op.bot },
        mode,
      });
    }
    m.timer = setTimeout(() => this._timeout(m), (DURATION_S + 5) * 1000);
    m.timer.unref?.();
    if (!c2) {
      const send = (o) => p1.conn.send(o);
      m.bot = new BotDriver(m, p2, p1, {
        progress: () => send({ t: 'opponent_progress', tiles_left: p2.tiles_left, tiles_total: p2.tiles_total, score: p2.score, combo: p2.combo }),
        sabotage: (kind) => send({ t: 'sabotage', kind, from: p2.id }),
        emote: (id) => send({ t: 'emote', id, from: p2.id }),
        finish: () => this._end(m, 1, 'cleared'),
      });
      m.bot.start();
    }
    this.log(`[pvp] match ${m.id} ${mode}: ${p1.nick} vs ${p2.nick}${p2.bot ? ' (bot)' : ''}`);
  }

  _inMatch(conn, m, msg) {
    const i = this._idx(m, conn), me = m.p[i], op = m.p[1 - i];
    const t = Date.now();
    switch (msg.t) {
      case 'progress': {
        me.tiles_left = clampInt(msg.tiles_left, 0, 5000);
        me.tiles_total = clampInt(msg.tiles_total, 0, 5000);
        me.score = clampInt(msg.score, 0, 1e9);
        me.combo = clampInt(msg.combo, 0, 10000);
        if (op.bot && me.tiles_total > 0 && op.tiles_total !== me.tiles_total) {
          const frac = op.tiles_left / Math.max(1, op.tiles_total);
          op.tiles_total = me.tiles_total;
          op.tiles_left = Math.max(2, Math.round((frac * me.tiles_total) / 2) * 2);
        }
        if (op.conn) op.conn.send({ t: 'opponent_progress', tiles_left: me.tiles_left, tiles_total: me.tiles_total, score: me.score, combo: me.combo });
        return;
      }
      case 'sabotage': {
        const kind = msg.kind;
        if (kind !== 'ice' && kind !== 'fog') return this._err(conn, 'bad_kind', 'kind: ice | fog');
        if (t - me.lastSab < 4000) return this._err(conn, 'rate_limited', 'Саботаж не чаще раза в 4 с');
        me.lastSab = t;
        if (op.conn) op.conn.send({ t: 'sabotage', kind, from: me.id });
        return;
      }
      case 'emote': {
        if (!EMOTES.includes(msg.id)) return this._err(conn, 'bad_emote', 'Неизвестная эмоция');
        if (t - me.lastEmote < 1500) return this._err(conn, 'rate_limited', 'Эмоции не чаще раза в 1.5 с');
        me.lastEmote = t;
        if (op.conn) op.conn.send({ t: 'emote', id: msg.id, from: me.id });
        else m.bot?.onHumanEmote();
        return;
      }
      case 'match_finish': {
        if (msg.tiles_left !== undefined) me.tiles_left = clampInt(msg.tiles_left, 0, 5000);
        if (msg.score !== undefined) me.score = clampInt(msg.score, 0, 1e9);
        if (msg.cleared === true) return this._end(m, i, 'cleared');
        return this._end(m, 1 - i, msg.reason === 'surrender' || msg.reason === 'forfeit' ? 'forfeit' : 'overflow');
      }
    }
  }

  _timeout(m) {
    if (m.ended) return;
    const [a, b] = m.p;
    let w = null;
    if (a.tiles_left !== b.tiles_left) w = a.tiles_left < b.tiles_left ? 0 : 1;
    else if (a.score !== b.score) w = a.score > b.score ? 0 : 1;
    this._end(m, w, 'timeout');
  }

  _stopMatch(m) {
    m.ended = true;
    clearTimeout(m.timer);
    m.bot?.stop();
    this.matches.delete(m.id);
    for (const p of m.p) if (p.conn && p.conn.st.match === m) p.conn.st.match = null;
  }

  /** winner: 0 | 1 | null (draw). */
  _end(m, winner, reason) {
    if (m.ended) return;
    this._stopMatch(m);
    const [a, b] = m.p;
    const sA = winner === null ? 0.5 : winner === 0 ? 1 : 0;
    const res = tx(this.db, () => {
      const ua = this.users.get(a.id), ub = b.bot ? null : this.users.get(b.id);
      const ea = Number(ua?.pvp_elo ?? a.elo), eb = b.bot ? b.elo : Number(ub?.pvp_elo ?? b.elo);
      const k = b.bot ? 16 : 32;
      const dA = eloDelta(k, ea, eb, sA);
      const dB = b.bot ? 0 : eloDelta(k, eb, ea, 1 - sA);
      this.qUpd.run(dA, sA === 1 ? 1 : 0, sA === 0 ? 1 : 0, a.id);
      if (!b.bot) this.qUpd.run(dB, sA === 0 ? 1 : 0, sA === 1 ? 1 : 0, b.id);
      const winnerId = winner === null ? null : m.p[winner].bot ? null : m.p[winner].id;
      this.qIns.run(m.id, a.id, b.bot ? null : b.id, b.bot ? b.nick : null, m.seed, winnerId, a.score, b.score,
        dA, dB, m.mode, reason, now());
      const fa = this.users.get(a.id), fb = b.bot ? null : this.users.get(b.id);
      return [
        { before: ea, after: Number(fa.pvp_elo) },
        { before: eb, after: b.bot ? eb : Number(fb.pvp_elo) },
      ];
    });
    const winnerId = winner === null ? null : m.p[winner].id;
    m.p.forEach((p, i) => {
      if (!p.conn) return;
      const op = m.p[1 - i];
      p.conn.user = this.users.get(p.id) || p.conn.user;
      p.conn.send({
        t: 'match_end', match_id: m.id, winner_id: winnerId, you_won: winner === i, reason,
        your_score: p.score, opp_score: op.score,
        elo_before: res[i].before, elo_after: res[i].after, elo_delta: res[i].after - res[i].before,
      });
    });
    this.log(`[pvp] match ${m.id} end: ${reason}, winner ${winnerId}`);
  }
}
