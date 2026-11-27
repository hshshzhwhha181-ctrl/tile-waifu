// End-to-end test: spawns the server on a free port with a temp DB and exercises REST + WebSocket PvP.
// Run: node server/e2e_test.mjs   → prints E2E_OK and exits 0.
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { createHash, createHmac } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const HERE = dirname(fileURLToPath(import.meta.url));
const T0 = Date.now();
const TG_TOKEN = '123456:TEST-telegram-bot-token';
let failures = 0, passes = 0;
const ok = (cond, name, extra = '') => {
  if (cond) { passes++; console.log(`  ok   ${name}`); }
  else { failures++; console.log(`  FAIL ${name} ${extra}`); }
  return cond;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const freePort = () => new Promise((res, rej) => {
  const s = createServer();
  s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => res(p)); });
  s.on('error', rej);
});

const tmp = mkdtempSync(join(tmpdir(), 'tw-e2e-'));
const dbPath = join(tmp, 'e2e.db');
const port = await freePort();
const BASE = `http://127.0.0.1:${port}`;

const child = spawn(process.execPath, [join(HERE, 'server.mjs')], {
  env: { ...process.env, PORT: String(port), HOST: '127.0.0.1', DB_PATH: dbPath, TELEGRAM_BOT_TOKEN: TG_TOKEN, ALLOW_DEV_OAUTH: '1',
    BOT_WAIT_MS: process.env.BOT_WAIT_MS || '1500', QUIET: '1', ENV_FILE: join(tmp, 'none.env'),
    YANDEX_CLIENT_ID: '', YANDEX_CLIENT_SECRET: '', GOOGLE_CLIENT_ID: '', GOOGLE_CLIENT_SECRET: '', VK_CLIENT_ID: '', VK_CLIENT_SECRET: '' },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let serverLog = '';
child.stdout.on('data', (d) => { serverLog += d; });
child.stderr.on('data', (d) => { serverLog += d; });

let finished = false;
async function finish(code) {
  if (finished) return;
  finished = true;
  child.kill();
  await sleep(150);
  try { rmSync(tmp, { recursive: true, force: true }); } catch { /* windows may hold WAL briefly */ }
  if (code !== 0 && serverLog.trim()) console.log('--- server log ---\n' + serverLog.trim().split('\n').slice(-30).join('\n'));
  console.log(`\n${passes} passed, ${failures} failed, ${((Date.now() - T0) / 1000).toFixed(1)} s`);
  if (code === 0) console.log('E2E_OK');
  process.exit(code);
}
const watchdog = setTimeout(() => { console.log('FAIL watchdog: test took longer than 25 s'); failures++; finish(1); }, 25000);

async function api(method, path, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const r = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const j = await r.json().catch(() => ({}));
  return { status: r.status, ...j };
}

function tgSign(fields) {
  const data = Object.keys(fields).sort().map((k) => `${k}=${fields[k]}`).join('\n');
  const secret = createHash('sha256').update(TG_TOKEN).digest();
  return { ...fields, hash: createHmac('sha256', secret).update(data).digest('hex') };
}

/** WebSocket client wrapper (Node 24 global WebSocket) with an awaitable message queue. */
function wsClient(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws?token=${encodeURIComponent(token)}`);
    const msgs = [];
    let waiters = [];
    ws.onmessage = (ev) => {
      const m = JSON.parse(ev.data);
      msgs.push(m);
      waiters = waiters.filter((w) => { const i = msgs.findIndex(w.pred); if (i >= 0) { w.res(msgs.splice(i, 1)[0]); clearTimeout(w.timer); return false; } return true; });
    };
    const c = {
      ws, msgs,
      send: (o) => ws.send(JSON.stringify(o)),
      wait: (t, ms = 4000, pred = () => true) => new Promise((res, rej) => {
        const p = (m) => m.t === t && pred(m);
        const i = msgs.findIndex(p);
        if (i >= 0) return res(msgs.splice(i, 1)[0]);
        const w = { pred: p, res, timer: setTimeout(() => { waiters = waiters.filter((x) => x !== w); rej(new Error(`timeout waiting for '${t}'`)); }, ms) };
        waiters.push(w);
      }),
      close: () => ws.close(),
    };
    ws.onopen = () => resolve(c);
    ws.onerror = (e) => reject(new Error('ws error ' + (e.message || '')));
  });
}

async function main() {
  // wait for the server to come up
  let health = null;
  for (let i = 0; i < 50 && !health; i++) {
    try { health = await api('GET', '/api/v1/health'); } catch { await sleep(100); }
  }
  console.log(`server up in ${Date.now() - T0} ms on port ${port}`);
  ok(health?.ok === true && health.version === '0.12.0' && health.db === 'sqlite', 'health', JSON.stringify(health));
  ok(health?.sandbox === true && health.oauth?.telegram === true && health.oauth?.yandex === false, 'health oauth flags');

  const opt = await fetch(BASE + '/api/v1/me', { method: 'OPTIONS' });
  ok(opt.status === 204 && opt.headers.get('access-control-allow-origin') === '*', 'CORS preflight');

  // guest
  const g = await api('POST', '/api/v1/auth/guest', { avatar: 'mc' });
  ok(g.ok && g.token && g.user?.guest === true && g.user.pvp_elo === 1000, 'guest login', JSON.stringify(g));
  const gid = g.user.id;
  let tok = g.token;

  const p = await api('PATCH', '/api/v1/me', { nick: 'Тестер', avatar: 'rin' }, tok);
  ok(p.ok && p.user.nick === 'Тестер' && p.user.avatar === 'rin', 'PATCH /me', JSON.stringify(p));
  ok((await api('GET', '/api/v1/me')).status === 401, '/me without token → 401');

  // sandbox link yandex / google / vk with Bearer → same user id
  for (const prov of ['yandex', 'google', 'vk']) {
    const r = await api('POST', '/api/v1/auth/oauth/sandbox', { provider: prov, provider_uid: `${prov}-uid-1`, name: `${prov} user` }, tok);
    ok(r.ok && r.linked === true && r.provider === prov && r.user.id === gid, `sandbox link ${prov}`, JSON.stringify(r));
  }
  const bad = await api('POST', '/api/v1/auth/oauth/sandbox', { provider: 'facebook' }, tok);
  ok(bad.status === 400, 'sandbox unknown provider → 400');

  // telegram widget verify
  const tgFields = tgSign({ id: 777000111, first_name: 'Аяка', username: 'ayaka_tw', auth_date: Math.floor(Date.now() / 1000) });
  const tg = await api('POST', '/auth/telegram/verify', tgFields, tok);
  ok(tg.ok && tg.provider === 'telegram' && tg.user?.id === gid && tg.token, 'telegram verify (signed)', JSON.stringify(tg));
  const tgBad = await api('POST', '/auth/telegram/verify', { ...tgFields, hash: 'deadbeef'.repeat(8) }, tok);
  ok(tgBad.status === 401 && tgBad.error === 'bad_signature', 'telegram bad hash → 401', JSON.stringify(tgBad));
  const tgOld = await api('POST', '/auth/telegram/verify', tgSign({ id: 1, first_name: 'X', auth_date: Math.floor(Date.now() / 1000) - 90000 }));
  ok(tgOld.status === 401 && tgOld.error === 'expired', 'telegram expired → 401');
  // telegram login without bearer → same account (identity lookup)
  const tg2 = await api('POST', '/auth/telegram/verify', tgFields);
  ok(tg2.ok && tg2.user.id === gid, 'telegram login (no bearer) finds same user');

  const me = await api('GET', '/api/v1/me', undefined, tok);
  const provs = (me.user?.providers || []).slice().sort().join(',');
  ok(me.ok && provs === 'google,telegram,vk,yandex' && me.user.guest === false, '/me providers has all 4', provs);

  // the real OAuth start without keys → 503
  const st = await fetch(`${BASE}/auth/yandex/start?state=abcdef123456`, { redirect: 'manual' });
  ok(st.status === 503, 'oauth start without keys → 503');
  const pl = await api('GET', '/api/v1/auth/poll?state=abcdef123456');
  ok(pl.ok === false && pl.error === 'provider_not_configured', 'poll reports provider_not_configured');
  ok((await api('GET', '/api/v1/auth/poll?state=nothing-here')).pending === true, 'poll pending');

  // save before register (must survive the upgrade)
  const s1 = await api('PUT', '/api/v1/save', { save: { rp: 42, hearts: 5, inv: ['a'] }, version: 0 }, tok);
  ok(s1.ok && s1.version === 1, 'save PUT v1', JSON.stringify(s1));

  // register-upgrade a fresh guest keeps id + save
  const g2 = await api('POST', '/api/v1/auth/guest', {});
  await api('PUT', '/api/v1/save', { save: { stage: 3 }, version: 0 }, g2.token);
  const weak = await api('POST', '/api/v1/auth/register', { nick: 'Аято', password: '123' }, g2.token);
  ok(weak.status === 400 && weak.error === 'weak_password', 'register weak_password → 400');
  const taken = await api('POST', '/api/v1/auth/register', { nick: 'тестер', password: 'secret123' }, g2.token);
  ok(taken.status === 409 && taken.error === 'nick_taken', 'register nick_taken → 409');
  const reg = await api('POST', '/api/v1/auth/register', { nick: 'Аято', email: 'ayato@example.com', password: 'secret123' }, g2.token);
  ok(reg.ok && reg.user.id === g2.user.id && reg.user.guest === false, 'register upgrade keeps guest id', JSON.stringify(reg));
  const s2 = await api('GET', '/api/v1/save', undefined, reg.token);
  ok(s2.ok && s2.save?.stage === 3 && s2.version === 1, 'save kept after upgrade');
  const etaken = await api('POST', '/api/v1/auth/register', { nick: 'Другой', email: 'AYATO@example.com', password: 'secret123' });
  ok(etaken.status === 409 && etaken.error === 'email_taken', 'register email_taken → 409');

  // login
  const l1 = await api('POST', '/api/v1/auth/login', { login: 'аято', password: 'secret123' });
  ok(l1.ok && l1.user.id === g2.user.id, 'login by nick (case-insensitive)', JSON.stringify(l1));
  const l2 = await api('POST', '/api/v1/auth/login', { login: 'ayato@example.com', password: 'secret123' });
  ok(l2.ok && l2.user.id === g2.user.id, 'login by email');
  const l3 = await api('POST', '/api/v1/auth/login', { login: 'Аято', password: 'wrong-pass' });
  ok(l3.status === 401 && l3.error === 'bad_credentials', 'login bad password → 401');

  // saves: version conflict + force
  const s3 = await api('PUT', '/api/v1/save', { save: { rp: 50 }, version: 1 }, tok);
  ok(s3.ok && s3.version === 2, 'save PUT v2');
  const s4 = await api('PUT', '/api/v1/save', { save: { rp: 1 }, version: 1 }, tok);
  ok(s4.status === 409 && s4.error === 'conflict' && s4.version === 2 && s4.save?.rp === 50, 'save stale → 409 conflict', JSON.stringify(s4));
  const s5 = await api('PUT', '/api/v1/save', { save: { rp: 7 }, version: 1, force: true }, tok);
  ok(s5.ok && s5.version === 3, 'save force overwrite');
  const s6 = await api('GET', '/api/v1/save', undefined, tok);
  ok(s6.ok && s6.save?.rp === 7 && s6.version === 3 && s6.updated_at > 0, 'save GET');

  // raid score + leaderboard
  const r1 = await api('POST', '/api/v1/raid/score', { stage_idx: 2, damage: 15000 }, tok);
  ok(r1.ok && r1.improved === true && r1.best.damage === 15000 && r1.rank === 1, 'raid score', JSON.stringify(r1));
  const r2 = await api('POST', '/api/v1/raid/score', { stage_idx: 2, damage: 9000 }, tok);
  ok(r2.ok && r2.improved === false && r2.best.damage === 15000, 'raid score keeps max');
  await api('POST', '/api/v1/raid/score', { stage_idx: 1, damage: 99999 }, reg.token);
  const lb = await api('GET', '/api/v1/leaderboard?board=raid&limit=10', undefined, tok);
  ok(lb.ok && lb.board === 'raid' && lb.rows.length === 2 && lb.rows[0].user_id === gid && lb.rows[0].value === 15000 && lb.me?.rank === 1,
    'leaderboard raid', JSON.stringify(lb));

  // ---- WebSocket PvP: private room between two humans ----
  const elo0A = (await api('GET', '/api/v1/me', undefined, tok)).user.pvp_elo;
  const elo0B = (await api('GET', '/api/v1/me', undefined, reg.token)).user.pvp_elo;
  const A = await wsClient(tok), B = await wsClient(reg.token);
  const wA = await A.wait('welcome'); await B.wait('welcome');
  ok(wA.user?.id === gid, 'ws welcome');
  const h2 = await api('GET', '/api/v1/health');
  ok(h2.online_players === 2, 'health online_players = 2');
  A.send({ t: 'ping' });
  ok(!!(await A.wait('pong')), 'ws ping/pong');
  A.send({ t: 'room_create' });
  const rc = await A.wait('room_created');
  ok(/^\d{6}$/.test(rc.code), 'room_created 6 digits');
  B.send({ t: 'room_join', code: '000000' === rc.code ? '999999' : '000000' });
  const nf = await B.wait('error');
  ok(nf.code === 'room_not_found', 'room_join wrong code → room_not_found');
  B.send({ t: 'room_join', code: rc.code });
  const [msA, msB] = await Promise.all([A.wait('match_start'), B.wait('match_start')]);
  ok(msA.seed === msB.seed && msA.match_id === msB.match_id && msA.mode === 'room' && msA.board_cfg?.seed === msA.seed,
    'both match_start, same seed', JSON.stringify(msA));
  ok(msA.opponent.id === reg.user.id && msA.opponent.bot === false && msB.opponent.id === gid && msA.duration_s === 180, 'match_start players');

  A.send({ t: 'progress', tiles_left: 60, tiles_total: 84, score: 120, combo: 2 });
  const op = await B.wait('opponent_progress');
  ok(op.tiles_left === 60 && op.tiles_total === 84 && op.score === 120 && op.combo === 2, 'progress forwarded');
  B.send({ t: 'sabotage', kind: 'ice' });
  const sb = await A.wait('sabotage');
  ok(sb.kind === 'ice' && sb.from === reg.user.id, 'sabotage ice forwarded');
  B.send({ t: 'sabotage', kind: 'fog' });
  const rl = await B.wait('error');
  ok(rl.code === 'rate_limited', 'sabotage rate limit');
  A.send({ t: 'emote', id: 'heart' });
  const em = await B.wait('emote');
  ok(em.id === 'heart' && em.from === gid, 'emote forwarded');

  A.send({ t: 'match_finish', cleared: true, tiles_left: 0, score: 900 });
  const [meA, meB] = await Promise.all([A.wait('match_end'), B.wait('match_end')]);
  ok(meA.you_won === true && meB.you_won === false && meA.winner_id === gid && meA.reason === 'cleared' && meA.your_score === 900,
    'both get match_end', JSON.stringify(meA));
  ok(meA.elo_delta > 0 && meB.elo_delta < 0 && meA.elo_after === elo0A + meA.elo_delta && meB.elo_before === elo0B, 'ELO winner up / loser down',
    `${meA.elo_delta} ${meB.elo_delta}`);
  const meNow = await api('GET', '/api/v1/me', undefined, tok);
  ok(meNow.user.pvp_elo === meA.elo_after && meNow.user.wins === 1, 'ELO persisted');
  const lbp = await api('GET', '/api/v1/leaderboard?board=pvp', undefined, reg.token);
  ok(lbp.ok && lbp.rows[0]?.user_id === gid && lbp.me?.rank === 2, 'leaderboard pvp');
  B.close();

  // ---- matchmaking alone → bot ----
  const tq = Date.now();
  A.send({ t: 'matchmake_join' });
  const q = await A.wait('queued');
  ok(q.elo === meA.elo_after && q.eta_s >= 1, 'queued');
  const bm = await A.wait('match_start', 8000);
  ok(bm.opponent?.bot === true && bm.mode === 'ranked' && Math.abs(bm.opponent.pvp_elo - bm.you.pvp_elo) <= 40, 'bot match_start',
    `${Date.now() - tq} ms ${JSON.stringify(bm.opponent)}`);
  A.send({ t: 'progress', tiles_left: 80, tiles_total: 84, score: 10, combo: 0 });
  const bp = await A.wait('opponent_progress', 5000);
  ok(bp.tiles_total === 84 && bp.tiles_left < 84 && bp.tiles_left % 2 === 0, 'bot opponent_progress', JSON.stringify(bp));
  A.send({ t: 'leave' });
  const fe = await A.wait('match_end');
  ok(fe.you_won === false && fe.reason === 'forfeit' && fe.elo_delta < 0, 'leave = forfeit vs bot');
  A.close();

  // unauthorized socket
  const bad2 = await new Promise((res) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws?token=nope`);
    let got = null;
    ws.onmessage = (ev) => { got = JSON.parse(ev.data); };
    ws.onclose = () => res(got);
    ws.onerror = () => {};
  });
  ok(bad2?.t === 'error' && bad2.code === 'unauthorized', 'ws bad token → unauthorized + close');

  const lo = await api('POST', '/api/v1/auth/logout', undefined, g2.token);
  ok(lo.ok && (await api('GET', '/api/v1/me', undefined, g2.token)).status === 401, 'logout invalidates token');

  // ---- DB checks ----
  await sleep(100);
  const db = new DatabaseSync(dbPath, { readOnly: true });
  const provRows = db.prepare('SELECT provider FROM oauth_identities WHERE user_id = ? ORDER BY provider').all(gid).map((r) => r.provider);
  ok(provRows.join(',') === 'google,telegram,vk,yandex', 'db oauth_identities 4 providers', provRows.join(','));
  const matches = db.prepare('SELECT * FROM pvp_matches ORDER BY id').all();
  ok(matches.length >= 2 && matches[0].winner_id === gid && matches[1].p2_id === null && !!matches[1].p2_bot_nick, 'db pvp_matches rows',
    JSON.stringify(matches));
  ok(!!db.prepare('SELECT 1 FROM player_saves WHERE user_id = ? AND version = 3').get(gid), 'db player_saves row');
  ok(!!db.prepare('SELECT 1 FROM leaderboard_raid WHERE user_id = ? AND damage = 15000').get(gid), 'db leaderboard_raid row');
  const jm = db.prepare('PRAGMA journal_mode').get();
  ok(String(Object.values(jm)[0]).toLowerCase() === 'wal', 'db WAL mode');
  db.close();
}

main()
  .then(() => { clearTimeout(watchdog); finish(failures ? 1 : 0); })
  .catch((e) => { clearTimeout(watchdog); console.log(`FAIL exception: ${e.stack || e.message}`); failures++; finish(1); });
