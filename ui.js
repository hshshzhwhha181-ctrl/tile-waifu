// ui.js v2 — «сладкий» мобильный интерфейс и ощущение игры Tile Waifu.
// Подключается ПОСЛЕДНИМ. Логику игры не меняет: оборачивает глобальные функции game.js
// (render, win, updateHud, say, shuffleBoard, renderWardrobe, renderPass, applyEquip) и следит за DOM.
// Публичный API: window.UI.go(screen), UI.burst(x,y), UI.confetti(), UI.showResult({type:'win'|'lose',...}).
'use strict';
(function () {
const UI = window.UI = window.UI || {};
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const R = f => { try { return f(); } catch { return undefined; } };
const mk = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
const RM = matchMedia('(prefers-reduced-motion: reduce)').matches;
const Q = RM ? 0.25 : 1;
const emit = (n, d) => document.dispatchEvent(new CustomEvent('ui:' + n, { detail: d }));
const wait = ms => new Promise(r => setTimeout(r, ms));
const ico = (n, cls = '') => `<img class="ui-ico ${cls}" src="art/icons/${n}.png" alt="" draggable="false">`;
const TILE_ICO = '<img class="ui-ico" src="art/tiles/ivory/00_sakura.png" alt="" draggable="false">';
const SVG = {
  LOCK: '<svg class="ui-svg" viewBox="0 0 24 24"><path d="M7 10V7a5 5 0 0110 0v3" fill="none" stroke="#e06d95" stroke-width="2.4"/><rect x="4.5" y="10" width="15" height="11" rx="2.5" fill="#e06d95"/><circle cx="12" cy="15.5" r="1.8" fill="#fff"/></svg>',
  FLAME: '<svg class="ui-svg" viewBox="0 0 24 24"><path d="M12 2c1 4 5.5 6 5.5 11.5a5.5 5.5 0 01-11 0c0-2.3 1.2-4 2.3-5 0 2.2 1 3.2 2.2 3.3C10 8.5 11 5.5 12 2z" fill="#ff8a3c"/><path d="M12 12c.5 2 2.6 2.8 2.6 5a2.6 2.6 0 01-5.2 0c0-1.2.6-2 1.2-2.6.2 1 .8 1.4 1.4 1.4-.4-1.3-.4-2.6 0-3.8z" fill="#ffd36a"/></svg>',
  RESTART: '<svg class="ui-svg" viewBox="0 0 24 24"><path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round"/><path d="M19.5 4v4.8h-4.8" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
};

// ---------- Доступ к состоянию игры (только чтение) ----------
const st = () => R(() => S) || {};
const ALL = () => R(() => ITEMS) || [];
const byId = id => R(() => ITEM[id]);
const HERO = () => R(() => HEROES) || {};
// вырезки героинь без фона (для меню, игры, победы, гардероба)
const CUT = { o_base: 'art/ui/mc_cut.webp', r_base: 'art/scenes/rin_vn.webp', h_base: 'art/scenes/hana_vn.webp', y_base: 'art/scenes/yue_vn.webp', n_base: 'art/scenes/nova_vn.webp' };
const STARS = { R: 3, SR: 4, SSR: 5 };
const BG_SW = {
  b_default: 'linear-gradient(160deg,#fff 0,#fde3ea 50%,#f7c8d6 100%)',
  b_tea: 'linear-gradient(160deg,#fff 0,#e6f2e3 50%,#cfe6d2 100%)',
  b_beach: 'linear-gradient(180deg,#bfe9ff 0,#e9f8ff 55%,#ffe6b5 100%)',
  b_neon: "url('art/bg_neon.webp') center/cover",
  b_night: "url('art/scenes/bg_rooftop.webp') center/cover",
};
// фон игрового стола по выбранному «фону» из гардероба
const PLAY_BG = {
  b_default: "url('art/ui/bg_play_sweet.webp')",
  b_tea: "linear-gradient(#e6f6ea66,#d2efdc55),url('art/ui/bg_play_sweet.webp')",
  b_beach: "linear-gradient(#c6ecff88,#fff3d455),url('art/ui/bg_play_sweet.webp')",
  b_neon: "linear-gradient(#1a1330aa,#1a133066),url('art/bg_neon.webp')",
  b_night: "linear-gradient(#1e1a3399,#1e1a3355),url('art/scenes/bg_rooftop.webp')",
};
function thumbStyle(it) {
  if (!it) return '';
  if (it.img) return `background-image:url('${it.img}')`;
  if (it.cat === 'skin') return `background:url('art/tiles/${it.id === 's_neon' ? 'neon' : 'ivory'}/00_sakura.png') center/72% no-repeat,${it.tile || '#fffaf0'};box-shadow:inset 0 0 0 3px ${it.back || '#ff9cc2'},inset 0 -6px 0 #0001`;
  if (it.cat === 'bg') return `background:${BG_SW[it.id] || '#ddd'}`;
  return '';
}
const outfitArt = it => (it && (CUT[it.id] || it.img)) || CUT.o_base;
const isCut = it => !!CUT[it?.id || 'o_base'];

// ---------- Обёртки функций game.js ----------
function wrap(name, after, before) {
  const orig = window[name];
  if (typeof orig !== 'function' || orig.__ui) return false;
  const w = function (...a) {
    if (before) try { before.apply(this, a); } catch (e) { console.warn('[ui]', name, e); }
    const r = orig.apply(this, a);
    if (after) try { after.call(this, r, ...a); } catch (e) { console.warn('[ui]', name, e); }
    return r;
  };
  w.__ui = true;
  window[name] = w;
  return true;
}

// ---------- Эмодзи → нарезанные иконки ----------
const EMO = [['💎', 'gem'], ['💡', 'hint'], ['↩️', 'undo'], ['↩', 'undo'], ['🔀', 'shuffle'], ['🔊', 'sound'], ['🔇', 'sound muted'], ['⭐', 'star'], ['🌟', 'star'],
  ['🎁', 'gift'], ['📜', 'calendar'], ['✅', 'star'], ['🏆', 'trophy'], ['💖', 'heart'], ['❤️', 'heart'], ['❤', 'heart'], ['💗', 'heart'], ['💕', 'heart'], ['🎫', 'ticket'], ['✉️', 'mail'],
  ['⚙️', 'settings'], ['🪙', 'coin'], ['🔒', '!LOCK'], ['🔥', '!FLAME']];
const EMO_MAP = Object.fromEntries(EMO);
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const EMO_SRC = '(' + EMO.map(e => esc(e[0])).join('|') + ')️?';
const EMO_TEST = new RegExp(EMO_SRC, 'u');
const SKIP_SEL = '#board,[data-noicon],script,style,textarea,input,#fx,#twVN';
function iconHTML(e) {
  const v = EMO_MAP[e] || EMO_MAP[e.replace('️', '')];
  if (!v) return null;
  if (v[0] === '!') return SVG[v.slice(1)];
  const [n, extra] = v.split(' ');
  return ico(n, 'sm ' + (extra || ''));
}
function iconizeText(node) {
  if (!node.isConnected || !EMO_TEST.test(node.data)) return;
  const p = node.parentElement; if (!p || p.closest(SKIP_SEL)) return;
  const frag = document.createDocumentFragment();
  const re = new RegExp(EMO_SRC, 'gu'); let last = 0, m;
  while ((m = re.exec(node.data))) {
    if (m.index > last) frag.appendChild(document.createTextNode(node.data.slice(last, m.index)));
    const h = iconHTML(m[1]);
    if (h) { const t = document.createElement('template'); t.innerHTML = h; frag.appendChild(t.content); }
    else frag.appendChild(document.createTextNode(m[0]));
    last = m.index + m[0].length;
  }
  if (last < node.data.length) frag.appendChild(document.createTextNode(node.data.slice(last)));
  node.replaceWith(frag);
}
function iconize(root) {
  if (!root) return;
  if (root.nodeType === 3) return iconizeText(root);
  if (root.nodeType !== 1 || root.closest(SKIP_SEL)) return;
  const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const list = []; let n; while ((n = w.nextNode())) if (EMO_TEST.test(n.data)) list.push(n);
  list.forEach(iconizeText);
}
UI.iconize = iconize;

// ---------- Движок частиц: один canvas, кадры идут только пока есть частицы ----------
const FX = (() => {
  const cv = mk('canvas'); cv.id = 'fx'; document.body.appendChild(cv);
  const ctx = cv.getContext('2d'); let W = 0, H = 0, D = 1; const P = []; let raf = 0, last = 0;
  const imgs = {};
  function size() { D = Math.min(1.5, devicePixelRatio || 1); W = innerWidth; H = innerHeight; cv.width = W * D; cv.height = H * D; ctx.setTransform(D, 0, 0, D, 0, 0); }
  size(); addEventListener('resize', size);
  const img = src => imgs[src] || (imgs[src] = Object.assign(new Image(), { src }));
  const eo = k => 1 - (1 - k) * (1 - k);
  const eio = k => k < .5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
  function add(p) { if (P.length > 420 || document.hidden) { if (p.done) p.done(); return; } p.t = p.t || 0; P.push(p); if (!raf) { last = performance.now(); raf = requestAnimationFrame(loop); } }
  function star(x, y, s, c, a) {
    ctx.globalAlpha = a; ctx.fillStyle = c; ctx.beginPath(); ctx.moveTo(x, y - s);
    ctx.quadraticCurveTo(x, y, x + s, y); ctx.quadraticCurveTo(x, y, x, y + s); ctx.quadraticCurveTo(x, y, x - s, y); ctx.quadraticCurveTo(x, y, x, y - s); ctx.fill();
  }
  function loop(now) {
    const dt = Math.min(.04, (now - last) / 1000); last = now; ctx.setTransform(D, 0, 0, D, 0, 0); ctx.globalAlpha = 1; ctx.clearRect(0, 0, W, H);
    for (let i = P.length - 1; i >= 0; i--) {
      const p = P[i]; p.t += dt;
      if (p.t >= p.life) { P.splice(i, 1); if (p.done) p.done(); continue; }
      if (p.t < 0) continue;
      const k = p.t / p.life;
      ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over'; ctx.setTransform(D, 0, 0, D, 0, 0);
      switch (p.type) {
        case 'petal': {
          p.vy += (p.g ?? 120) * dt; p.vx *= .985; p.vy *= .99; p.x += p.vx * dt + Math.sin(p.t * 4 + p.ph) * 24 * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
          ctx.globalAlpha = 1 - k * k; ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.scale(1, Math.abs(Math.cos(p.t * 5 + p.ph)) * .7 + .3);
          ctx.fillStyle = p.c; ctx.beginPath(); ctx.ellipse(0, 0, p.s, p.s * .62, 0, 0, Math.PI * 2); ctx.fill(); break;
        }
        case 'spark': {
          p.vx *= .93; p.vy = p.vy * .93 + (p.g || 0) * dt; p.x += p.vx * dt; p.y += p.vy * dt;
          ctx.globalCompositeOperation = 'lighter'; star(p.x, p.y, p.s * (1 - k * .6) * (.75 + .25 * Math.sin(p.t * 22 + p.ph)), p.c, 1 - k); break;
        }
        case 'ring': {
          const r = p.r0 + (p.r1 - p.r0) * eo(k); ctx.globalAlpha = (1 - k) * .9; ctx.strokeStyle = p.c; ctx.lineWidth = p.w * (1 - k) + .5;
          ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2); ctx.stroke(); break;
        }
        case 'glow': {
          const r = p.r * (.4 + .6 * eo(k)); const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
          g.addColorStop(0, p.c); g.addColorStop(1, 'rgba(255,255,255,0)'); ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 1 - k; ctx.fillStyle = g;
          ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2); ctx.fill(); break;
        }
        case 'beam': {
          ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 1 - k; ctx.lineCap = 'round';
          const g = ctx.createLinearGradient(p.x1, p.y1, p.x2, p.y2); g.addColorStop(0, '#fff3c4'); g.addColorStop(.5, '#ffffff'); g.addColorStop(1, '#ffd5df');
          ctx.strokeStyle = g; ctx.lineWidth = 9 * (1 - k) + 1;
          ctx.beginPath(); ctx.moveTo(p.x1, p.y1); ctx.lineTo(p.x2, p.y2); ctx.stroke(); break;
        }
        case 'fly': {
          const e = eio(k), u = 1 - e; const x = u * u * p.x0 + 2 * u * e * p.cx + e * e * p.x1, y = u * u * p.y0 + 2 * u * e * p.cy + e * e * p.y1;
          const im = img(p.src); const s = p.s * (k < .15 ? .6 + k / .15 * .55 : 1.15 - .45 * (k - .15) / .85);
          if (im.complete && im.naturalWidth) { ctx.globalAlpha = k < .1 ? k * 10 : 1; ctx.drawImage(im, x - s / 2, y - s / 2, s, s); }
          if ((p.n = (p.n || 0) + 1) % 2 === 0) add({ type: 'spark', x, y, vx: 0, vy: 0, s: 3.5, c: p.trail || '#ffd5df', life: .28, ph: 0 });
          break;
        }
        case 'confetti': {
          p.vy += 260 * dt; p.vx *= .99; p.vy = Math.min(p.vy, 260); p.x += p.vx * dt + Math.sin(p.t * 3 + p.ph) * 30 * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
          ctx.globalAlpha = k > .8 ? (1 - k) * 5 : 1; ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.scale(1, Math.cos(p.t * 8 + p.ph));
          ctx.fillStyle = p.c; if (p.round) { ctx.beginPath(); ctx.ellipse(0, 0, p.s, p.s * .6, 0, 0, 7); ctx.fill(); } else ctx.fillRect(-p.s, -p.s * .45, p.s * 2, p.s * .9); break;
        }
        case 'ember': {
          p.y += p.vy * dt; p.x += Math.sin(p.t * 3 + p.ph) * 26 * dt; ctx.globalCompositeOperation = 'lighter';
          ctx.globalAlpha = Math.sin(k * Math.PI) * .9; ctx.fillStyle = p.c; ctx.beginPath(); ctx.arc(p.x, p.y, p.s, 0, 7); ctx.fill();
          ctx.globalAlpha *= .35; ctx.beginPath(); ctx.arc(p.x, p.y, p.s * 3, 0, 7); ctx.fill(); break;
        }
        case 'heart': {
          p.y += p.vy * dt; p.x += Math.sin(p.t * 4 + p.ph) * 30 * dt; const im = img('art/icons/heart.png'); const s = p.s * (k < .2 ? k / .2 : 1);
          ctx.globalAlpha = k > .7 ? (1 - k) / .3 : 1; if (im.complete && im.naturalWidth) ctx.drawImage(im, p.x - s / 2, p.y - s / 2, s, s); break;
        }
      }
    }
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    raf = P.length ? requestAnimationFrame(loop) : 0;
    if (!raf) { ctx.setTransform(D, 0, 0, D, 0, 0); ctx.clearRect(0, 0, W, H); }
  }
  return { add, img, clear() { P.length = 0; } };
})();
UI.fx = FX;
['gem', 'heart', 'star'].forEach(n => FX.img(`art/icons/${n}.png`));

