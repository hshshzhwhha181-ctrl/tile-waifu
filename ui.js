// ui.js — премиальный интерфейс и эффекты Tile Waifu.
// Подключается ПОСЛЕДНИМ. Логику игры не меняет: оборачивает глобальные функции game.js
// (render, win, showPull, renderWardrobe, renderPass, updateHud, say, shuffleBoard) и следит за DOM.
// Публичный API: window.UI.go(screen), UI.burst(x,y), UI.confetti(), UI.showResult({type:'win'|'lose',...}).
'use strict';
(function () {
const UI = window.UI = window.UI || {};
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const R = f => { try { return f(); } catch { return undefined; } };
const mk = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
const RM = matchMedia('(prefers-reduced-motion: reduce)').matches;
const Q = RM ? 0.25 : 1;
const mobile = () => innerWidth < 900;
const emit = (n, d) => document.dispatchEvent(new CustomEvent('ui:' + n, { detail: d }));
const wait = ms => new Promise(r => setTimeout(r, ms));
const ico = (n, cls = '') => `<img class="ui-ico ${cls}" src="art/icons/${n}.png" alt="" draggable="false">`;
const SVG = {
  LOCK: '<svg class="ui-svg" viewBox="0 0 24 24"><path d="M7 10V7a5 5 0 0110 0v3" fill="none" stroke="#d4a24c" stroke-width="2.4"/><rect x="4.5" y="10" width="15" height="11" rx="2.5" fill="#d4a24c"/><circle cx="12" cy="15.5" r="1.8" fill="#2a2428"/></svg>',
  FLAME: '<svg class="ui-svg" viewBox="0 0 24 24"><path d="M12 2c1 4 5.5 6 5.5 11.5a5.5 5.5 0 01-11 0c0-2.3 1.2-4 2.3-5 0 2.2 1 3.2 2.2 3.3C10 8.5 11 5.5 12 2z" fill="#ff8a3c"/><path d="M12 12c.5 2 2.6 2.8 2.6 5a2.6 2.6 0 01-5.2 0c0-1.2.6-2 1.2-2.6.2 1 .8 1.4 1.4 1.4-.4-1.3-.4-2.6 0-3.8z" fill="#ffd36a"/></svg>',
  RESTART: '<svg class="ui-svg" viewBox="0 0 24 24"><path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/><path d="M19.5 4v4.8h-4.8" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
};

// ---------- Доступ к состоянию игры (только чтение) ----------
const st = () => R(() => S) || {};
const ALL = () => R(() => ITEMS) || [];
const byId = id => R(() => ITEM[id]);
const HERO = () => R(() => HEROES) || {};
const CUT = { o_base: 'art/ui/mc_cut.webp' }; // вырезки без фона
const STARS = { R: 3, SR: 4, SSR: 5 };
const BG_SW = {
  b_default: 'linear-gradient(160deg,#fff 0,#f3ece8 45%,#e2d4d0 100%)',
  b_tea: 'linear-gradient(160deg,#fff 0,#e6f2e3 50%,#cfe6d2 100%)',
  b_beach: 'linear-gradient(180deg,#bfe9ff 0,#e9f8ff 55%,#ffe6b5 100%)',
  b_neon: "url('art/bg_neon.webp') center/cover",
  b_night: 'radial-gradient(circle at 20% 10%,#3b2f66 0,#1e1a33 70%)',
};
function thumbStyle(it) {
  if (!it) return '';
  if (it.img) return `background-image:url('${it.img}')`;
  if (it.cat === 'skin') return `background:url('art/tiles/${it.id === 's_neon' ? 'neon' : 'ivory'}/00_sakura.png') center/72% no-repeat,${it.tile || '#fffaf0'};box-shadow:inset 0 0 0 3px ${it.back || '#ff9cc2'},inset 0 -6px 0 #0001`;
  if (it.cat === 'bg') return `background:${BG_SW[it.id] || '#ddd'}`;
  return '';
}
const outfitArt = it => (it && (CUT[it.id] || it.img)) || 'art/mc_base.webp';

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
const SKIP_SEL = '#board,[data-noicon],script,style,textarea,input,#fx';
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
  const parts = node.data.split(new RegExp(EMO_SRC, 'u'));
  if (parts.length < 2) return;
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

// ---------- Движок частиц (canvas поверх всего, работает только пока есть частицы) ----------
const FX = (() => {
  const cv = mk('canvas'); cv.id = 'fx'; document.body.appendChild(cv);
  const ctx = cv.getContext('2d'); let W = 0, H = 0; const P = []; let raf = 0, last = 0;
  const imgs = {};
  function size() { const d = Math.min(2, devicePixelRatio || 1); W = innerWidth; H = innerHeight; cv.width = W * d; cv.height = H * d; ctx.setTransform(d, 0, 0, d, 0, 0); }
  size(); addEventListener('resize', size);
  const img = src => imgs[src] || (imgs[src] = Object.assign(new Image(), { src }));
  const eo = k => 1 - (1 - k) * (1 - k);
  const eio = k => k < .5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
  function add(p) { if (P.length > 800 || document.hidden) return; p.t = 0; P.push(p); if (!raf) { last = performance.now(); raf = requestAnimationFrame(loop); } }
  function star(x, y, s, c, a) {
    ctx.globalAlpha = a; ctx.fillStyle = c; ctx.beginPath(); ctx.moveTo(x, y - s);
    ctx.quadraticCurveTo(x, y, x + s, y); ctx.quadraticCurveTo(x, y, x, y + s); ctx.quadraticCurveTo(x, y, x - s, y); ctx.quadraticCurveTo(x, y, x, y - s); ctx.fill();
  }
  function loop(now) {
    const dt = Math.min(.05, (now - last) / 1000); last = now; ctx.clearRect(0, 0, W, H);
    for (let i = P.length - 1; i >= 0; i--) {
      const p = P[i]; p.t += dt;
      if (p.t >= p.life) { P.splice(i, 1); if (p.done) p.done(); continue; }
      if (p.t < 0) continue;
      const k = p.t / p.life; ctx.save();
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
          ctx.strokeStyle = g; ctx.shadowColor = '#f3d08a'; ctx.shadowBlur = 18; ctx.lineWidth = 7 * (1 - k) + 1;
          ctx.beginPath(); ctx.moveTo(p.x1, p.y1); ctx.lineTo(p.x2, p.y2); ctx.stroke(); break;
        }
        case 'fly': {
          const e = eio(k), u = 1 - e; const x = u * u * p.x0 + 2 * u * e * p.cx + e * e * p.x1, y = u * u * p.y0 + 2 * u * e * p.cy + e * e * p.y1;
          const im = img(p.src); const s = p.s * (1 - .35 * k);
          if (im.complete && im.naturalWidth) { ctx.globalAlpha = k < .1 ? k * 10 : 1; ctx.drawImage(im, x - s / 2, y - s / 2, s, s); }
          if (Math.random() < .5) add({ type: 'spark', x, y, vx: 0, vy: 0, s: 3, c: p.trail || '#ffd5df', life: .3, ph: 0 });
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
      }
      ctx.restore();
    }
    raf = P.length ? requestAnimationFrame(loop) : 0;
    if (!raf) ctx.clearRect(0, 0, W, H);
  }
  return { add, img, clear() { P.length = 0; } };
})();
UI.fx = FX;

const PETALS = ['#ffd5df', '#f7b6c6', '#fff2d6', '#e7aebb', '#ffe9ee'];
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
  if (o.ring !== 0) FX.add({ type: 'ring', x, y, r0: 6, r1: o.ring || 48, w: 3.5, c: o.ringColor || '#f3d08a', life: .5 });
  if (o.glow) FX.add({ type: 'glow', x, y, r: o.glow, c: o.glowColor || 'rgba(255,240,200,.9)', life: .5 });
}
function confetti(n = 120, y0 = -20) {
  const cols = ['#f3d08a', '#e7aebb', '#c9798d', '#fffaf2', '#9bd6c1', '#ffd36a'];
  for (let i = 0; i < n * Q; i++) FX.add({ type: 'confetti', x: Math.random() * innerWidth, y: y0 - Math.random() * 200, vx: (Math.random() - .5) * 120, vy: 40 + Math.random() * 120,
    rot: Math.random() * 6, vr: (Math.random() - .5) * 10, s: 4 + Math.random() * 4, c: cols[i % cols.length], round: Math.random() < .35, life: 2.6 + Math.random() * 1.6, ph: Math.random() * 6 });
}
function flyIcon(src, from, to, o = {}) {
  const x0 = from.x, y0 = from.y, x1 = to.x, y1 = to.y;
  FX.add({ type: 'fly', src, x0, y0, x1, y1, cx: (x0 + x1) / 2 + (Math.random() - .5) * 120, cy: Math.min(y0, y1) - 80 - Math.random() * 60, s: o.s || 26, life: o.life || .75, trail: o.trail, done: o.done });
}
const center = e => { const r = e.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2, r }; };
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

