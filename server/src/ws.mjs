// Minimal RFC 6455 WebSocket server on top of node:http 'upgrade' (no npm deps).
// Text + binary-reject, masking, fragmentation (continuation frames), ping/pong, close handshake.
import { createHash } from 'node:crypto';
import { EventEmitter } from 'node:events';

const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
const MAX_MESSAGE = 256 * 1024;

export function acceptKey(key) {
  return createHash('sha1').update(key + GUID).digest('base64');
}

/** Completes the handshake. Returns a WsConn or null (after answering 400). */
export function upgrade(req, socket, head) {
  const key = req.headers['sec-websocket-key'];
  const ver = req.headers['sec-websocket-version'];
  const up = String(req.headers.upgrade || '').toLowerCase();
  if (up !== 'websocket' || !key || ver !== '13') {
    socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\nSec-WebSocket-Version: 13\r\n\r\n');
    return null;
  }
  socket.write(
    'HTTP/1.1 101 Switching Protocols\r\n' +
    'Upgrade: websocket\r\n' +
    'Connection: Upgrade\r\n' +
    `Sec-WebSocket-Accept: ${acceptKey(key)}\r\n\r\n`,
  );
  return new WsConn(socket, head);
}

export class WsConn extends EventEmitter {
  constructor(socket, head) {
    super();
    this.socket = socket;
    this.buf = head && head.length ? Buffer.from(head) : Buffer.alloc(0);
    this.frag = null; // { opcode, chunks, size }
    this.closed = false;
    this.closeSent = false;
    this.alive = true;
    socket.setNoDelay(true);
    socket.setTimeout(0);
    socket.on('data', (d) => this._onData(d));
    socket.on('close', () => this._finish(1006, ''));
    socket.on('error', () => this._finish(1006, ''));
    socket.on('end', () => this._finish(1006, ''));
    if (this.buf.length) setImmediate(() => this._onData(Buffer.alloc(0)));
  }

  get open() { return !this.closed && !this.closeSent; }

  send(obj) {
    if (!this.open) return false;
    const s = typeof obj === 'string' ? obj : JSON.stringify(obj);
    this._frame(0x1, Buffer.from(s, 'utf8'));
    return true;
  }

  ping() {
    if (this.open) this._frame(0x9, Buffer.alloc(0));
  }

  close(code = 1000, reason = '') {
    if (this.closed || this.closeSent) return;
    const r = Buffer.from(String(reason).slice(0, 100), 'utf8');
    const p = Buffer.alloc(2 + r.length);
    p.writeUInt16BE(code, 0);
    r.copy(p, 2);
    this._frame(0x8, p);
    this.closeSent = true;
    // give the peer a moment to answer, then hard-close
    this._killTimer = setTimeout(() => this.socket.destroy(), 1500);
    this._killTimer.unref?.();
  }

  terminate() {
    this.socket.destroy();
    this._finish(1006, '');
  }

  _frame(opcode, payload) {
    const len = payload.length;
    let header;
    if (len < 126) {
      header = Buffer.from([0x80 | opcode, len]);
    } else if (len < 65536) {
      header = Buffer.alloc(4);
      header[0] = 0x80 | opcode; header[1] = 126; header.writeUInt16BE(len, 2);
    } else {
      header = Buffer.alloc(10);
      header[0] = 0x80 | opcode; header[1] = 127; header.writeBigUInt64BE(BigInt(len), 2);
    }
    try { this.socket.write(Buffer.concat([header, payload])); } catch { /* socket gone */ }
  }

  _fail(code, reason) {
    this.close(code, reason);
    this.buf = Buffer.alloc(0);
  }

  _onData(d) {
    if (this.closed) return;
    if (d.length) this.buf = this.buf.length ? Buffer.concat([this.buf, d]) : d;
    while (this.buf.length >= 2) {
      const b0 = this.buf[0], b1 = this.buf[1];
      const fin = (b0 & 0x80) !== 0;
      const rsv = b0 & 0x70;
      const opcode = b0 & 0x0f;
      const masked = (b1 & 0x80) !== 0;
      let len = b1 & 0x7f;
      let off = 2;
      if (rsv) return this._fail(1002, 'rsv');
      if (!masked) return this._fail(1002, 'unmasked');
      if (len === 126) {
        if (this.buf.length < 4) return;
        len = this.buf.readUInt16BE(2); off = 4;
      } else if (len === 127) {
        if (this.buf.length < 10) return;
        const big = this.buf.readBigUInt64BE(2);
        if (big > BigInt(MAX_MESSAGE)) return this._fail(1009, 'too big');
        len = Number(big); off = 10;
      }
      if (len > MAX_MESSAGE) return this._fail(1009, 'too big');
      if (this.buf.length < off + 4 + len) return;
      const mask = this.buf.subarray(off, off + 4);
      const payload = Buffer.from(this.buf.subarray(off + 4, off + 4 + len));
      for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
      this.buf = this.buf.subarray(off + 4 + len);
      this._onFrame(fin, opcode, payload);
      if (this.closed) return;
    }
  }

  _onFrame(fin, opcode, payload) {
    this.alive = true;
    if (opcode >= 0x8) { // control frames: never fragmented, ≤125 bytes
      if (!fin || payload.length > 125) return this._fail(1002, 'bad control');
      if (opcode === 0x8) {
        const code = payload.length >= 2 ? payload.readUInt16BE(0) : 1005;
        if (!this.closeSent) {
          const p = payload.length >= 2 ? payload.subarray(0, 2) : Buffer.alloc(0);
          this._frame(0x8, p);
          this.closeSent = true;
        }
        this.socket.end();
        this._finish(code, payload.subarray(2).toString('utf8'));
      } else if (opcode === 0x9) {
        if (this.open) this._frame(0xA, payload);
      } else if (opcode === 0xA) {
        // pong: alive already set
      } else {
        this._fail(1002, 'bad opcode');
      }
      return;
    }
    if (opcode === 0x0) { // continuation
      if (!this.frag) return this._fail(1002, 'unexpected continuation');
      this.frag.chunks.push(payload);
      this.frag.size += payload.length;
      if (this.frag.size > MAX_MESSAGE) return this._fail(1009, 'too big');
      if (fin) {
        const { opcode: op, chunks } = this.frag;
        this.frag = null;
        this._deliver(op, Buffer.concat(chunks));
      }
      return;
    }
    if (opcode !== 0x1 && opcode !== 0x2) return this._fail(1002, 'bad opcode');
    if (this.frag) return this._fail(1002, 'interleaved');
    if (!fin) {
      this.frag = { opcode, chunks: [payload], size: payload.length };
      return;
    }
    this._deliver(opcode, payload);
  }

  _deliver(opcode, data) {
    if (opcode === 0x2) return this._fail(1003, 'text only');
    let text;
    try {
      text = new TextDecoder('utf-8', { fatal: true }).decode(data);
    } catch {
      return this._fail(1007, 'bad utf8');
    }
    if (this.open) this.emit('message', text);
  }

  _finish(code, reason) {
    if (this.closed) return;
    this.closed = true;
    clearTimeout(this._killTimer);
    if (!this.socket.destroyed) setTimeout(() => this.socket.destroy(), 1000).unref?.();
    this.emit('close', code, reason);
  }
}