const PETALS = ['#ffd5df', '#f7b6c6', '#fff2d6', '#f59ab7', '#ffe9ee'];
function burst(x, y, o = {}) {
  const n = Math.round((o.n ?? 14) * Q), sp = o.speed || 170;
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2, v = sp * (.35 + Math.random());
    FX.add({ type: 'petal', x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 70, rot: Math.random() * 6, vr: (Math.random() - .5) * 12, s: 3 + Math.random() * 4.5, c: (o.colors || PETALS)[i % (o.colors || PETALS).length], life: .8 + Math.random() * .7, ph: Math.random() * 6 });
  }
  const ns = Math.round((o.sparks ?? 10) * Q);
  for (let i = 0; i < ns; i++) {
    const a = Math.random() * Math.PI * 2, v = sp * 1.3 * (.3 + Math.random());
    FX.add({ type: 'spark', x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, s: 4 + Math.random() * 7, c: o.spark || '#ffe7a3', life: .45 + Math.random() * .45, ph: Math.random() * 6 });
  }
  if (o.ring !== 0) FX.add({ type: 'ring', x, y, r0: 6, r1: o.ring || 48, w: 3.5, c: o.ringColor || '#f7c86a', life: .5 });
  if (o.glow) FX.add({ type: 'glow', x, y, r: o.glow, c: o.glowColor || 'rgba(255,240,200,.9)', life: .5 });
}
function confetti(n = 120, y0 = -20) {
  const cols = ['#f7c86a', '#f59ab7', '#ef7fa3', '#fffaf2', '#9ddcc0', '#c7aef0'];
  const fr = frameRect();
  for (let i = 0; i < n * Q; i++) FX.add({ type: 'confetti', x: fr.left + Math.random() * fr.width, y: y0 - Math.random() * 200, vx: (Math.random() - .5) * 120, vy: 40 + Math.random() * 120,
    rot: Math.random() * 6, vr: (Math.random() - .5) * 10, s: 4 + Math.random() * 4, c: cols[i % cols.length], round: Math.random() < .35, life: 2.6 + Math.random() * 1.6, ph: Math.random() * 6 });
}
function flyIcon(src, from, to, o = {}) {
  const x0 = from.x, y0 = from.y, x1 = to.x, y1 = to.y;
  FX.add({ type: 'fly', src, x0, y0, x1, y1, cx: (x0 + x1) / 2 + (Math.random() - .5) * 140, cy: Math.min(y0, y1) - 60 - Math.random() * 80, s: o.s || 26, life: o.life || .75, trail: o.trail, done: o.done, t: o.delay ? -o.delay : 0 });
}
function hearts(x, y, n = 3) { for (let i = 0; i < n * Q; i++) FX.add({ type: 'heart', x: x + (Math.random() - .5) * 60, y, vy: -60 - Math.random() * 50, s: 16 + Math.random() * 12, life: 1.1 + Math.random() * .5, ph: Math.random() * 6, t: -i * .12 }); }
const center = e => { const r = e.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2, r }; };
const frameRect = () => $('#app')?.getBoundingClientRect() || { left: 0, top: 0, width: innerWidth, height: innerHeight };
const bumpEl = e => { if (!e) return; e.classList.remove('bump'); void e.offsetWidth; e.classList.add('bump'); };
UI.burst = burst; UI.confetti = confetti;

// ---------- Звуковые акценты (тихие, уважают настройку звука) ----------
let ac;
function chime(notes, o = {}) {
  if (!st().sound) return;
  try {
    ac = ac || new (window.AudioContext || window.webkitAudioContext)();
    notes.forEach((f, i) => {
      const os = ac.createOscillator(), g = ac.createGain(), t = ac.currentTime + i * (o.step ?? .07), d = o.dur || .35;
      os.type = o.type || 'sine'; os.frequency.value = f;
      g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(o.vol || .07, t + .012); g.gain.exponentialRampToValueAtTime(.0001, t + d);
      os.connect(g).connect(ac.destination); os.start(t); os.stop(t + d + .05);
    });
  } catch {}
}

