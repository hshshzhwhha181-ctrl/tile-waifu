// «Умный спарринг-соперник»: a server-side bot that races the player on the same board.
import { randomInt } from 'node:crypto';

const BOT_NICKS = ['Сакура-бот', 'Лунная Лиса', 'Юки-тян', 'Кицунэ-сэмпай', 'Тихая Химэ', 'Мико Аянэ', 'Хару-автомат', 'Рин-спарринг'];
const rnd = (a, b) => a + Math.random() * (b - a);

export function makeBot(humanElo) {
  const avatars = (process.env.BOT_AVATARS || 'mc').split(',').map((s) => s.trim()).filter(Boolean);
  return {
    id: -randomInt(1000, 1000000),
    nick: BOT_NICKS[randomInt(BOT_NICKS.length)],
    avatar: avatars[randomInt(avatars.length)] || 'mc',
    elo: Math.max(100, humanElo + randomInt(-40, 41)),
    bot: true,
  };
}

/**
 * Drives the bot player `bp` in match `m`. Callbacks:
 *   hooks.progress()            – bot progress changed (forward as opponent_progress)
 *   hooks.sabotage(kind)        – bot sends a sabotage
 *   hooks.emote(id)             – bot sends an emote
 *   hooks.finish()              – bot cleared the board
 */
export class BotDriver {
  constructor(m, bp, human, hooks) {
    this.m = m; this.bp = bp; this.human = human; this.hooks = hooks;
    this.t0 = Date.now();
    this.timer = null;
    this.burst = 0;
    this.nextSab = this.t0 + rnd(25, 40) * 1000;
    this.stopped = false;
    // higher ELO → faster (0.75 … 1.3 multiplier on the 1.6–3.4 s base interval)
    this.speed = Math.min(1.3, Math.max(0.75, 1.15 - (bp.elo - 1000) / 2000));
    this.minFinishMs = Number(process.env.BOT_MIN_FINISH_MS || 45000);
  }

  start() { this._schedule(rnd(1.6, 3.4) * 1000 * Math.min(1, this.speed)); }
  stop() { this.stopped = true; clearTimeout(this.timer); }

  _schedule(ms) {
    if (this.stopped) return;
    this.timer = setTimeout(() => this._step(), Math.max(200, ms));
    this.timer.unref?.();
  }

  onHumanEmote() {
    if (this.stopped || Math.random() > 0.4) return;
    const t = setTimeout(() => { if (!this.stopped) this.hooks.emote(['laugh', 'heart', 'cool'][randomInt(3)]); }, rnd(900, 2200));
    t.unref?.();
  }

  _step() {
    if (this.stopped || this.m.ended) return;
    const bp = this.bp, h = this.human, now = Date.now(), elapsed = now - this.t0;
    let quick = false;
    if (this.burst > 0) { this.burst--; quick = true; }
    else if (Math.random() < 0.18) { this.burst = randomInt(1, 3); }

    bp.tiles_left = Math.max(0, bp.tiles_left - 2);
    bp.combo = quick || this.burst > 0 ? bp.combo + 1 : (Math.random() < 0.35 ? bp.combo + 1 : 0);
    bp.score += 20 + 10 * Math.min(bp.combo, 10);

    if (bp.tiles_left <= 0 && elapsed < this.minFinishMs) {
      // never finishes before 45 s: hold on the last pair
      bp.tiles_left = 2;
      bp.combo = 0;
      this.hooks.progress();
      this._schedule(this.minFinishMs - elapsed + rnd(500, 3000));
      return;
    }
    this.hooks.progress();
    if (bp.tiles_left <= 0) { this.hooks.finish(); return; }

    if (now >= this.nextSab) {
      this.nextSab = now + rnd(25, 40) * 1000;
      this.hooks.sabotage(Math.random() < 0.5 ? 'ice' : 'fog');
    }
    if (bp.combo >= 4 && Math.random() < 0.25) this.hooks.emote('cool');
    else if (h.tiles_total > 0 && h.tiles_left < bp.tiles_left - 12 && Math.random() < 0.06) this.hooks.emote('angry');

    let ms = rnd(1.6, 3.4) * 1000 * this.speed;
    if (quick || this.burst > 0) ms = rnd(500, 850);
    else if (Math.random() < 0.12) ms += rnd(2000, 5000); // «задумалась»
    // rubber band: a decent player should win most races
    if (h.tiles_total > 0) {
      const humanFrac = h.tiles_left / h.tiles_total, botFrac = bp.tiles_left / Math.max(1, bp.tiles_total);
      if (botFrac < humanFrac - 0.08) ms *= 1.45;
      else if (botFrac > humanFrac + 0.3) ms *= 0.85;
    }
    this._schedule(ms);
  }
}