// ---------- Фоновые сцены, лепестки, шторка переходов ----------
const bg = mk('div'); bg.id = 'uiBg';
bg.innerHTML = '<i class="bgMenu"></i><i class="bgTable"></i><i class="bgSummon"></i><i class="bgSoft"></i><i class="bgPass"></i>';
document.body.prepend(bg);
const BG_FOR = { home: 'bgMenu', play: 'bgTable', gacha: 'bgSummon', wardrobe: 'bgSoft', pass: 'bgPass' };
const petals = mk('div'); petals.id = 'petalLayer';
for (let i = 0; i < (RM ? 0 : 12); i++) {
  const b = mk('b'); b.style.left = Math.random() * 100 + '%'; b.style.animationDuration = 9 + Math.random() * 9 + 's'; b.style.animationDelay = -Math.random() * 18 + 's';
  b.style.setProperty('--dx', (Math.random() * 160 - 40) + 'px'); b.style.transform = `scale(${.6 + Math.random() * .7})`; petals.appendChild(b);
}
document.body.prepend(petals);
const wipeEl = mk('div'); wipeEl.id = 'screenWipe'; document.body.appendChild(wipeEl);
const feverFx = mk('div'); feverFx.id = 'feverFx'; document.body.appendChild(feverFx);
function wipe(ev) {
  if (ev && ev.clientX != null) { wipeEl.style.setProperty('--wx', ev.clientX + 'px'); wipeEl.style.setProperty('--wy', ev.clientY + 'px'); }
  wipeEl.classList.remove('go'); void wipeEl.offsetWidth; wipeEl.classList.add('go');
}

// ---------- Верхняя панель ----------
function buildTopbar() {
  const tb = $('#topbar'); if (!tb) return;
  const br = tb.querySelector('.brand');
  if (br) br.innerHTML = '<i class="ava"></i><span class="bTxt"><b class="goldText">Tile Waifu</b><small id="tbLevel"></small></span>';
  const w = tb.querySelector('.wallet'), gems = $('#gems');
  if (w && gems) {
    w.textContent = '';
    w.insertAdjacentHTML('beforeend', ico('gem'));
    w.appendChild(gems);
    w.appendChild(mk('b', 'gemsView'));
    const plus = mk('button', 'plus', '+'); plus.title = 'Пропуск и подарки'; plus.onclick = e => go('pass', e); w.appendChild(plus);
  }
  const snd = mk('button', 'topBtn'); snd.id = 'topSound'; snd.title = 'Звук';
  snd.onclick = () => { $('#btnSound')?.click(); paintSound(); };
  tb.insertBefore(snd, tb.querySelector('nav'));
  paintSound();
}
function paintSound() {
  const on = st().sound !== false;
  const t = $('#topSound'); if (t) t.innerHTML = ico('sound', on ? '' : 'muted');
  const b = $('#btnSound'); if (b) { b.innerHTML = ico('sound', on ? '' : 'muted'); b.title = on ? 'Звук включён' : 'Звук выключен'; }
}

// ---------- Навигация: таб-бар строится из кнопок nav, плюс «Главная» ----------
const TAB_META = { home: ['Главная', 'home'], play: ['Играть', 'TILE'], gacha: ['Призыв', 'gem'], wardrobe: ['Гардероб', 'wardrobe'], pass: ['Пропуск', 'ticket'],
  story: ['Сюжет', 'mail'], events: ['События', 'gift'], chapters: ['Главы', 'mail'], map: ['Карта', 'calendar'], heroes: ['Героини', 'heart'], shop: ['Магазин', 'gift'] };