// ---------- Фоны экранов, лепестки, фивер ----------
function addBg(sec, cls) { if (!sec || sec.querySelector(':scope > .scrBg')) return; const b = mk('div', 'scrBg' + (cls ? ' ' + cls : '')); sec.prepend(b); return b; }
const feverFx = mk('div'); feverFx.id = 'feverFx'; document.body.appendChild(feverFx);
function petalLayer(n) {
  const l = mk('div'); l.id = 'petalLayer';
  for (let i = 0; i < (RM ? 0 : n); i++) {
    const b = mk('b'); b.style.left = Math.random() * 100 + '%'; b.style.animationDuration = 10 + Math.random() * 9 + 's'; b.style.animationDelay = -Math.random() * 18 + 's';
    b.style.setProperty('--dx', (Math.random() * 160 - 40) + 'px'); b.style.scale = (.6 + Math.random() * .7).toFixed(2); l.appendChild(b);
  }
  return l;
}

// ---------- Верхняя панель: профиль, кристаллы, звук ----------
function buildTopbar() {
  const tb = $('#topbar'); if (!tb) return;
  const br = tb.querySelector('.brand');
  if (br) br.innerHTML = '<i class="ava"><b id="tbLv">Ур. 1</b></i><span class="bTxt"><b id="tbName">Маджонг-тян</b><span class="xpBar"><i id="tbXp"></i><span id="tbXpT"></span></span></span>';
  const w = tb.querySelector('.wallet'), gems = $('#gems');
  if (w && gems) {
    w.textContent = '';
    const pill = mk('span', 'pill'); pill.innerHTML = ico('gem') + '<b class="gemsView"></b>';
    const plus = mk('button', 'plusBtn', '+'); plus.title = 'Пропуск и подарки'; plus.onclick = () => go('pass');
    pill.appendChild(plus); w.appendChild(gems); w.appendChild(pill);
  }
  const snd = mk('button', 'roundBtn'); snd.id = 'topSound'; snd.title = 'Звук';
  snd.onclick = () => { $('#btnSound')?.click(); paintSound(); };
  tb.insertBefore(snd, tb.querySelector('nav'));
  paintSound();
}
function paintSound() {
  const on = st().sound !== false;
  const h = ico('sound', on ? '' : 'muted');
  ['#topSound', '#hudSound'].forEach(s => { const e = $(s); if (e) e.innerHTML = h; });
  const b = $('#btnSound'); if (b) b.title = on ? 'Звук включён' : 'Звук выключен';
}
function refreshTop() {
  const S_ = st(), ps = passState();
  const set = (id, v) => { const e = document.getElementById(id); if (e && e.textContent !== String(v)) e.textContent = v; };
  set('tbLv', `Ур. ${S_.level || 1}`);
  set('tbName', HERO()[byId(S_.equipped?.outfit)?.hero] || 'Маджонг-тян');
  const x = $('#tbXp'); if (x) x.style.width = (ps.tier >= 10 ? 100 : (ps.xp % ps.step) / ps.step * 100) + '%';
  set('tbXpT', ps.tier >= 10 ? 'Сезон пройден' : `Пропуск ${ps.tier} · ${ps.xp % ps.step}/${ps.step}`);
}

// ---------- Нижнее меню: строится из кнопок nav ----------
const TAB_META = { home: ['Главная', 'home'], play: ['Играть', 'TILE'], gacha: ['Призыв', 'gem'], wardrobe: ['Гардероб', 'wardrobe'], pass: ['Пропуск', 'ticket'],
  story: ['Сюжет', 'mail'], events: ['События', 'gift'], chapters: ['Главы', 'mail'], map: ['Карта', 'calendar'], heroes: ['Героини', 'heart'], shop: ['Магазин', 'gift'] };
const icoFor = k => { const m = TAB_META[k]; return !m ? ico('star') : m[1] === 'TILE' ? TILE_ICO : ico(m[1]); };
function buildTabs() {
  let tb = $('#tabbar');
  if (!tb) { tb = mk('nav'); tb.id = 'tabbar'; }
  $('#app').appendChild(tb);
  const list = [['home', 'Главная']].concat($$('#topbar nav button[data-screen]').map(b => [b.dataset.screen, b.textContent.trim()]));
  tb.innerHTML = '';
  for (const [scr, label] of list) {
    const m = TAB_META[scr];
    const b = mk('button', 'tab'); b.dataset.go = scr;
    b.innerHTML = `<span class="tIco">${icoFor(scr)}</span><span>${m ? m[0] : label}</span><i class="dot"></i>`;
    b.onclick = () => go(scr);
    tb.appendChild(b);
  }
  // в нижнем меню 5 вкладок, остальные экраны открываются из главного меню
  const prio = ['home', 'story', 'play', 'gacha', 'wardrobe', 'pass', 'events', 'heroes'];
  const tabs = [...tb.children].sort((a, b) => (prio.indexOf(a.dataset.go) + 1 || 99) - (prio.indexOf(b.dataset.go) + 1 || 99));
  tabs.forEach((t, i) => { t.classList.toggle('extra', i >= 5); tb.appendChild(t); });
  syncScreen(true); paintDots();
}
const activeScreen = () => ($('.screen.active')?.id || '').replace('screen-', '');
function go(name) {
  if (name === activeScreen()) return;
  const nb = $(`#topbar nav button[data-screen="${name}"]`);
  if (nb) nb.click();
  else {
    $$('.screen').forEach(s => s.classList.toggle('active', s.id === 'screen-' + name));
    $$('#topbar nav button').forEach(b => b.classList.remove('active'));
  }
  syncScreen();
}
UI.go = go;
let curScreen = '';
function syncScreen(force) {
  const s = activeScreen();
  if (s === curScreen && !force) return;
  const prev = curScreen; curScreen = s;
  document.documentElement.dataset.screen = s;
  $$('#tabbar .tab').forEach(t => t.classList.toggle('active', t.dataset.go === s));
  $$('.tw-screen').forEach(sec => addBg(sec));
  if (s === 'home') refreshHome(prev !== 'home');
  if (s === 'play') requestAnimationFrame(() => { R(() => fit()); updateHudNow(); runDeal(); });
  if (s === 'gacha') decorateGacha();
  if (s !== 'play') clearInterval(emberT);
  emit('screen', { screen: s, prev });
}

// ---------- Главное меню ----------
const HOME_LINES = ['С возвращением! Сыграем партию?', 'Я соскучилась~ Давай ещё уровень!', 'Задание дня уже ждёт тебя.', 'На баннере новая героиня… посмотрим?',
  'Хи-хи, не смотри так пристально~', 'Собери пару и получи кристаллы!', 'Сегодня отличный день для маджонга.'];
