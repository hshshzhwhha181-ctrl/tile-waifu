// Small HTTP helpers shared by the REST API and the OAuth routes.
export const VERSION = '0.12.0';
export const now = () => Math.floor(Date.now() / 1000);

export class ApiError extends Error {
  constructor(status, code, msg, extra = null) {
    super(msg || code);
    this.status = status;
    this.code = code;
    this.msg = msg || code;
    this.extra = extra;
  }
}

export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Max-Age': '86400',
};

export function sendJson(res, status, obj) {
  if (res.headersSent) return;
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    ...CORS_HEADERS,
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

export function sendHtml(res, status, html) {
  if (res.headersSent) return;
  res.writeHead(status, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(html);
}

export function sendError(res, err) {
  if (err instanceof ApiError) {
    sendJson(res, err.status, { ok: false, error: err.code, msg: err.msg, ...(err.extra || {}) });
  } else {
    console.error('[server] internal error:', err);
    sendJson(res, 500, { ok: false, error: 'internal', msg: 'Внутренняя ошибка сервера' });
  }
}

export const MAX_BODY = 2 * 1024 * 1024;

/** Reads a JSON body (≤ 2 MB). Empty body → {}. */
export function readJson(req, limit = MAX_BODY) {
  return new Promise((resolve, reject) => {
    const declared = Number(req.headers['content-length'] || 0);
    if (declared > limit) {
      reject(new ApiError(413, 'too_large', 'Слишком большой запрос (максимум 2 МБ)'));
      req.resume();
      return;
    }
    const chunks = [];
    let size = 0;
    let failed = false;
    req.on('data', (c) => {
      if (failed) return;
      size += c.length;
      if (size > limit) {
        failed = true;
        reject(new ApiError(413, 'too_large', 'Слишком большой запрос (максимум 2 МБ)'));
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      if (failed) return;
      const text = Buffer.concat(chunks).toString('utf8').trim();
      if (!text) return resolve({});
      try {
        const v = JSON.parse(text);
        if (v === null || typeof v !== 'object' || Array.isArray(v)) {
          return reject(new ApiError(400, 'bad_json', 'Тело запроса должно быть JSON-объектом'));
        }
        resolve(v);
      } catch {
        reject(new ApiError(400, 'bad_json', 'Некорректный JSON'));
      }
    });
    req.on('error', reject);
  });
}

export function clientIp(req) {
  const xf = req.headers['x-forwarded-for'];
  if (xf && process.env.TRUST_PROXY === '1') return String(xf).split(',')[0].trim();
  return req.socket.remoteAddress || '?';
}

/** Fixed-window limiter: allow `max` hits per `windowMs` per key, with bounded map size. */
export class RateLimiter {
  constructor(max, windowMs, maxEntries = 10000) {
    this.max = max;
    this.windowMs = windowMs;
    this.maxEntries = Math.max(1, Number(maxEntries) || 10000);
    this.map = new Map();
  }
  hit(key) {
    const t = Date.now();
    let e = this.map.get(key);
    if (!e || t - e.start >= this.windowMs) {
      if (!e && this.map.size >= this.maxEntries) {
        this.sweep();
        while (this.map.size >= this.maxEntries) {
          const oldest = this.map.keys().next().value;
          if (oldest === undefined) break;
          this.map.delete(oldest);
        }
      }
      e = { start: t, n: 0 };
      this.map.set(key, e);
    }
    e.n++;
    return e.n <= this.max;
  }
  sweep() {
    const t = Date.now();
    for (const [k, e] of this.map) if (t - e.start >= this.windowMs) this.map.delete(k);
  }
}

export function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

export function int(v, def = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : def;
}