function buildTabs() {
  let tb = $('#tabbar');
  if (!tb) { tb = mk('div'); tb.id = 'tabbar'; tb.setAttribute('role', 'navigation'); $('#topbar')?.appendChild(tb); }
  const list = [['home', 'Главная']].concat($$('#topbar nav button[data-screen]').map(b => [b.dataset.screen, b.textContent.trim()]));
  tb.innerHTML = '';
  for (const [scr, label] of list) {
    const m = TAB_META[scr];
    const b = mk('button', 'tab'); b.dataset.go = scr;
    const icon = !m ? ico('star') : m[1] === 'TILE' ? '<img class="ui-ico" src="art/tiles/ivory/00_sakura.png" alt="">' : ico(m[1]);
    b.innerHTML = `${icon}<span>${m ? m[0] : label}</span><i class="dot"></i>`;
    b.onclick = e => go(scr, e);
    tb.appendChild(b);
  }
  // на телефоне в таб-баре максимум 5 вкладок, остальные экраны доступны из главного меню
  const prio = ['home', 'story', 'play', 'gacha', 'wardrobe', 'pass', 'events', 'heroes'];
  const tabs = [...tb.children].sort((a, b) => (prio.indexOf(a.dataset.go) + 1 || 99) - (prio.indexOf(b.dataset.go) + 1 || 99));
  tabs.forEach((t, i) => { t.classList.toggle('extra', i >= 5); tb.appendChild(t); });
  syncScreen(true);
}
const activeScreen = () => ($('.screen.active')?.id || '').replace('screen-', '');
function go(name, ev) {
  if (name === activeScreen()) return;
  if (ev) wipe(ev);
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
  curScreen = s;
  document.documentElement.dataset.screen = s;
  $$('#tabbar .tab').forEach(t => t.classList.toggle('active', t.dataset.go === s));
  const layer = BG_FOR[s] || 'bgSoft';
  $$('#uiBg i').forEach(i => i.classList.toggle('on', i.classList.contains(layer)));
  if (s === 'home') refreshHome(true);
  if (s === 'play') requestAnimationFrame(() => { R(() => fit()); updateHudNow(); });
  if (s === 'gacha') decorateGacha();
  scrollTo(0, 0);
  emit('screen', { screen: s });
}

// ---------- Главное меню ----------
const HOME_LINES = ['С возвращением! Сыграем партию?', 'Я соскучилась~ Давай ещё уровень!', 'Задание дня уже ждёт тебя.', 'На баннере новая героиня… посмотрим?',
  'Хи-хи, не смотри так пристально~', 'Собери пару и получи кристаллы!', 'Сегодня отличный день для маджонга.'];