function greet() { const h = new Date().getHours(); return h < 6 ? 'Не спится? Сыграем тихонько?' : h < 12 ? 'Доброе утро! Чай уже заварен~' : h < 18 ? 'Добрый день! Готов к новой партии?' : 'Добрый вечер~ Фонари уже зажглись.'; }
let bubbleT;
function homeSay(t) {
  const b = $('.homeBubble'); if (!b) return;
  b.textContent = t; b.classList.remove('show'); void b.offsetWidth; b.classList.add('show'); clearTimeout(bubbleT); bubbleT = setTimeout(() => b.classList.remove('show'), 3800);
}
function hBtn(go_, cls, icon, title, sub, extra = '') {
  return `<button class="hBtn ${cls}" data-go="${go_}"><span class="hIco">${icon}</span><span class="hTxt">${title}${sub != null ? `<small>${sub}</small>` : ''}${extra}</span><span class="chev">›</span></button>`;
}
function buildHome() {
  if ($('#screen-home')) return;
  const s = mk('section', 'screen'); s.id = 'screen-home';
  s.innerHTML = `<div class="scrBg"></div>
    <img class="homeGirl" alt="" draggable="false">
    <div class="homeBubble"></div>
    <div class="homeQuick">
      <button class="qBtn" data-go="story" id="qStory">${ico('mail')}<span>Сюжет</span></button>
      <button class="qBtn" data-go="pass" id="qPass">${ico('gift')}<span>Награды</span></button>
    </div>
    <div class="homeCol">
      <div class="homeLogo"><img src="art/ui/logo_sweet.webp" alt="Tile Waifu" draggable="false"></div>
      <button class="hBtn hPlay" data-go="play"><span class="tiles2"><i></i><i></i></span><span class="hTxt">Играть<small id="hLevel"></small></span><span class="chev">›</span></button>
      ${hBtn('play', 'hDaily', ico('calendar'), 'Задание дня', '', '<span class="mini"><i id="hQuestBar"></i></span>').replace('<small></small>', '<small id="hQuestTxt"></small>')}
      ${hBtn('gacha', 'hSummon', ico('gem'), 'Призыв', 'Шанс SSR повышен!')}
      ${hBtn('wardrobe', '', ico('wardrobe'), 'Гардероб', '').replace('<small></small>', '<small id="hWard"></small>')}
      <div class="homeExtra"></div>
    </div>`;
  s.prepend(petalLayer(12));
  s.querySelectorAll('[data-go]').forEach(b => b.addEventListener('click', () => go(b.dataset.go)));
  const girl = s.querySelector('.homeGirl');
  girl.addEventListener('click', e => {
    girl.classList.remove('hop'); void girl.offsetWidth; girl.classList.add('hop');
    setTimeout(() => girl.classList.remove('hop'), 600);
    burst(e.clientX, e.clientY, { n: 6, sparks: 6, colors: ['#ff8fb0', '#ffb3c8', '#ffd5df'], ring: 30 });
    hearts(e.clientX, e.clientY, 3);
    homeSay(HOME_LINES[Math.random() * HOME_LINES.length | 0]); chime([880, 1320], { vol: .04 });
    emit('heroTap', { where: 'home' });
  });
  $('#app').insertBefore(s, $('#screen-play'));
}
function passState() {
  const P = R(() => PASS), step = R(() => PASS_STEP) || 30, S_ = st();
  const tier = Math.min(10, (S_.passXP || 0) / step | 0);
  let claim = 0;
  if (P) P.forEach((p, i) => { if (i < tier) { if (!S_.passClaimed?.['f' + i]) claim++; if (S_.passPremium && !S_.passClaimed?.['p' + i]) claim++; } });
  return { tier, claim, step, xp: S_.passXP || 0 };
}
function refreshHome(entering) {
  const S_ = st(); const home = $('#screen-home'); if (!home) return;
  const o = byId(S_.equipped?.outfit);
  const g = home.querySelector('.homeGirl'), src = outfitArt(o);
  if (g.dataset.src !== src) { g.dataset.src = src; g.src = src; g.classList.toggle('framed', !isCut(o)); }
  if (entering) { g.style.animation = 'none'; void g.offsetWidth; g.style.animation = ''; home.querySelectorAll('.hBtn,.homeLogo').forEach(b => { b.style.animation = 'none'; void b.offsetWidth; b.style.animation = ''; }); }
  const set = (sel, v) => { const e = $(sel); if (e && e.textContent !== v) e.textContent = v; };
  const cur = R(() => TW.st().cur);
  set('#hLevel', cur ? `Глава ${String(cur).replace('-', ' · сцена ')}` : `Уровень ${S_.level || 1}`);
  const q = Math.min(S_.questPairs || 0, 40);
  set('#hQuestTxt', S_.questDone ? 'Выполнено! Завтра будет новое' : `Собери 40 пар · ${q}/40 · +150`);
  const qb = $('#hQuestBar'); if (qb) qb.style.width = (S_.questDone ? 100 : q / 40 * 100) + '%';
  const outfits = ALL().filter(i => i.cat === 'outfit');
  set('#hWard', `Наряды ${outfits.filter(i => S_.owned?.[i.id]).length}/${outfits.length}`);
  // экраны других модулей (героини, события…) получают свои кнопки в меню
  const navScr = $$('#topbar nav button[data-screen]').map(b => [b.dataset.screen, b.textContent.trim()]);
  const ex = home.querySelector('.homeExtra');
  const want = navScr.filter(([k]) => !['play', 'gacha', 'wardrobe', 'pass', 'story'].includes(k));
  if (!want.length) want.push(['pass', 'Пропуск']);
  for (const [scr, label] of want) {
    if (ex.querySelector(`[data-go="${scr}"]`)) continue;
    const m = TAB_META[scr];
    const sub = scr === 'events' ? '' : scr === 'heroes' ? 'Симпатия и истории' : scr === 'pass' ? 'Сезон Neon Night' : '';
    const t = mk('template'); t.innerHTML = hBtn(scr, scr === 'events' ? 'hEvent' : '', icoFor(scr), m ? m[0] : label, scr === 'events' ? null : sub, scr === 'events' ? '<span class="neonTag">NEON NIGHT</span>' : '').trim();
    const nb = t.content.firstChild;
    nb.onclick = () => go(scr); ex.appendChild(nb);
  }
  $('#qStory').style.display = navScr.some(n => n[0] === 'story') ? '' : 'none';
  const ps = passState();
  $('#qPass')?.classList.toggle('has-dot', ps.claim > 0);
  home.querySelector('.hEvent')?.classList.toggle('has-dot', !!$('#topbar nav [data-screen="events"].tw-dot'));
  refreshTop();
  if (entering) setTimeout(() => homeSay(greet()), 650);
}

const affLvl = () => R(() => TW.affLevel(TW.st().aff[TW.hero()])) ?? (1 + ((st().aff || 0) / 50 | 0));
// ---------- HUD в игре ----------
function buildHud() {
  const sp = $('#screen-play'); if (!sp || $('#hud')) return;
  addBg(sp);
  const h = mk('div'); h.id = 'hud';
  h.innerHTML = `<div class="hudRow">
      <button class="roundBtn" id="hudHome" title="Главное меню">${ico('home')}</button>
      <div class="hudLv"><small id="hudLvL">Уровень</small><b id="hudLevel">1</b></div>
      <div class="pill hudPairs"><i class="pIco"></i><small>Осталось<br>пар</small><b id="hudPairs">0</b></div>
      <div class="pill hudGems">${ico('gem')}<b class="gemsView"></b></div>
    </div>
    <div class="hudRow">
      <div class="hudCombo"><span class="cLab">Комбо <b id="hudCombo">×0</b></span><div class="cbar"><i id="hudBar"></i><span class="st" style="left:33%"></span><span class="st" style="left:66%"></span><span class="st" style="left:96%"></span></div></div>
      <div class="hudSmall"><button class="roundBtn" id="hudRestart" title="Начать уровень заново">${SVG.RESTART}</button><button class="roundBtn" id="hudSound" title="Звук"></button></div>
    </div>`;
  sp.insertBefore(h, $('#stage'));
  $('#hudHome').onclick = () => go('home');
  $('#hudRestart').onclick = () => { $('#btnRestart')?.click(); };
  $('#hudSound').onclick = () => { $('#btnSound')?.click(); paintSound(); };
  // шкала симпатии с подложкой
  const af = $('#affection'); if (af && !af.querySelector('.affTrack')) af.insertBefore(mk('i', 'affTrack'), af.firstChild);
  $('#heroFrame')?.addEventListener('click', e => {
    burst(e.clientX, e.clientY, { n: 5, sparks: 5, ring: 26 }); hearts(e.clientX, e.clientY - 20, 2);
    R(() => heroReact('react')); emit('heroTap', { where: 'play' });
  });
  // тап по заблокированной фишке — лёгкое «нет»
  $('#board')?.addEventListener('pointerdown', e => {
    const t = e.target.closest('.tile'); if (!t || !t.classList.contains('blocked')) return;
    t.classList.remove('deny'); void t.offsetWidth; t.classList.add('deny');
  });
  if ('ResizeObserver' in window && $('#boardWrap')) new ResizeObserver(() => R(() => fit())).observe($('#boardWrap'));
}
function syncHero() {
  const o = byId(st().equipped?.outfit), f = $('#heroFrame'), img = $('#heroImg'); if (!f || !img) return;
  const cut = CUT[o?.id];
  f.classList.toggle('cut', !!cut);
  if (cut && img.dataset.cut !== cut) { img.dataset.cut = cut; img.dataset.src = cut; img.src = cut; }
  if (!cut) img.dataset.cut = '';
  const bg = st().equipped?.bg, sb = $('#screen-play > .scrBg');
  if (sb) sb.style.backgroundImage = PLAY_BG[bg] || PLAY_BG.b_default;
}
function setBtn(b, icon, label, cost, free, pink) {
  if (!b) return;
  const html = `<span class="cIco">${ico(icon)}<span class="cLbl">${label}</span></span><span class="cCost">${cost}</span>`;
  if (b.dataset.html !== html || !b.firstElementChild?.classList.contains('cIco')) { b.innerHTML = html; b.dataset.html = html; }
  b.classList.add('cBtn'); b.classList.toggle('free', !!free); b.classList.toggle('pinkB', !!pink);
}
function decorateControls() {
  const S_ = st(), h = $('#btnHint'), sh = $('#btnShuffle'), u = $('#btnUndo');
  const hc = R(() => hintCharges), fs = R(() => freeShuffles), un = (R(() => undoStack) || []).length;
  if (h) { const [c, f] = S_.vip ? ['∞', true] : hc > 0 ? ['×' + hc, true] : [ico('gem') + '20', false]; setBtn(h, 'hint', 'Подсказка', c, f); }
  if (u) setBtn(u, 'undo', 'Отмена', '×' + un, true, true);
  if (sh) { const [c, f] = fs > 0 ? ['×' + fs, true] : [ico('gem') + '30', false]; setBtn(sh, 'shuffle', 'Перемешать', c, f); }
}
let comboRaf = 0;
function updateHudNow() {
  const S_ = st(), t = R(() => tiles) || [];
  const set = (id, v) => { const e = document.getElementById(id); if (e && e.textContent !== String(v)) e.textContent = v; };
  const cur = R(() => TW.st().cur);
  set('hudLvL', cur ? 'Глава' : 'Уровень');
  set('hudLevel', cur || S_.level || 1);
  set('hudPairs', t.filter(x => x.alive).length / 2 | 0);
  refreshTop();
  tickCombo();
}
let lastLbl = '';
function tickCombo() {
  const c = R(() => combo) || 0, lm = R(() => lastMatch) || 0, fu = R(() => feverUntil) || 0, now = Date.now();
  const fever = now < fu;
  const left = fever ? (fu - now) / 6000 : c > 0 ? Math.max(0, 1 - (now - lm) / 4000) : 0;
  const bar = $('#hudBar'); if (bar) bar.style.transform = `scaleX(${left.toFixed(3)})`, bar.style.width = '100%';
  const live = left > 0 ? c : 0;
  const lbl = fever ? 'ФИВЕР' : '×' + live;
  const cb = $('#hudCombo');
  if (cb && lbl !== lastLbl) { lastLbl = lbl; cb.textContent = lbl; cb.classList.remove('pulse'); void cb.offsetWidth; cb.classList.add('pulse'); }
  $$('.cbar .st').forEach((s, i) => s.classList.toggle('on', fever || live >= i + 3));
  cancelAnimationFrame(comboRaf);
  if (left > 0) comboRaf = requestAnimationFrame(tickCombo);
}

