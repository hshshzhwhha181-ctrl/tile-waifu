#!/usr/bin/env node
// Tile Waifu 0.12.0 — online backend. Zero npm deps: node:http + node:sqlite + own RFC 6455 WebSocket.
// Run: node server/server.mjs   (env: see .env.example)
import { createServer } from 'node:http';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { CORS_HEADERS, sendError, sendJson, VERSION } from './src/util.mjs';
import { openDb } from './src/db.mjs';
import { Users } from './src/users.mjs';
import { OAuth } from './src/oauth.mjs';
import { Pvp } from './src/pvp.mjs';
import { Api } from './src/api.mjs';
import { upgrade } from './src/ws.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));

/**
 * Starts the server. Returns a promise of { port, server, db, close() }.
 * opts: { port, host, dbPath, quiet, publicUrl, botWaitMs, sandbox }
 */
export async function start(opts = {}) {
  const env = process.env;
  const port = opts.port ?? Number(env.PORT || 8787);
  const host = opts.host ?? env.HOST ?? '0.0.0.0';
  const dbPath = resolve(opts.dbPath ?? env.DB_PATH ?? join(HERE, 'data', 'tilewaifu.db'));
  const quiet = opts.quiet ?? env.QUIET === '1';
  const log = quiet ? () => {} : (...a) => console.log(new Date().toISOString(), ...a);
  const sandbox = opts.sandbox ?? ((env.ALLOW_DEV_OAUTH ?? (env.NODE_ENV === 'production' ? '0' : '1')) === '1');
  const botWaitMs = opts.botWaitMs ?? Number(env.BOT_WAIT_MS || 6000);

  const db = openDb(dbPath);
  const users = new Users(db);
  const pvp = new Pvp({ db, users, botWaitMs, log });
  let publicUrl = opts.publicUrl ?? env.PUBLIC_URL ?? '';
  const oauth = new OAuth({ users, publicUrl: publicUrl || `http://127.0.0.1:${port}`, log });
  const api = new Api({ db, users, oauth, pvp, sandbox });

  const server = createServer(async (req, res) => {
    let url;
    try { url = new URL(req.url, 'http://x'); } catch { return sendJson(res, 400, { ok: false, error: 'bad_url', msg: 'Некорректный адрес' }); }
    if (req.method === 'OPTIONS') { res.writeHead(204, CORS_HEADERS); return res.end(); }
    if (req.method === 'GET' && url.pathname === '/') {
      return sendJson(res, 200, { ok: true, name: 'Tile Waifu online', version: VERSION });
    }
    try {
      await api.handle(req, res, url);
    } catch (e) {
      sendError(res, e);
    }
  });
  server.headersTimeout = 15000;
  server.requestTimeout = 30000;

  server.on('upgrade', (req, socket, head) => {
    socket.on('error', () => {});
    let url;
    try { url = new URL(req.url, 'http://x'); } catch { socket.destroy(); return; }
    if (url.pathname !== '/ws') { socket.end('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n'); return; }
    const conn = upgrade(req, socket, head);
    if (!conn) return;
    const user = users.byToken(url.searchParams.get('token'));
    if (!user) {
      conn.send({ t: 'error', code: 'unauthorized', msg: 'Нужен действующий токен' });
      conn.close(4001, 'unauthorized');
      return;
    }
    pvp.accept(conn, user);
  });

  await new Promise((ok, fail) => {
    server.once('error', fail);
    server.listen(port, host, () => { server.off('error', fail); ok(); });
  });
  const realPort = server.address().port;
  if (!publicUrl) oauth.publicUrl = `http://127.0.0.1:${realPort}`;
  log(`[server] Tile Waifu ${VERSION} on http://${host}:${realPort}  db=${dbPath}  sandbox=${sandbox}  oauth=${JSON.stringify(oauth.flags)}`);

  let closed = false;
  return {
    port: realPort, server, db,
    close() {
      if (closed) return Promise.resolve();
      closed = true;
      pvp.close();
      oauth.close();
      return new Promise((ok) => {
        server.close(() => { try { db.close(); } catch { /* ignore */ } ok(); });
        server.closeAllConnections?.();
      });
    },
  };
}

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const envFile = process.env.ENV_FILE || join(HERE, '.env');
  if (existsSync(envFile)) process.loadEnvFile(envFile);
  const srv = await start().catch((e) => { console.error('[server] failed to start:', e.message); process.exit(1); });
  const stop = () => { srv.close().then(() => process.exit(0)); setTimeout(() => process.exit(0), 3000).unref(); };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}