function greet() { const h = new Date().getHours(); return h < 6 ? 'Не спится? Я тоже… Сыграем тихонько?' : h < 12 ? 'Доброе утро! Чай уже заварен~' : h < 18 ? 'Добрый день! Готов к новой партии?' : 'Добрый вечер~ Фонари уже зажглись.'; }
let bubbleT;
function homeSay(t) {
  const b = $('.homeBubble'); if (!b) return;
  b.textContent = t; b.classList.add('show'); clearTimeout(bubbleT); bubbleT = setTimeout(() => b.classList.remove('show'), 3800);
}
function buildHome() {
  if ($('#screen-home')) return;
  const s = mk('section', 'screen'); s.id = 'screen-home';
  s.innerHTML = `
    <img class="homeGirl" alt="">
    <div class="homeBubble"></div>
    <div class="homeCol">
      <div class="homeLogo"><img src="art/ui/logo_gold.webp" alt="Tile Waifu"><small>АНИМЕ МАДЖОНГ · ГАЧА</small></div>
      <button class="hBtn hPlay" data-go="play"><i class="tileChip"></i><span class="hTxt"><b>Играть</b><small id="hLevel"></small></span><span class="chev">›</span></button>
      <button class="hBtn" data-go="play" id="hQuest"><span class="hIco">${ico('calendar')}</span><span class="hTxt">Задание дня<small id="hQuestTxt"></small><span class="mini"><i id="hQuestBar"></i></span></span><span class="chev">›</span></button>
      <button class="hBtn" data-go="gacha"><span class="hIco">${ico('gem')}</span><span class="hTxt">Призыв<small>Королева лунной ночи · SSR 3%</small></span><span class="chev">›</span></button>
      <button class="hBtn" data-go="wardrobe"><span class="hIco">${ico('wardrobe')}</span><span class="hTxt">Гардероб<small id="hWard"></small></span><span class="chev">›</span></button>
      <button class="hBtn hEvent" data-go="pass"><span class="hIco">${ico('ticket')}</span><span class="hTxt">Событие<small id="hPass"></small></span><span class="neonTag">NEON NIGHT</span></button>
    </div>`;
  const logo = s.querySelector('.homeLogo img');
  logo.onerror = () => { logo.replaceWith(Object.assign(mk('div', 'txtLogo goldText'), { textContent: 'Tile Waifu' })); };
  s.querySelectorAll('[data-go]').forEach(b => b.addEventListener('click', e => go(b.dataset.go, e)));
  const girl = s.querySelector('.homeGirl');
  girl.addEventListener('click', e => {
    girl.classList.remove('hop'); void girl.offsetWidth; girl.classList.add('hop');
    burst(e.clientX, e.clientY, { n: 6, sparks: 6, colors: ['#ff8fb0', '#ffb3c8', '#ffd5df'], ring: 30 });
    flyIcon('art/icons/heart.png', { x: e.clientX, y: e.clientY }, { x: e.clientX + (Math.random() - .5) * 80, y: e.clientY - 140 }, { s: 30, life: .9 });
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
  const S_ = st(); if (!$('#screen-home')) return;
  const o = byId(S_.equipped?.outfit);
  const g = $('.homeGirl'), src = outfitArt(o);
  if (g.dataset.src !== src) { g.dataset.src = src; g.src = src; g.classList.toggle('framed', !CUT[o?.id]); }
  const set = (sel, v) => { const e = $(sel); if (e) e.textContent = v; };
  set('#hLevel', `Уровень ${S_.level || 1}`);
  const q = Math.min(S_.questPairs || 0, 40);
  set('#hQuestTxt', S_.questDone ? 'Выполнено! Возвращайся завтра' : `Собери 40 пар · ${q}/40 · +150 💎`);
  const qb = $('#hQuestBar'); if (qb) qb.style.width = (S_.questDone ? 100 : q / 40 * 100) + '%';
  const outfits = ALL().filter(i => i.cat === 'outfit');
  set('#hWard', `Наряды ${outfits.filter(i => S_.owned?.[i.id]).length}/${outfits.length}`);
  const ps = passState(); set('#hPass', `Пропуск: уровень ${ps.tier}/10${ps.claim ? ` · забрать: ${ps.claim}` : ''}`);
  iconize($('#hQuestTxt'));
  // экраны, которые добавили другие модули (сюжет, героини, события…), получают свою кнопку в меню
  const col = $('.homeCol'), navScr = $$('#topbar nav button[data-screen]').map(b => [b.dataset.screen, b.textContent.trim()]);
  const ev = $('.hEvent');
  if (ev) {
    const hasEv = navScr.some(n => n[0] === 'events');
    ev.dataset.go = hasEv ? 'events' : 'pass';
    if (hasEv && !ev.dataset.ev) { ev.dataset.ev = '1'; ev.querySelector('.hTxt').innerHTML = 'События<small>Ежедневки и ивент Neon Night</small>'; }
    ev.classList.toggle('has-dot', !!$('#topbar nav [data-screen="events"].tw-dot'));
  }
  let row = col.querySelector('.homeRow');
  if (!row) { row = mk('div', 'homeRow'); col.insertBefore(row, ev); }
  const small = [['pass', 'Пропуск']].concat(navScr.filter(([k]) => !['play', 'gacha', 'wardrobe', 'pass', 'events', 'story'].includes(k)));
  for (const [scr, label] of small) {
    if (row.querySelector(`[data-go="${scr}"]`)) continue;
    const m = TAB_META[scr];
    const nb = mk('button', 'hBtn hSmall', `<span class="hIco">${ico(m ? m[1] : 'star')}</span><span class="hTxt">${m ? m[0] : label}</span>`);
    nb.dataset.go = scr; nb.onclick = e => go(scr, e); row.appendChild(nb);
  }
  const psb = row.querySelector('[data-go="pass"]'); if (psb) psb.classList.toggle('has-dot', ps.claim > 0);
  if (navScr.some(n => n[0] === 'story') && !col.querySelector('[data-go="story"]')) {
    const nb = mk('button', 'hBtn', `<span class="hIco">${ico('mail')}</span><span class="hTxt">Сюжет<small id="hStory">Главы, сцены и героини</small></span><span class="chev">›</span>`);
    nb.dataset.go = 'story'; nb.onclick = e => go('story', e); col.insertBefore(nb, col.querySelector('.hPlay').nextSibling);
  }
  const cur = R(() => TW.st().cur); if (cur && $('#hStory')) $('#hStory').textContent = `Глава ${String(cur).replace('-', ' · сцена ')}`;
  if (entering) setTimeout(() => homeSay(greet()), 700);
}

const affLvl = () => R(() => TW.affLevel(TW.st().aff[TW.hero()])) ?? (1 + ((st().aff || 0) / 50 | 0));
// ---------- HUD в игре ----------
function buildHud() {
  const sp = $('#screen-play'); if (!sp || $('#hud')) return;
  const h = mk('div'); h.id = 'hud';
  h.innerHTML = `<button class="hudHome" title="Главное меню">${ico('home')}</button>
    <div class="hudCell"><small>Уровень</small><b id="hudLevel">1</b><em id="hudLayout"></em></div>
    <div class="hudCell"><small>Пары</small><b id="hudPairs">0</b></div>
    <div class="hudCombo"><div class="row"><small>Комбо</small><b id="hudCombo">×0</b></div><div class="cbar"><i id="hudBar"></i></div></div>
    <div class="hudGems">${ico('gem')}<b class="gemsView"></b></div>`;
  sp.prepend(h);
  h.querySelector('.hudHome').onclick = e => go('home', e);
  // перезапуск и звук — в угол поля
  const tools = mk('div', 'boardTools');
  const rs = $('#btnRestart'), sn = $('#btnSound');
  if (rs) { rs.innerHTML = SVG.RESTART; rs.title = 'Начать уровень заново'; tools.appendChild(rs); }
  if (sn) tools.appendChild(sn);
  $('#boardWrap')?.appendChild(tools);
  // героиня в игре: тап = реакция
  $('#heroFrame')?.addEventListener('click', e => { burst(e.clientX, e.clientY, { n: 5, sparks: 5, ring: 26 }); emit('heroTap', { where: 'play' }); });
  if ('ResizeObserver' in window && $('#boardWrap')) new ResizeObserver(() => R(() => fit())).observe($('#boardWrap'));
}
function setBtn(b, icon, label, cost, free) {
  if (!b) return;
  b.innerHTML = `<span class="cIco">${ico(icon)}</span>${cost != null && cost !== '' ? `<span class="cCost">${cost}</span>` : ''}<span class="cLbl">${label}</span>`;
  b.classList.add('cBtn'); b.classList.toggle('free', !!free);
}
function decorateControls() {
  const S_ = st(), h = $('#btnHint'), sh = $('#btnShuffle'), u = $('#btnUndo');
  const hc = R(() => hintCharges), fs = R(() => freeShuffles);
  const parse = (b, price) => { const t = b?.textContent || ''; const m = t.match(/\((\d+|∞)\)/); return m ? [m[1], true] : /·/.test(t) ? [ico('gem') + price, false] : ['', false]; };
  if (h) { const [c, f] = S_.vip ? ['∞', true] : hc != null ? (hc > 0 ? [String(hc), true] : [ico('gem') + '20', false]) : parse(h, 20); setBtn(h, 'hint', 'Подсказка', c, f); }
  if (u) setBtn(u, 'undo', 'Отмена', null);
  if (sh) { const [c, f] = fs != null ? (fs > 0 ? [String(fs), true] : [ico('gem') + '30', false]) : parse(sh, 30); setBtn(sh, 'shuffle', 'Перемешать', c, f); }
}
let comboRaf = 0, lastComboShown = -1;
function updateHudNow() {
  const S_ = st(), t = R(() => tiles) || [];
  const set = (id, v) => { const e = document.getElementById(id); if (e && e.textContent !== String(v)) e.textContent = v; };
  set('hudLevel', S_.level || 1);
  set('hudLayout', ($('#levelInfo')?.textContent.split('·')[1] || '').trim());
  set('hudPairs', t.filter(x => x.alive).length / 2 | 0);
  set('tbLevel', `Уровень ${S_.level || 1} · Симпатия ${affLvl()}`);
  tickCombo();
}
function tickCombo() {
  const c = R(() => combo) || 0, lm = R(() => lastMatch) || 0, fu = R(() => feverUntil) || 0, now = Date.now();
  const fever = now < fu;
  const left = fever ? (fu - now) / 6000 : c > 0 ? Math.max(0, 1 - (now - lm) / 4000) : 0;
  const bar = $('#hudBar'); if (bar) bar.style.width = (left * 100).toFixed(1) + '%';
  const lbl = fever ? 'ФИВЕР' : '×' + (left > 0 ? c : 0);
  const cb = $('#hudCombo');
  if (cb && cb.textContent !== lbl) { cb.textContent = lbl; cb.classList.remove('pulse'); void cb.offsetWidth; cb.classList.add('pulse'); }
  cancelAnimationFrame(comboRaf);
  if (left > 0) comboRaf = requestAnimationFrame(tickCombo);
}

// ---------- Кристаллы: плавный счётчик ----------
let shownGems = null, gemAnim = 0;
function syncGems(pop) {
  const v = st().gems | 0;
  if (shownGems === null) { shownGems = v; paintGems(v); return; }
  if (v === shownGems) return;
  const from = shownGems, to = v, t0 = performance.now(), dur = Math.min(900, 250 + Math.abs(to - from) * 6);
  shownGems = v; cancelAnimationFrame(gemAnim);
  const step = now => { const k = Math.min(1, (now - t0) / dur), e = 1 - Math.pow(1 - k, 3); paintGems(Math.round(from + (to - from) * e)); if (k < 1) gemAnim = requestAnimationFrame(step); };
  gemAnim = requestAnimationFrame(step);
  if (pop !== false) $$('.wallet, .hudGems').forEach(e => { e.classList.remove('bump'); void e.offsetWidth; e.classList.add('bump'); });
}
function paintGems(v) { const s = v.toLocaleString('ru-RU'); $$('.gemsView').forEach(e => { e.textContent = s; }); }
function gemTarget() { const e = mobile() && curScreen === 'play' ? $('.hudGems') : (curScreen === 'play' ? $('.hudGems') : $('.wallet')); return e ? center(e) : { x: innerWidth - 40, y: 30 }; }

// ---------- Матчи, комбо, фивер ----------
let bestCombo = 0, levelBase = null, lastTilesRef = null, dealPending = false, shufPending = false;
function onPairGone(els) {
  const pts = els.map(e => center(e));
  pts.forEach(p => burst(p.x, p.y, { n: 12, sparks: 9, ring: 42, glow: 46 }));
  if (pts.length >= 2) FX.add({ type: 'beam', x1: pts[0].x, y1: pts[0].y, x2: pts[1].x, y2: pts[1].y, life: .32 });
  const mid = pts.length ? { x: pts.reduce((a, p) => a + p.x, 0) / pts.length, y: pts.reduce((a, p) => a + p.y, 0) / pts.length } : { x: innerWidth / 2, y: innerHeight / 2 };
  const c = R(() => combo) || 1, fever = Date.now() < (R(() => feverUntil) || 0);
  bestCombo = Math.max(bestCombo, c);
  const gain = fever ? 2 : 1;
  const tgt = gemTarget();
  for (let i = 0; i < gain; i++) setTimeout(() => flyIcon('art/icons/gem.png', mid, tgt, { s: 24, life: .7, done: () => { const e = curScreen === 'play' ? $('.hudGems') : $('.wallet'); if (e) { e.classList.remove('bump'); void e.offsetWidth; e.classList.add('bump'); } } }), i * 90);
  const f = mk('div', 'gemFloat', `+${gain} ${ico('gem', 'sm')}`); f.style.left = mid.x + 'px'; f.style.top = mid.y + 'px'; document.body.appendChild(f); setTimeout(() => f.remove(), 950);
  if (c >= 2) {
    const p = mk('div', 'comboPop' + (c >= 5 ? ' big' : ''), `Комбо <b>×${c}</b>`);
    p.style.left = mid.x + 'px'; p.style.top = (mid.y - 46) + 'px'; document.body.appendChild(p); setTimeout(() => p.remove(), 1050);
    emit('combo', { combo: c });
  }
  if (c >= 4) { const bw = $('#boardWrap'); bw?.classList.remove('shake'); void bw?.offsetWidth; bw?.classList.add('shake'); }
  emit('match', { combo: c, fever });
  tickCombo();
}
let feverOn = false, emberT = 0;
function checkFever() {
  const on = document.body.classList.contains('fever');
  if (on === feverOn) return; feverOn = on;
  if (on) {
    const b = mk('div', 'feverBanner', '<b>ФИВЕР!</b><small>×2 КРИСТАЛЛЫ</small>'); document.body.appendChild(b); setTimeout(() => b.remove(), 1700);
    chime([523, 659, 784, 1047], { type: 'triangle', vol: .06 });
    clearInterval(emberT);
    emberT = setInterval(() => {
      if (!feverOn) return clearInterval(emberT);
      const r = $('#boardWrap')?.getBoundingClientRect(); if (!r) return;
      for (let i = 0; i < 3 * Q; i++) FX.add({ type: 'ember', x: r.left + Math.random() * r.width, y: r.bottom - Math.random() * 20, vy: -60 - Math.random() * 90, s: 1.5 + Math.random() * 2.5, c: Math.random() < .5 ? '#ffb347' : '#ff7a9a', life: 1.6 + Math.random(), ph: Math.random() * 6 });
    }, 140);
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
function afterRender() {
  const t = R(() => tiles);
  if (t && t !== lastTilesRef) { // новый расклад: раздача фишек + новая статистика уровня
    lastTilesRef = t; dealPending = true; bestCombo = 0;
    const S_ = st(); levelBase = { aff: S_.aff || 0, xp: S_.passXP || 0, gems: S_.gems || 0, t: Date.now(), level: S_.level };
  }
  const tilesEls = $$('#board .tile');
  if (dealPending && !RM) {
    dealPending = false;
    tilesEls.forEach((e, i) => { e.classList.add('deal'); e.style.animationDelay = Math.min(i * 14, 700) + 'ms'; });
    setTimeout(() => tilesEls.forEach(e => { e.classList.remove('deal'); e.style.animationDelay = ''; }), 1400);
  }
  if (shufPending) {
    shufPending = false;
    tilesEls.forEach((e, i) => { e.classList.add('shuf'); e.style.animationDelay = (i % 12) * 20 + 'ms'; });
    setTimeout(() => tilesEls.forEach(e => { e.classList.remove('shuf'); e.style.animationDelay = ''; }), 900);
    const c = center($('#boardWrap')); burst(c.x, c.y, { n: 18, sparks: 14, ring: 120, speed: 240 }); chime([660, 880, 660, 990], { step: .05, vol: .04 });
  }
  decorateControls(); updateHudNow();
}

// ---------- Бабл героини (на телефоне всплывает и прячется) ----------
let bubT;
function onSay() {
  const b = $('#bubble'); if (!b) return;
  b.classList.add('show'); clearTimeout(bubT); bubT = setTimeout(() => b.classList.remove('show'), 3400);
}

// ---------- Призыв ----------
function decorateGacha() {
  const info = $('.bannerInfo'); if (!info || info.dataset.ui) { updatePity(); return; }
  info.dataset.ui = '1';
  const h2 = info.querySelector('h2');
  if (h2) { h2.textContent = h2.textContent.replace(/^Баннер\s*/, '').replace(/[«»]/g, ''); h2.insertAdjacentHTML('beforebegin', '<span class="limTag">ЛИМИТИРОВАННЫЙ БАННЕР</span>'); }
  const ps = info.querySelectorAll('p');
  if (ps[0]) { ps[0].textContent = ps[0].textContent.replace(/\s*SSR\s*3%.*$/, ''); ps[0].insertAdjacentHTML('afterend', '<div class="rates"><span class="SSR">SSR 3%</span><span class="SR">SR 15%</span><span class="R">R 82%</span></div>'); }
  const pityP = $('#pity')?.closest('p');
  if (pityP) { const box = mk('div', 'pityBox'); pityP.replaceWith(box); box.innerHTML = `Гарант SSR через <b id="pityUi"></b> призывов<div class="bar"><i id="pityBar"></i></div><small style="opacity:.7;font-weight:700">В ×10 минимум один SR</small>`; box.appendChild(pityP); pityP.hidden = true; }
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
  ov.innerHTML = `<div class="sfBg"></div><div class="circle"></div><button class="btnGhost sfSkip">Пропустить ›</button><div class="sfHint"></div>`;
  ov.classList.add('on'); document.body.style.overflow = 'hidden';
  const alive = () => tok === sfToken;
  const tap = () => new Promise(r => { tapR = r; });
  ov.onclick = () => { if (tapR) { const r = tapR; tapR = null; r(); } };
  ov.querySelector('.sfSkip').onclick = e => { e.stopPropagation(); skip = true; if (tapR) { const r = tapR; tapR = null; r(); } };
  const sleep = ms => Promise.race([wait(ms), new Promise(r => { const iv = setInterval(() => { if (skip || !alive()) { clearInterval(iv); r(); } }, 50); setTimeout(() => clearInterval(iv), ms + 60); })]);
  // 1. ритуал: падающая звезда цвета лучшей редкости (если anim.js уже показал своё видео призыва, сразу вспышка)
  const introDone = !!document.getElementById('summonFx');
  if (!skip && !introDone) {
    ov.insertAdjacentHTML('beforeend', `<div class="orb ${best}"></div>`);
    chime([392, 523, 659], { step: .18, dur: .7, vol: .05 });
    await sleep(1100); if (!alive()) return;
    const fl = mk('div', 'flashW' + (best === 'SSR' ? ' gold' : '')); ov.appendChild(fl); setTimeout(() => fl.remove(), 800);
    burst(innerWidth / 2, innerHeight * .52, { n: 30, sparks: 30, ring: 220, speed: 380, glow: 260, spark: best === 'SSR' ? '#ffe08a' : best === 'SR' ? '#e2c8ff' : '#dfe9ff' });
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
    setTimeout(() => burst(innerWidth / 2, innerHeight * .78, { n: 24, sparks: 26, ring: 160, speed: 300, colors: ['#fff3c4', '#ffd36a', '#ffd5df'] }), 380);
    await Promise.race([tap(), wait(6000)]); if (!alive()) return;
    stage.remove(); ov.querySelector('.sfHint').textContent = '';
  }
  // 3. сетка результатов
  if (!alive()) return;
  ov.querySelector('.sfSkip')?.remove(); ov.querySelector('.circle')?.remove();
  const box = mk('div', 'resStage');
  box.innerHTML = `<div class="resTitle">Результаты призыва</div><div class="resSub">Получено предметов: ${n}</div><div class="resGrid${n === 1 ? ' one' : ''}"></div>
    <div class="resBtns"><button class="btnRose" data-again>${ico('gem', 'sm')} Ещё ×${n}</button><button class="btnGold" data-ok>OK</button></div>`;
  const grid = box.querySelector('.resGrid');
  res.forEach(it => {
    const c = mk('div', 'rCard ' + it.rar);
    const th = it.img ? `<div class="th" style="background-image:url('${it.img}')"></div>` : `<div class="th sw" style="${thumbStyle(it)}"></div>`;
    c.innerHTML = `<div class="in"><div class="b"></div><div class="f"><span class="rb">${it.rar}</span>${th}<div class="nm">${it.name}</div><div class="tg${it.dup ? ' dup' : ''}">${it.dup ? 'повтор → +20 💎' : 'НОВОЕ!'}</div></div></div>`;
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
    if (!skip) await wait(i === 0 ? 350 : 130);
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
  ov.classList.remove('on'); ov.innerHTML = ''; document.body.style.overflow = '';
}

// ---------- Гардероб ----------
let wTab = 'outfit', wHero = 'all', lastStageOutfit = null;
function enhanceWardrobe() {
  const box = $('#wardrobe'); if (!box) return;
  let stage = $('#wStage');
  if (!stage) {
    stage = mk('div'); stage.id = 'wStage';
    box.parentNode.insertBefore(stage, box);
    const hs = mk('div', 'wHeroes'); hs.id = 'wHeroes'; box.parentNode.insertBefore(hs, box);
  }
  const S_ = st(), H = HERO(), cats = R(() => CAT_NAME) || { outfit: 'Наряды', skin: 'Фишки', bg: 'Фоны' };
  const catByName = Object.fromEntries(Object.entries(cats).map(([k, v]) => [v, k]));
  const heroByName = Object.fromEntries(Object.entries(H).map(([k, v]) => [v, k]));
  const lists = {}; const idx = {};
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
    if (!own) c.addEventListener('click', () => R(() => toast(`«${it.rar}» можно получить в призыве`)));
    c.style.animationDelay = Math.min(delay++ * 25, 500) + 'ms';
  }
  void heroByName;
  // сцена: надетый наряд
  const o = byId(S_.equipped?.outfit), sk = byId(S_.equipped?.skin), b = byId(S_.equipped?.bg);
  const outfits = ALL().filter(i => i.cat === 'outfit');
  const cnt = c => { const l = ALL().filter(i => i.cat === c); return `${l.filter(i => S_.owned?.[i.id]).length}/${l.length}`; };
  const affLv = affLvl();
  stage.innerHTML = `<div class="stageArt"><img class="${CUT[o?.id] ? 'cut' : ''}" src="${outfitArt(o)}" alt=""></div>
    <div class="info"><div class="who">${H[o?.hero] || ''}</div><div class="what">${o?.name || ''}</div><div class="stars">${'★'.repeat(STARS[o?.rar] || 3)}</div>
    <div class="hearts">${ico('heart')} Симпатия ${affLv}</div>
    <div class="eqRow"><span><i style="${thumbStyle(sk)}"></i>${sk?.name || ''}</span><span><i style="${thumbStyle(b)}"></i>${b?.name || ''}</span></div>
    <div class="wTabs"><button data-t="outfit">${ico('wardrobe')}Наряды <small>${cnt('outfit')}</small></button><button data-t="skin"><img class="ui-ico" src="art/tiles/ivory/00_sakura.png" alt="">Фишки <small>${cnt('skin')}</small></button><button data-t="bg">${ico('star')}Фоны <small>${cnt('bg')}</small></button></div></div>`;
  if (lastStageOutfit && lastStageOutfit !== o?.id) { stage.querySelector('.stageArt').classList.add('pop'); const p = center(stage.querySelector('.stageArt')); setTimeout(() => burst(p.x, p.y, { n: 16, sparks: 16, ring: 90, glow: 120 }), 60); chime([784, 988, 1319], { vol: .04 }); }
  lastStageOutfit = o?.id;
  stage.querySelectorAll('.wTabs button').forEach(bt => bt.onclick = () => { wTab = bt.dataset.t; filterWardrobe(); });
  const hs = $('#wHeroes');
  const heroesIn = [...new Set(outfits.map(i => i.hero))];
  hs.innerHTML = `<button data-h="all">Все героини</button>` + heroesIn.map(h => `<button data-h="${h}">${H[h] || h}</button>`).join('');
  hs.querySelectorAll('button').forEach(bt => bt.onclick = () => { wHero = bt.dataset.h; filterWardrobe(); });
  filterWardrobe();
}
function filterWardrobe() {
  $$('#wardrobe .wItem').forEach(c => { c.hidden = (c.dataset.cat && c.dataset.cat !== wTab) || (wTab === 'outfit' && wHero !== 'all' && c.dataset.hero !== wHero); });
  $$('#wStage .wTabs button').forEach(b => b.classList.toggle('on', b.dataset.t === wTab));
  const hs = $('#wHeroes'); if (hs) { hs.style.display = wTab === 'outfit' ? '' : 'none'; hs.querySelectorAll('button').forEach(b => b.classList.toggle('on', b.dataset.h === wHero)); }
}

// ---------- Пропуск и VIP ----------
function enhancePass() {
  const sc = $('#screen-pass'); if (!sc) return;
  let head = $('#passHead');
  if (!head) {
    head = mk('div'); head.id = 'passHead';
    const t = sc.querySelector('h2')?.textContent || 'Сезон «Неоновая ночь»';
    head.innerHTML = `<span class="evTag">СОБЫТИЕ · NEON NIGHT</span><h3>${t}</h3><div class="tierRow"><div class="tierNum"><span id="phTier">0</span></div><div class="xp"><div class="bar"><i id="phBar"></i></div><small id="phTxt"></small></div></div>`;
    sc.insertBefore(head, $('#passInfo') || sc.firstChild);
    const vip = sc.querySelector('.vipCard');
    if (vip && !vip.querySelector('.vipPerks')) {
      const perks = mk('div', 'vipPerks', `<div>${ico('hint')}Подсказки без лимита</div><div>${ico('gem')}+100 каждый день</div><div>${ico('star')}Золотая рамка героини</div>`);
      vip.insertBefore(perks, $('#vipBtn'));
    }
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
  // быстро прокрутить к ближайшей награде
  const firstClaim = track.querySelector('.pCell:not(:disabled)');
  if (firstClaim) firstClaim.closest('.pTier')?.scrollIntoView({ block: 'nearest', inline: 'center', behavior: 'smooth' });
}

// ---------- Победа / поражение ----------
const fmtTime = s => `${String(s / 60 | 0).padStart(2, '0')}:${String(s % 60 | 0).padStart(2, '0')}`;
function showWin() {
  const m = $('#winModal'); if (!m) return;
  const card = m.querySelector('.modalCard'); if (!card) return;
  const S_ = st(), base = levelBase || { aff: S_.aff, xp: S_.passXP, gems: S_.gems, t: Date.now() };
  const txt = $('#winText')?.textContent || '';
  const stars = (txt.match(/★/g) || []).length || S_.stars?.[(S_.level || 2) - 1] || 1;
  const secs = (Date.now() - base.t) / 1000;
  const o = byId(S_.equipped?.outfit);
  let x = card.querySelector('.winX');
  if (!x) {
    x = mk('div', 'winX'); x.style.cssText = 'display:contents';
    x.innerHTML = `<img class="winGirl" alt=""><div class="winBody"><div class="winTitle"><span>Победа!</span></div><div class="winStars"><i></i><i></i><i></i></div>
      <div class="winRow" id="winR1"></div><div class="winRow two" id="winR2"></div><div class="winBtns"><button class="btnJade" id="winHome">${ico('home', 'sm')} Домой</button></div></div>`;
    card.appendChild(x);
    const next = $('#btnNext'); if (next) { next.classList.add('btnRose'); x.querySelector('.winBtns').appendChild(next); }
    x.querySelector('#winHome').onclick = () => { $('#btnNext')?.click(); setTimeout(() => go('home'), 30); };
  }
  const next = $('#btnNext'); if (next) next.innerHTML = 'Далее ›';
  const mapB = $('#twMapBtn'), btns = x.querySelector('.winBtns');
  if (mapB) { if (mapB.parentNode !== btns) { mapB.classList.add('btnJade'); btns.prepend(mapB); } x.querySelector('#winHome').style.display = 'none'; }
  const g = x.querySelector('.winGirl'); g.src = outfitArt(o); g.classList.toggle('framed', !CUT[o?.id]);
  g.style.animation = 'none'; void g.offsetWidth; g.style.animation = '';
  $('#winR1').innerHTML = `<div>${ico('gem')}<small>Кристаллы</small><b>+${Math.max(0, (S_.gems || 0) - (base.gems || 0))}</b></div>
    <div>${ico('heart')}<small>Симпатия</small><b>+${Math.max(0, (S_.aff || 0) - (base.aff || 0))}</b></div>
    <div>${ico('ticket')}<small>Пропуск</small><b>+${Math.max(0, (S_.passXP || 0) - (base.xp || 0))}</b></div>`;
  $('#winR2').innerHTML = `<div>${ico('calendar')}<small>Время</small><b>${fmtTime(secs)}</b></div><div>${SVG.FLAME.replace('ui-svg', 'ui-ico')}<small>Лучшее комбо</small><b>×${Math.max(1, bestCombo)}</b></div>`;
  const si = x.querySelectorAll('.winStars i'); si.forEach(i => i.classList.remove('on'));
  confetti(140);
  chime([523, 659, 784, 1047], { step: .12, dur: .6, vol: .06, type: 'triangle' });
  [0, 1, 2].slice(0, stars).forEach(k => setTimeout(() => {
    si[k].classList.add('on'); const p = center(si[k]);
    burst(p.x, p.y, { n: 10, sparks: 16, ring: 60, glow: 80, spark: '#ffe08a' }); chime([880 + k * 220], { vol: .05, dur: .3 });
  }, 650 + k * 380));
  emit('win', { stars, secs });
}
UI.showResult = function (o = {}) {
  if (o.type === 'win' && !o.title) return showWin();
  let m = $('#uiResult');
  if (!m) { m = mk('div', 'modal'); m.id = 'uiResult'; document.body.appendChild(m); }
  const lose = o.type === 'lose';
  m.innerHTML = `<div class="modalCard ${lose ? 'loseCard' : ''}" style="max-width:420px;width:calc(100% - 32px);padding:22px 18px;text-align:center;display:flex;flex-direction:column;align-items:center;gap:12px">
    <div class="winTitle"><span>${o.title || (lose ? 'Не вышло…' : 'Победа!')}</span></div>
    ${o.heroLine ? `<p style="margin:0;font-weight:800">${o.heroLine}</p>` : ''}
    <p style="margin:0;opacity:.85">${o.text || (lose ? 'Ходы закончились. Попробуем ещё раз?' : '')}</p>
    <div class="winBtns"><button class="btnJade" data-home>${ico('home', 'sm')} Домой</button><button class="btnRose" data-retry>${lose ? 'Ещё раз' : 'Далее ›'}</button></div></div>`;
  iconize(m);
  m.classList.remove('hidden'); m.style.display = 'flex';
  const close = () => { m.style.display = 'none'; };
  m.querySelector('[data-home]').onclick = () => { close(); (o.onHome || (() => go('home')))(); };
  m.querySelector('[data-retry]').onclick = () => { close(); (o.onRetry || (() => $('#btnRestart')?.click()))(); };
  if (!lose) confetti(100); else chime([392, 330, 262], { step: .16, dur: .5, vol: .05 });
  emit(lose ? 'lose' : 'win', o);
};

// ---------- Мелочи: рипл на кнопках ----------
document.addEventListener('pointerdown', e => {
  const b = e.target.closest('.hBtn,.btnGold,.btnRose,.btnJade,.btnGhost,#pull1,#pull10,#btnNext,#passPremBtn,#vipBtn'); if (!b) return;
  const r = b.getBoundingClientRect(), s = Math.max(r.width, r.height) * 2;
  const rp = mk('span', 'ripple'); rp.style.cssText = `width:${s}px;height:${s}px;left:${e.clientX - r.left - s / 2}px;top:${e.clientY - r.top - s / 2}px`;
  b.appendChild(rp); setTimeout(() => rp.remove(), 600);
}, { passive: true });

// ---------- Подключение ----------
function init() {
  buildTopbar(); buildHome(); buildHud(); buildTabs();
  wrap('render', afterRender);
  wrap('shuffleBoard', null, () => { shufPending = true; });
  wrap('updateHud', () => { syncGems(); updatePity(); if (curScreen === 'home') refreshHome(); paintPassDot(); updateHudNow(); });
  wrap('say', onSay);
  wrap('win', () => setTimeout(showWin, 30));
  watchPulls();
  wrap('renderWardrobe', enhanceWardrobe);
  wrap('renderPass', () => { enhancePass(); paintPassDot(); });
  wrap('applyEquip', () => { if (curScreen === 'home') refreshHome(); });
  watchBoard();
  // экраны: следим, кто и как их переключает
  new MutationObserver(ms => { if (ms.some(m => m.target.classList?.contains('screen'))) syncScreen(); })
    .observe($('#app'), { subtree: true, attributes: true, attributeFilter: ['class'] });
  const nav = $('#topbar nav'); if (nav) new MutationObserver(() => buildTabs()).observe(nav, { childList: true });
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
  syncGems(false); paintSound(); decorateControls(); afterRender(); paintPassDot();
  const start = new URLSearchParams(location.search).get('screen');
  go(start && $('#screen-' + start) ? start : 'home');
  syncScreen(true);
  document.documentElement.classList.add('ui-ready');
}
function paintPassDot() {
  const t = $('#tabbar .tab[data-go="pass"]'); if (t) t.classList.toggle('has-dot', passState().claim > 0);
  const ev = $('#tabbar .tab[data-go="events"]'); if (ev) ev.classList.toggle('has-dot', !!$('#topbar nav [data-screen="events"].tw-dot'));
  const g = $('#tabbar .tab[data-go="gacha"]'); if (g) g.classList.toggle('has-dot', (st().gems || 0) >= 900);
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