// ---------- Кристаллы: плавный счётчик ----------
let shownGems = null, gemAnim = 0;
function syncGems() {
  const v = st().gems | 0;
  if (shownGems === null) { shownGems = v; paintGems(v); return; }
  if (v === shownGems) return;
  const from = shownGems, to = v, t0 = performance.now(), dur = Math.min(900, 250 + Math.abs(to - from) * 6);
  shownGems = v; cancelAnimationFrame(gemAnim);
  const delay = to > from && curScreen === 'play' ? 520 : 0; // в игре счёт растёт, когда долетает кристалл
  const step = now => { const k = Math.max(0, Math.min(1, (now - t0 - delay) / dur)), e = 1 - Math.pow(1 - k, 3); paintGems(Math.round(from + (to - from) * e)); if (k < 1) gemAnim = requestAnimationFrame(step); };
  gemAnim = requestAnimationFrame(step);
}
function paintGems(v) { const s = v.toLocaleString('ru-RU'); $$('.gemsView').forEach(e => { if (e.textContent !== s) e.textContent = s; }); }
function gemTarget() { const e = curScreen === 'play' ? $('.hudGems .ui-ico') : $('.wallet .ui-ico'); return e ? center(e) : { x: innerWidth - 40, y: 30 }; }

// ---------- Матчи: призраки фишек, вспышки, комбо, награды ----------
let ready = false, bestCombo = 0, levelBase = null, lastTilesRef = null, dealPending = false, shufPending = false, lastSel = null;
const COMBO_TXT = { 2: 'Хорошо!', 3: 'Отлично!', 4: 'Супер!', 5: 'Невероятно!' };
function ghost(el, to, dir) {
  const r = el.getBoundingClientRect(), w = el.offsetWidth || 48, sc = r.width / w;
  const g = el.cloneNode(true); g.classList.remove('gone', 'sel', 'hint', 'pick', 'deal', 'shuf', 'blocked'); g.classList.add('tileGhost');
  g.removeAttribute('id'); g.onclick = null;
  Object.assign(g.style, { left: r.left + 'px', top: r.top + 'px', width: w + 'px', height: (el.offsetHeight || 62) + 'px', transformOrigin: '0 0', zIndex: 70, animation: 'none', animationDelay: '' });
  document.body.appendChild(g);
  const cx = r.left + r.width / 2, cy = r.top + r.height / 2, dx = to.x - cx, dy = to.y - cy;
  const T = (x, y, s, rot = 0) => `translate(${x}px,${y}px) scale(${s}) translate(${w / 2}px,${(el.offsetHeight || 62) / 2}px) rotate(${rot}deg) translate(${-w / 2}px,${-(el.offsetHeight || 62) / 2}px)`;
  const a = g.animate([
    { transform: T(0, 0, sc), opacity: 1, filter: 'brightness(1)' },
    { transform: T(dx * .1, dy * .1 - 16, sc * 1.14, -dir * 4), opacity: 1, filter: 'brightness(1.08)', offset: .35 },
    { transform: T(dx - dir * (r.width * .3), dy, sc * 1.02, dir * 10), opacity: 1, filter: 'brightness(1.25)', offset: .8 },
    { transform: T(dx - dir * (r.width * .25), dy, sc * 1.35, dir * 4), opacity: 0, filter: 'brightness(1.6)' },
  ], { duration: RM ? 150 : 430, easing: 'cubic-bezier(.3,.7,.3,1)', fill: 'forwards' });
  a.onfinish = () => g.remove();
  setTimeout(() => g.remove(), 900);
  return r;
}
function onPairGone(els) {
  const pts = els.map(e => center(e));
  const mid = pts.length ? { x: pts.reduce((a, p) => a + p.x, 0) / pts.length, y: pts.reduce((a, p) => a + p.y, 0) / pts.length - 10 } : { x: innerWidth / 2, y: innerHeight / 2 };
  els.forEach((e, i) => ghost(e, mid, pts[i].x < mid.x ? -1 : 1));
  if (pts.length >= 2) FX.add({ type: 'beam', x1: pts[0].x, y1: pts[0].y, x2: pts[1].x, y2: pts[1].y, life: .26 });
  const c = R(() => combo) || 1, fever = Date.now() < (R(() => feverUntil) || 0);
  bestCombo = Math.max(bestCombo, c);
  const gain = fever ? 2 : 1;
  setTimeout(() => {
    burst(mid.x, mid.y, { n: 10 + Math.min(c, 6) * 3, sparks: 10 + Math.min(c, 6) * 3, ring: 50 + Math.min(c, 6) * 10, glow: 70, speed: 170 + c * 15 });
    const tgt = gemTarget();
    for (let i = 0; i < gain; i++) flyIcon('art/icons/gem.png', mid, tgt, { s: 26, life: .6, delay: i * .08, trail: '#ffd5f0', done: () => { bumpEl($(curScreen === 'play' ? '.hudGems' : '.wallet .pill')); chime([1568 + i * 200], { vol: .025, dur: .12 }); } });
    // сердечко летит в шкалу симпатии
    const af = $('#affection');
    if (af && curScreen === 'play') { const r = af.getBoundingClientRect(); flyIcon('art/icons/heart.png', mid, { x: r.left + 14, y: r.top + r.height / 2 }, { s: 22, life: .75, delay: .12, trail: '#ffc1d6', done: () => bumpEl(af) }); }
    const f = mk('div', 'gemFloat', `+${gain} ${ico('gem', 'sm')}`); f.style.left = mid.x + 'px'; f.style.top = (mid.y + 6) + 'px'; document.body.appendChild(f); setTimeout(() => f.remove(), 850);
    if (c >= 2) {
      const lv = Math.min(c, 5);
      const p = mk('div', 'comboPop c' + lv, `<small>Комбо ×${c}</small>${COMBO_TXT[lv]}`);
      const fr = frameRect(); p.style.left = Math.max(fr.left + 90, Math.min(fr.left + fr.width - 90, mid.x)) + 'px'; p.style.top = (mid.y - 50) + 'px';
      document.body.appendChild(p); setTimeout(() => p.remove(), 950);
      chime([659 + c * 70, 880 + c * 70], { step: .06, vol: .035, type: 'triangle' });
      emit('combo', { combo: c });
    }
    if (c >= 3) { const hf = $('#heroFrame'); if (hf) { const hr = hf.getBoundingClientRect(); hearts(hr.left + hr.width * .5, hr.top + hr.height * .35, Math.min(c - 1, 4)); } }
    if (c >= 4) { const bw = $('#boardWrap'); bw?.classList.remove('shake'); void bw?.offsetWidth; bw?.classList.add('shake'); }
  }, RM ? 60 : 330);
  emit('match', { combo: c, fever });
  tickCombo();
}
let feverOn = false, emberT = 0;
function checkFever() {
  const on = document.body.classList.contains('fever');
  if (on === feverOn) return; feverOn = on;
  if (on) {
    const b = mk('div', 'feverBanner', '<b>ФИВЕР!</b><small>×2 КРИСТАЛЛЫ</small>'); document.body.appendChild(b); setTimeout(() => b.remove(), 1600);
    chime([523, 659, 784, 1047], { type: 'triangle', vol: .06 });
    const c = center($('#boardWrap') || document.body); burst(c.x, c.y, { n: 20, sparks: 26, ring: 160, glow: 160, speed: 260, spark: '#ffd36a' });
    clearInterval(emberT);
    emberT = setInterval(() => {
      if (!feverOn) return clearInterval(emberT);
      const r = $('#boardWrap')?.getBoundingClientRect(); if (!r) return;
      for (let i = 0; i < 2 * Q; i++) FX.add({ type: 'ember', x: r.left + Math.random() * r.width, y: r.bottom - Math.random() * 20, vy: -60 - Math.random() * 90, s: 1.5 + Math.random() * 2.5, c: Math.random() < .5 ? '#ffb347' : '#ff7a9a', life: 1.6 + Math.random(), ph: Math.random() * 6 });
    }, 160);
    emit('fever', { on: true });
  } else { clearInterval(emberT); emit('fever', { on: false }); }
}
function watchBoard() {
  const board = $('#board'); if (!board) return;
  let pending = [], sched = false;
  new MutationObserver(ms => {
    for (const m of ms) {
      const t = m.target;
      if (m.type !== 'attributes' || !t.classList?.contains('tile')) continue;
      const was = (m.oldValue || '').split(' ');
      if (t.classList.contains('gone') && !was.includes('gone')) pending.push(t);
      if (t.classList.contains('hint') && !was.includes('hint')) { const p = center(t); burst(p.x, p.y, { n: 0, sparks: 8, ring: 40, ringColor: '#8fe3c6', spark: '#d6fff0' }); }
    }
    if (pending.length && !sched) { sched = true; queueMicrotask(() => { sched = false; const els = pending; pending = []; onPairGone(els); }); }
  }).observe(board, { subtree: true, attributes: true, attributeFilter: ['class'], attributeOldValue: true });
  new MutationObserver(checkFever).observe(document.body, { attributes: true, attributeFilter: ['class'] });
}
function levelBanner() {
  const cur = R(() => TW.st().cur), S_ = st();
  const b = mk('div', 'levelBanner', `<span class="rb">${cur ? 'Глава ' + String(cur).replace('-', ' · ') : 'Уровень ' + (S_.level || 1)}</span><small>Найди одинаковые свободные фишки!</small>`);
  document.body.appendChild(b); setTimeout(() => b.remove(), 1800);
  chime([523, 659, 784], { step: .09, vol: .04 });
}
function runDeal() {
  const tilesEls = $$('#board .tile');
  if (!dealPending || !ready || curScreen !== 'play' || RM || !tilesEls.length) return;
  dealPending = false;
  tilesEls.forEach(e => { const x = parseFloat(e.style.left) || 0, y = parseFloat(e.style.top) || 0, z = (parseInt(e.style.zIndex) || 0) / 1000 | 0;
    e.classList.add('deal'); e.style.animationDelay = Math.round(260 + (x + y) * 1.4 + z * 90) + 'ms'; });
  setTimeout(() => tilesEls.forEach(e => { e.classList.remove('deal'); e.style.animationDelay = ''; }), 2400);
  levelBanner();
}
function afterRender() {
  const t = R(() => tiles);
  if (t && t !== lastTilesRef) { // новый расклад: раздача фишек волной + статистика уровня
    lastTilesRef = t; dealPending = true; bestCombo = 0; lastSel = null;
    const S_ = st(); levelBase = { aff: S_.aff || 0, xp: S_.passXP || 0, gems: S_.gems || 0, t: Date.now(), level: S_.level };
  }
  const tilesEls = $$('#board .tile');
  runDeal();
  if (shufPending) {
    shufPending = false;
    tilesEls.forEach((e, i) => { e.classList.add('shuf'); e.style.animationDelay = (i % 12) * 20 + 'ms'; });
    setTimeout(() => tilesEls.forEach(e => { e.classList.remove('shuf'); e.style.animationDelay = ''; }), 900);
    const c = center($('#boardWrap')); burst(c.x, c.y, { n: 18, sparks: 14, ring: 120, speed: 240 }); chime([660, 880, 660, 990], { step: .05, vol: .04 });
  }
  // выбор фишки: подскок и искорки
  const sel = R(() => selected);
  if (sel && sel !== lastSel) { const e = $('#board .tile.sel'); if (e) { e.classList.add('pick'); const p = center(e); burst(p.x, p.y - 6, { n: 0, sparks: 5, ring: 26, ringColor: '#ffe27a', speed: 90 }); } }
  lastSel = sel || null;
  decorateControls(); updateHudNow();
}

// ---------- Бабл героини: всплывает и прячется ----------
let bubT;
function onSay() {
  const b = $('#bubble'); if (!b) return;
  b.classList.remove('show'); void b.offsetWidth; b.classList.add('show'); clearTimeout(bubT); bubT = setTimeout(() => b.classList.remove('show'), 2800);
}

// ---------- Призыв ----------
function decorateGacha() {
  const sc = $('#screen-gacha'), info = $('.bannerInfo'); if (!info || info.dataset.ui) { updatePity(); return; }
  info.dataset.ui = '1';
  const ban = $('.banner');
  const head = mk('div', 'gHead', `<span class="ttl">Призыв</span><span class="rates">SSR 3% · SR 15%</span>`);
  const tabs = mk('div', 'gTabs');
  const feat = $('#bannerImg')?.getAttribute('src') || 'art/keyart.webp';
  tabs.innerHTML = `<button class="gTab on" style="background-image:url('${feat}')"><em>ЛИМИТ</em><span>Лунная ночь</span></button><button class="gTab" style="background-image:url('art/keyart.webp')"><span>Стандарт</span></button>`;
  tabs.children[1].onclick = () => R(() => toast('Стандартный баннер откроется после теста'));
  ban.appendChild(head); ban.appendChild(tabs);
  const h2 = info.querySelector('h2');
  if (h2) { h2.textContent = h2.textContent.replace(/^Баннер\s*/, '').replace(/[«»]/g, ''); h2.insertAdjacentHTML('beforebegin', '<span class="limTag">ЛИМИТИРОВАННЫЙ БАННЕР</span>'); }
  const ps = info.querySelectorAll('p');
  if (ps[0]) ps[0].textContent = ps[0].textContent.replace(/\s*SSR\s*3%.*$/, '');
  const pityP = $('#pity')?.closest('p');
  if (pityP) { const box = mk('div', 'pityBox'); pityP.replaceWith(box); box.innerHTML = `Гарант SSR через <b id="pityUi"></b> призывов<div class="bar"><i id="pityBar"></i></div>`; box.appendChild(pityP); pityP.hidden = true; }
  $('#pull1')?.classList.add('btnLav'); $('#pull10')?.classList.add('btnGold');
  void sc;
  updatePity();
}
function updatePity() {
  const p = st().pity || 0; const a = $('#pityUi'), b = $('#pityBar');
  if (a) a.textContent = 60 - p; if (b) b.style.width = (p / 60 * 100) + '%';
}
let sfToken = 0;
function summonOverlay() {
  let ov = $('#uiSummon');
  if (!ov) { ov = mk('div'); ov.id = 'uiSummon'; document.body.appendChild(ov); }
  return ov;
}
async function runSummon(res) {
  const tok = ++sfToken, n = res.length;
  const best = res.some(r => r.rar === 'SSR') ? 'SSR' : res.some(r => r.rar === 'SR') ? 'SR' : 'R';
  const ov = summonOverlay(); let skip = false, tapR = null;
  ov.innerHTML = `<div class="sfBg"></div><button class="sfSkip">Пропустить ›</button><div class="sfHint"></div>`;
  ov.classList.add('on');
  const fr = () => frameRect();
  const alive = () => tok === sfToken;
  const tap = () => new Promise(r => { tapR = r; });
  ov.onclick = () => { if (tapR) { const r = tapR; tapR = null; r(); } };
  ov.querySelector('.sfSkip').onclick = e => { e.stopPropagation(); skip = true; if (tapR) { const r = tapR; tapR = null; r(); } };
  const sleep = ms => new Promise(r => { const t0 = Date.now(); const iv = setInterval(() => { if (skip || !alive() || Date.now() - t0 >= ms) { clearInterval(iv); r(); } }, 40); });
  const cx = () => fr().left + fr().width / 2;
  // 1. ритуал: падающая звезда цвета лучшей редкости (если anim.js уже показал видео призыва — сразу вспышка)
  const introDone = !!document.getElementById('summonFx');
  if (!skip && !introDone) {
    ov.insertAdjacentHTML('beforeend', `<div class="orb ${best}"></div>`);
    chime([392, 523, 659], { step: .18, dur: .7, vol: .05 });
    await sleep(1100); if (!alive()) return;
    const fl = mk('div', 'flashW' + (best === 'SSR' ? ' gold' : '')); ov.appendChild(fl); setTimeout(() => fl.remove(), 800);
    burst(cx(), innerHeight * .55, { n: 30, sparks: 30, ring: 220, speed: 380, glow: 260, spark: best === 'SSR' ? '#ffe08a' : best === 'SR' ? '#e2c8ff' : '#dfe9ff' });
    ov.querySelector('.orb')?.remove();
  } else if (introDone) {
    const fl = mk('div', 'flashW' + (best === 'SSR' ? ' gold' : '')); ov.appendChild(fl); setTimeout(() => fl.remove(), 800);
  }
  // 2. крупный показ SSR (и SR при одиночном призыве)
  const feature = res.filter(r => r.rar === 'SSR' || (n === 1 && r.rar === 'SR'));
  for (const it of feature) {
    if (skip || !alive()) break;
    const stage = mk('div', 'ssrStage');
    const art = it.img ? `<img src="${it.img}" alt="">` : `<div class="ico" style="${thumbStyle(it)}"></div>`;
    stage.innerHTML = `<div class="rays"></div><div class="art">${art}</div><div class="stamp ${it.rar}">${it.rar}</div><div class="nm">${it.name}</div><div class="sub">${it.hero ? HERO()[it.hero] : (R(() => CAT_NAME[it.cat]) || '')}${it.dup ? ' · повтор → +20 💎' : ' · НОВОЕ!'}</div><div class="stars5">${'★'.repeat(STARS[it.rar])}</div>`;
    iconize(stage);
    ov.appendChild(stage); ov.querySelector('.sfHint').textContent = 'НАЖМИ, ЧТОБЫ ПРОДОЛЖИТЬ';
    if (it.rar === 'SSR') { chime([523, 659, 784, 1047, 1319, 1568], { step: .09, dur: .9, vol: .06, type: 'triangle' }); confetti(60); emit('ssr', { item: it }); }
    else chime([659, 880, 1175], { step: .1, dur: .6, vol: .05 });
    setTimeout(() => burst(cx(), innerHeight * .74, { n: 24, sparks: 26, ring: 160, speed: 300, colors: ['#fff3c4', '#ffd36a', '#ffd5df'] }), 380);
    await Promise.race([tap(), wait(6000)]); if (!alive()) return;
    stage.remove(); ov.querySelector('.sfHint').textContent = '';
  }
  // 3. результаты: героиня-ведущая, лента, сетка карт
  if (!alive()) return;
  ov.querySelector('.sfSkip')?.remove();
  const host = byId(st().equipped?.outfit);
  const box = mk('div', 'resStage');
  box.innerHTML = `<img class="resGirl" src="${CUT[host?.id] || CUT.o_base}" alt=""><div class="resTitle">Результаты призыва</div><div class="resSub">Получено предметов: ${n}</div><div class="resGrid${n === 1 ? ' one' : ''}"></div>
    <div class="resBtns"><button class="btnPink" data-again>Ещё ×${n}<small>${ico('gem', 'sm')} ${n === 10 ? 900 : 100}</small></button><button class="btnGold" data-ok>OK</button></div>`;
  const grid = box.querySelector('.resGrid');
  res.forEach(it => {
    const c = mk('div', 'rCard ' + it.rar);
    const th = it.img ? `<div class="th" style="background-image:url('${it.img}')"></div>` : `<div class="th sw" style="${thumbStyle(it)}"></div>`;
    c.innerHTML = `<div class="in"><div class="b"></div><div class="f"><span class="rb">${it.rar}</span>${th}<div class="nm">${it.name}</div><div class="tg${it.dup ? ' dup' : ''}">${it.dup ? 'повтор +20 💎' : 'НОВОЕ!'}</div></div></div>`;
    c.onclick = e => { e.stopPropagation(); flip(c, it); };
    grid.appendChild(c);
  });
  iconize(box); ov.appendChild(box);
  const flip = (c, it) => {
    if (c.classList.contains('flip')) return; c.classList.add('flip');
    const p = center(c);
    chime([it.rar === 'SSR' ? 1319 : it.rar === 'SR' ? 988 : 784], { vol: .035, dur: .2 });
    if (it.rar !== 'R') burst(p.x, p.y, { n: it.rar === 'SSR' ? 18 : 8, sparks: it.rar === 'SSR' ? 22 : 10, ring: it.rar === 'SSR' ? 90 : 56, spark: it.rar === 'SSR' ? '#ffe08a' : '#e2c8ff', glow: it.rar === 'SSR' ? 120 : 0 });
  };
  box.querySelector('[data-ok]').onclick = e => { e.stopPropagation(); closeSummon(); };
  box.querySelector('[data-again]').onclick = e => { e.stopPropagation(); closeSummon(); setTimeout(() => $(n === 10 ? '#pull10' : '#pull1')?.click(), 120); };
  const cards = [...grid.children];
  for (let i = 0; i < cards.length; i++) {
    if (!alive()) return;
    if (!skip) await wait(i === 0 ? 420 : 120);
    flip(cards[i], res[i]);
  }
}
// Результаты призыва читаем из DOM (#pullResult), поэтому порядок обёрток showPull в других модулях не важен.
function watchPulls() {
  const box = $('#pullResult'); if (!box) return;
  let sched = false;
  new MutationObserver(() => {
    if (sched) return; sched = true;
    queueMicrotask(() => {
      sched = false;
      const cards = [...box.querySelectorAll('.card')]; if (!cards.length) return;
      const byName = Object.fromEntries(ALL().map(i => [i.name, i]));
      const res = cards.map(c => {
        const rar = (c.className.match(/r-(SSR|SR|R)/) || [])[1] || 'R';
        const front = c.querySelector('.cardFront');
        const name = [...(front?.children || [])].find(d => d.tagName === 'DIV' && !d.className)?.textContent.trim() || '';
        const it = byName[name] || { name, rar };
        return { ...it, rar, dup: /повтор/.test(front?.querySelector('.dup')?.textContent || '') };
      });
      runSummon(res);
    });
  }).observe(box, { childList: true });
}
function closeSummon() {
  sfToken++; const ov = $('#uiSummon'); if (!ov) return;
  ov.classList.remove('on'); ov.innerHTML = '';
}

// ---------- Гардероб: сцена сверху, вкладки справа, сетка снизу ----------
let wTab = 'outfit', wHero = 'all', lastStageOutfit = null;
function enhanceWardrobe() {
  const box = $('#wardrobe'), sc = $('#screen-wardrobe'); if (!box || !sc) return;
  let stage = $('#wStage');
  if (!stage) {
    addBg(sc);
    stage = mk('div'); stage.id = 'wStage';
    const sheet = mk('div', 'wSheet'); sheet.innerHTML = '<div class="wHead"><b id="wHeadT">Наряды</b><small id="wHeadC"></small></div>';
    const hs = mk('div', 'wHeroes'); hs.id = 'wHeroes';
    sc.insertBefore(stage, box); sc.insertBefore(sheet, box); sheet.appendChild(hs); sheet.appendChild(box);
  }
  const S_ = st(), H = HERO(), cats = R(() => CAT_NAME) || { outfit: 'Наряды', skin: 'Фишки', bg: 'Фоны' };
  const catByName = Object.fromEntries(Object.entries(cats).map(([k, v]) => [v, k]));
  const lists = {}, idx = {};
  let cat = null, delay = 0;
  for (const c of [...box.children]) {
    if (c.classList.contains('wCat')) { const t = c.textContent.trim(); if (catByName[t]) cat = catByName[t]; continue; }
    if (!c.classList.contains('wItem') || !cat) continue;
    lists[cat] = lists[cat] || ALL().filter(i => i.cat === cat); idx[cat] = idx[cat] || 0;
    const it = lists[cat][idx[cat]++]; c.dataset.cat = cat;
    if (!it) continue;
    c.dataset.id = it.id; c.dataset.hero = it.hero || ''; c.classList.add('r-' + it.rar);
    const own = !!S_.owned?.[it.id];
    if (!it.img) { const ic = c.querySelector('.ico'); if (ic) { const sw = mk('i', 'sw'); sw.setAttribute('style', thumbStyle(it)); ic.replaceWith(sw); } }
    c.insertAdjacentHTML('afterbegin', `<span class="wStars">${'★'.repeat(STARS[it.rar] || 3)}</span>`);
    if (!own) c.addEventListener('click', () => R(() => toast(`«${it.name}» можно получить в призыве`)));
    c.style.animationDelay = Math.min(delay++ * 22, 400) + 'ms';
  }
  const o = byId(S_.equipped?.outfit);
  const cnt = c => { const l = ALL().filter(i => i.cat === c); return `${l.filter(i => S_.owned?.[i.id]).length}/${l.length}`; };
  stage.innerHTML = `<div class="stageArt${isCut(o) ? ' cut' : ''}"><img src="${outfitArt(o)}" alt=""></div>
    <div class="info"><div class="aff"><b>${affLvl()}</b>Симпатия</div><div class="who">${H[o?.hero] || ''}</div><div class="what">${o?.name || ''}</div><div class="stars">${'★'.repeat(STARS[o?.rar] || 3)}</div></div>
    <div class="wTabs"><button data-t="outfit">${ico('wardrobe')}Наряды<small>${cnt('outfit')}</small></button><button data-t="skin">${TILE_ICO}Фишки<small>${cnt('skin')}</small></button><button data-t="bg">${ico('star')}Фоны<small>${cnt('bg')}</small></button></div>`;
  if (lastStageOutfit && lastStageOutfit !== o?.id) {
    stage.querySelector('.stageArt').classList.add('pop'); const p = center(stage.querySelector('.stageArt'));
    setTimeout(() => { burst(p.x, p.y, { n: 16, sparks: 16, ring: 90, glow: 120 }); hearts(p.x, p.y - 40, 3); }, 60); chime([784, 988, 1319], { vol: .04 });
  }
  lastStageOutfit = o?.id;
  stage.querySelectorAll('.wTabs button').forEach(bt => bt.onclick = () => { wTab = bt.dataset.t; filterWardrobe(); });
  const outfits = ALL().filter(i => i.cat === 'outfit');
  const hs = $('#wHeroes');
  const heroesIn = [...new Set(outfits.map(i => i.hero))];
  hs.innerHTML = `<button data-h="all">Все</button>` + heroesIn.map(h => `<button data-h="${h}">${H[h] || h}</button>`).join('');
  hs.querySelectorAll('button').forEach(bt => bt.onclick = () => { wHero = bt.dataset.h; filterWardrobe(); });
  filterWardrobe();
}
function filterWardrobe() {
  $$('#wardrobe .wItem').forEach(c => { c.hidden = (c.dataset.cat && c.dataset.cat !== wTab) || (wTab === 'outfit' && wHero !== 'all' && c.dataset.hero !== wHero); });
  $$('#wStage .wTabs button').forEach(b => b.classList.toggle('on', b.dataset.t === wTab));
  const names = { outfit: 'Наряды', skin: 'Фишки', bg: 'Фоны' };
  const S_ = st(), l = ALL().filter(i => i.cat === wTab);
  const t = $('#wHeadT'); if (t) t.textContent = names[wTab];
  const c = $('#wHeadC'); if (c) c.textContent = `собрано ${l.filter(i => S_.owned?.[i.id]).length} из ${l.length}`;
  const hs = $('#wHeroes'); if (hs) { hs.style.display = wTab === 'outfit' ? '' : 'none'; hs.querySelectorAll('button').forEach(b => b.classList.toggle('on', b.dataset.h === wHero)); }
}

// ---------- Пропуск и VIP ----------
function enhancePass() {
  const sc = $('#screen-pass'); if (!sc) return;
  let head = $('#passHead');
  if (!head) {
    addBg(sc);
    head = mk('div'); head.id = 'passHead';
    const t = sc.querySelector('h2')?.textContent || 'Сезон «Неоновая ночь»';
    head.innerHTML = `<span class="evTag">СОБЫТИЕ · NEON NIGHT</span><h3>${t}</h3><div class="tierRow"><div class="tierNum"><span id="phTier">0</span></div><div class="xp"><div class="bar"><i id="phBar"></i></div><small id="phTxt"></small></div></div>`;
    sc.insertBefore(head, $('#passInfo') || sc.firstChild);
    const vip = sc.querySelector('.vipCard');
    if (vip && !vip.querySelector('.vipPerks')) vip.insertBefore(mk('div', 'vipPerks', `<div>${ico('hint')}Подсказки без лимита</div><div>${ico('gem')}+100 каждый день</div><div>${ico('star')}Золотая рамка героини</div>`), $('#vipBtn'));
    $('#passPremBtn')?.classList.add('btnGold'); $('#vipBtn')?.classList.add('btnPink');
  }
  const ps = passState();
  $('#phTier').textContent = ps.tier;
  $('#phBar').style.width = (ps.tier >= 10 ? 100 : (ps.xp % ps.step) / ps.step * 100) + '%';
  $('#phTxt').textContent = ps.tier >= 10 ? 'Сезон пройден полностью!' : `${ps.xp % ps.step}/${ps.step} очков до уровня ${ps.tier + 1} · 1 за пару, 10 за победу`;
  const track = $('#passTrack'), P = R(() => PASS);
  if (!track) return;
  if (!track.querySelector('.pLegend')) track.prepend(mk('div', 'pLegend', `<div></div><div>${ico('gift')}Бесплатно</div><div class="prem">${ico('trophy')}Премиум</div>`));
  if (P) [...track.querySelectorAll('.pTier')].forEach((col, i) => {
    const cells = col.querySelectorAll('.pCell');
    [P[i]?.free, P[i]?.prem].forEach((r, j) => {
      const c = cells[j]; if (!c || !r) return;
      const status = c.querySelector('small')?.textContent || '';
      const body = r.item ? `<i class="pth" style="${thumbStyle(byId(r.item))}"></i><span>${byId(r.item)?.name || ''}</span>` : `<span class="pg">${ico('gem')}${r.gems}</span>`;
      c.innerHTML = body + (status ? `<small>${status}</small>` : '');
    });
  });
  iconize(sc);
  const firstClaim = track.querySelector('.pCell:not(:disabled)');
  if (firstClaim) { const col = firstClaim.closest('.pTier'); if (col) track.scrollTo({ left: Math.max(0, col.offsetLeft - 80), behavior: 'smooth' }); }
}

// ---------- Победа / поражение ----------
const fmtTime = s => `${String(s / 60 | 0).padStart(2, '0')}:${String(s % 60 | 0).padStart(2, '0')}`;
function showWin() {
  const m = $('#winModal'); if (!m) return;
  const card = m.querySelector('.modalCard'); if (!card) return;
  const S_ = st(), base = levelBase || { aff: S_.aff, xp: S_.passXP, gems: S_.gems, t: Date.now() };
  const txt = $('#winText')?.textContent || '';
  const stars = (txt.match(/★/g) || []).length || 1;
  const secs = (Date.now() - base.t) / 1000;
  const o = byId(S_.equipped?.outfit);
  let x = card.querySelector('.winX');
  if (!x) {
    x = mk('div', 'winX'); x.style.cssText = 'display:contents';
    x.innerHTML = `<img class="winGirl" alt=""><div class="winBody"><div class="winTitle">Победа!</div><div class="winStars"><i></i><i></i><i></i></div><div class="winLab" id="winLab"></div>
      <div class="winRow" id="winR1"></div><div class="winRow two" id="winR2"></div><div class="winBtns"><button class="btnMint" id="winHome">Домой</button></div></div>`;
    card.appendChild(x);
    const next = $('#btnNext'); if (next) { next.classList.add('btnPink'); x.querySelector('.winBtns').appendChild(next); }
    x.querySelector('#winHome').onclick = () => { $('#btnNext')?.click(); setTimeout(() => go('home'), 30); };
  }
  const next = $('#btnNext'); if (next) next.textContent = 'Далее ›';
  const mapB = $('#twMapBtn'), btns = x.querySelector('.winBtns');
  if (mapB) { if (mapB.parentNode !== btns) { mapB.className = 'btnMint'; btns.prepend(mapB); } x.querySelector('#winHome').style.display = 'none'; }
  const g = x.querySelector('.winGirl'); g.src = outfitArt(o); g.classList.toggle('framed', !isCut(o));
  g.style.animation = 'none'; void g.offsetWidth; g.style.animation = '';
  const cur = R(() => TW.st().cur);
  $('#winLab').textContent = cur ? 'Сцена пройдена' : `Уровень ${base.level || ''} пройден`;
  $('#winR1').innerHTML = `<div>${ico('gem')}<small>Кристаллы</small><b>+${Math.max(0, (S_.gems || 0) - (base.gems || 0))}</b></div>
    <div>${ico('heart')}<small>Симпатия</small><b>+${Math.max(0, (S_.aff || 0) - (base.aff || 0))}</b></div>
    <div>${ico('ticket')}<small>Пропуск</small><b>+${Math.max(0, (S_.passXP || 0) - (base.xp || 0))}</b></div>`;
  $('#winR2').innerHTML = `<div>${ico('calendar')}<small>Время</small><b>${fmtTime(secs)}</b></div><div>${SVG.FLAME.replace('ui-svg', 'ui-ico')}<small>Лучшее комбо</small><b>×${Math.max(1, bestCombo)}</b></div>`;
  const si = x.querySelectorAll('.winStars i'); si.forEach(i => i.classList.remove('on'));
  confetti(130);
  chime([523, 659, 784, 1047], { step: .12, dur: .6, vol: .06, type: 'triangle' });
  [0, 1, 2].slice(0, stars).forEach(k => setTimeout(() => {
    si[k].classList.add('on'); const p = center(si[k]);
    burst(p.x, p.y, { n: 10, sparks: 16, ring: 60, glow: 80, spark: '#ffe08a' }); chime([880 + k * 220], { vol: .05, dur: .3 });
  }, 650 + k * 380));
  // кристаллы из строки наград летят в счётчик
  setTimeout(() => { const from = $('#winR1 .ui-ico'); if (!from) return; const a = center(from); for (let i = 0; i < 6; i++) flyIcon('art/icons/gem.png', a, { x: a.x, y: a.y - 4 }, { s: 22, life: .7, delay: i * .06 }); }, 1700);
  emit('win', { stars, secs });
}
UI.showResult = function (o = {}) {
  if (o.type === 'win' && !o.title) return showWin();
  let m = $('#uiResult');
  if (!m) { m = mk('div', 'modal'); m.id = 'uiResult'; document.body.appendChild(m); }
  const lose = o.type === 'lose';
  m.innerHTML = `<div class="modalCard ${lose ? 'loseCard' : ''}" style="max-width:360px;width:calc(100% - 40px);padding:26px 18px 20px;text-align:center;display:flex;flex-direction:column;align-items:center;gap:12px">
    <div class="winTitle">${o.title || (lose ? 'Не вышло…' : 'Победа!')}</div>
    ${o.heroLine ? `<p style="margin:0;font-weight:800">${o.heroLine}</p>` : ''}
    <p style="margin:0;font-weight:700">${o.text || (lose ? 'Ходы закончились. Попробуем ещё раз?' : '')}</p>
    <div class="winBtns"><button class="btnMint" data-home>Домой</button><button class="btnPink" data-retry>${lose ? 'Ещё раз' : 'Далее ›'}</button></div></div>`;
  iconize(m);
  m.classList.remove('hidden'); m.style.display = 'flex';
  const close = () => { m.style.display = 'none'; };
  m.querySelector('[data-home]').onclick = () => { close(); (o.onHome || (() => go('home')))(); };
  m.querySelector('[data-retry]').onclick = () => { close(); (o.onRetry || (() => $('#btnRestart')?.click()))(); };
  if (!lose) confetti(100); else chime([392, 330, 262], { step: .16, dur: .5, vol: .05 });
  emit(lose ? 'lose' : 'win', o);
};

// ---------- Рипл на кнопках ----------
document.addEventListener('pointerdown', e => {
  const b = e.target.closest('.hBtn,.btnPink,.btnMint,.btnLav,.btnGold'); if (!b) return;
  const r = b.getBoundingClientRect(), s = Math.max(r.width, r.height) * 2;
  const rp = mk('span', 'ripple'); rp.style.cssText = `width:${s}px;height:${s}px;left:${e.clientX - r.left - s / 2}px;top:${e.clientY - r.top - s / 2}px`;
  b.appendChild(rp); setTimeout(() => rp.remove(), 550);
}, { passive: true });

function paintDots() {
  const ps = passState();
  const t = $('#tabbar .tab[data-go="pass"]'); if (t) t.classList.toggle('has-dot', ps.claim > 0);
  const ev = $('#tabbar .tab[data-go="events"]'); if (ev) ev.classList.toggle('has-dot', !!$('#topbar nav [data-screen="events"].tw-dot'));
  const g = $('#tabbar .tab[data-go="gacha"]'); if (g) g.classList.toggle('has-dot', (st().gems || 0) >= 900);
}

// ---------- Подключение ----------
function init() {
  buildTopbar(); buildHome(); buildHud(); buildTabs();
  wrap('render', afterRender);
  wrap('shuffleBoard', null, () => { shufPending = true; });
  wrap('updateHud', () => { syncGems(); updatePity(); if (curScreen === 'home') refreshHome(); paintDots(); updateHudNow(); });
  wrap('say', onSay);
  wrap('win', () => setTimeout(showWin, 30));
  watchPulls();
  wrap('renderWardrobe', enhanceWardrobe);
  wrap('renderPass', () => { enhancePass(); paintDots(); });
  wrap('applyEquip', () => { syncHero(); if (curScreen === 'home') refreshHome(); });
  watchBoard();
  new MutationObserver(ms => { if (ms.some(m => m.target.classList?.contains('screen'))) syncScreen(); })
    .observe($('#app'), { subtree: true, attributes: true, attributeFilter: ['class'] });
  const nav = $('#topbar nav'); if (nav) new MutationObserver(() => buildTabs()).observe(nav, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] });
  // иконки вместо эмодзи: сразу и для всего, что появится позже
  iconize(document.body);
  new MutationObserver(ms => {
    for (const m of ms) {
      if (m.type === 'characterData') iconize(m.target);
      else m.addedNodes.forEach(n => iconize(n));
    }
  }).observe(document.body, { subtree: true, childList: true, characterData: true });
  new MutationObserver(() => syncGems()).observe($('#gems'), { childList: true, characterData: true, subtree: true });
  $('#btnSound')?.addEventListener('click', () => setTimeout(paintSound, 0));
  syncHero(); syncGems(); paintSound(); decorateControls(); afterRender(); paintDots();
  const start = new URLSearchParams(location.search).get('screen');
  go(start && $('#screen-' + start) ? start : 'home');
  ready = true; syncScreen(true);
  document.documentElement.classList.add('ui-ready');
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
