// Tile Waifu — сюжетный режим: прогресс по главам, карта уровней, визуальная новелла между уровнями.
// Подключается ДО game.js (после levels.js и story_*.js). Состояние живёт в S.tw (S — сохранение из game.js).
'use strict';
(function () {
const TW = window.TW = window.TW || {};
const $q = s => document.querySelector(s);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const CH = () => window.TW_CHAPTERS || [];
const SC = () => window.TW_SCENES || {};

// ---------- Состояние ----------
TW.st = function () {
  if (!S.tw) S.tw = {};
  const t = S.tw;
  t.cur = t.cur || '1-1';           // самый дальний открытый сюжетный уровень
  t.play = t.play || t.cur;         // что играем сейчас (можно переигрывать пройденное)
  t.mode = t.mode || 'story';       // story | event | daily | endless
  t.stars = t.stars || {};
  t.seen = t.seen || {};            // просмотренные сцены и подсказки
  t.pending = t.pending || [];      // сцены, которые надо показать перед следующей доской
  t.endless = t.endless || 1;
  t.storyDone = !!t.storyDone;
  return t;
};
const storyIds = () => TW.LEVELS.filter(l => l.mode === 'story').map(l => l.id);
const nextId = id => { const a = storyIds(), i = a.indexOf(id); return i >= 0 && i < a.length - 1 ? a[i + 1] : null; };
const idxOf = id => storyIds().indexOf(id);
TW.isOpen = id => idxOf(id) <= idxOf(TW.st().cur);

// Сцены вокруг уровня: перед 1-м — intro главы, перед 7-м — mid, после 12-го — end. Ивент: nn_1..nn_5.
const EVENT_SCENES = { 1: 'nn_1', 4: 'nn_2', 8: 'nn_3', 12: 'nn_4' };
TW.preScenes = def => {
  const out = [];
  if (def.mode === 'story') { if (def.n === 1) out.push(`ch${def.ch}_intro`); if (def.n === 7) out.push(`ch${def.ch}_mid`); }
  if (def.mode === 'event' && EVENT_SCENES[def.n]) out.push(EVENT_SCENES[def.n]);
  // подсказка по новой механике — в первый раз, когда она встречается
  for (const k of ['coin', 'heart', 'ice', 'flower', 'lock', 'spark', 'hidden', 'stone']) if (def.mech?.[k]) out.push('tip_' + k);
  return out;
};
TW.postScenes = def => {
  if (def.mode === 'story' && def.n === 12) return [`ch${def.ch}_end`];
  if (def.mode === 'event' && def.n === 15) return ['nn_5'];
  return [];
};
// Новая героиня присоединяется в начале своей главы: даём её базовый наряд.
const JOIN = { 2: ['rin', 'r_base'], 3: ['hana', 'h_base'], 4: ['yue', 'y_base'] };

TW.currentDef = function () {
  const t = TW.st();
  if (t.mode === 'event' && TW.ev) return TW.LEVEL[TW.ev().play] || TW.LEVEL['N-1'];
  if (t.mode === 'daily') return TW.dailyLevel(new Date().toISOString().slice(0, 10));
  if (t.mode === 'endless') return TW.endlessLevel(t.endless);
  return TW.LEVEL[t.play] || TW.LEVEL['1-1'];
};
TW.titleFor = def => {
  const L = TW.LAYOUTS[def.layout].name;
  if (def.mode === 'story') return `Глава ${def.ch} · ${def.n}/12${def.boss ? ' 👑' : ''} · ${L}`;
  if (def.mode === 'event') return `Неоновая ночь · ${def.n}/15${def.boss ? ' 👑' : ''} · ${L}`;
  if (def.mode === 'daily') return `Испытание дня · ${L}`;
  return `Бесконечный режим · ${def.n} · ${L}`;
};

// ---------- Хуки для game.js ----------
TW.build = function () {
  const t = TW.st(), def = TW.currentDef();
  TW.cur = def; TW.neon = !!def.neon;
  const perks = TW.perks ? TW.perks() : {};
  const tiles = TW.generate(def, { iceMinus: perks.iceMinus || 0 });
  // Очередь сцен: отложенные (после прошлой победы) + перед этим уровнем, только непросмотренные.
  const q = [...t.pending, ...TW.preScenes(def)].filter((id, i, a) => a.indexOf(id) === i && !t.seen[id]);
  t.pending = [];
  TW.queue = q;
  return { tiles, cfg: { faces: def.faces, layout: 0 }, layout: { name: TW.LAYOUTS[def.layout].name }, title: TW.titleFor(def) };
};
TW.afterNewGame = function () {
  const p = TW.perks ? TW.perks() : {};
  if (p.hints && typeof hintCharges !== 'undefined') hintCharges += p.hints;
  if (p.shuffles && typeof freeShuffles !== 'undefined') freeShuffles += p.shuffles;
  document.documentElement.classList.toggle('tw-neon', !!TW.neon);
  TW.startedAt = Date.now();
  if (typeof render === 'function') render();
  TW.refreshHud?.();
  if (TW.ready) TW.flushQueue();
};
TW.flushQueue = function () {
  const q = TW.queue || []; TW.queue = [];
  if (q.length) TW.playScenes(q);
};
// Победа: звёзды, награда, продвижение. Возвращает {reward, extra} для окна победы game.js.
TW.onWin = function (stars) {
  const t = TW.st(), def = TW.cur || TW.currentDef();
  let reward = 0, extra = [];
  const first = !(t.stars[def.id] > 0);
  if (def.mode === 'story') {
    reward = first ? 40 + idxOf(def.id) * 2 + stars * 15 + (def.boss ? 100 : 0) : 10 + stars * 5;
    t.stars[def.id] = Math.max(t.stars[def.id] || 0, stars);
    const nx = nextId(def.id);
    if (def.id === t.cur) { if (nx) t.cur = nx; else t.storyDone = true; }
    t.play = nx && TW.isOpen(nx) ? nx : t.cur;
    if (!nx) { t.mode = 'endless'; extra.push('Сюжет пройден! Открыт бесконечный режим.'); }
    if (def.boss && first) extra.push(`Глава ${def.ch} пройдена! +100 💎`);
  } else if (def.mode === 'endless') {
    reward = 30 + Math.min(60, t.endless * 2) + stars * 10; t.endless++;
  } else if (def.mode === 'daily') {
    reward = TW.onDailyWin ? TW.onDailyWin(stars) : 50;
    t.mode = t.storyDone ? 'endless' : 'story';
  } else if (def.mode === 'event' && TW.onEventWin) {
    const r = TW.onEventWin(def, stars, first); reward = r.reward; if (r.text) extra.push(r.text);
  }
  t.pending.push(...TW.postScenes(def));
  const m = TW.onWinMeta ? TW.onWinMeta(def, stars) : null; // симпатия, задания дня
  if (m) extra.push(m);
  if (typeof S !== 'undefined') S.level = Math.max(S.level || 1, idxOf(t.cur) + 1); // для старых экранов
  const nb = $q('#btnNext'); if (nb) nb.textContent = t.mode === 'event' && TW.ev && !TW.LEVEL[TW.ev().play] ? 'К ивенту' : 'Дальше ▶';
  setTimeout(() => TW.renderMap?.(), 0);
  return { reward, extra: extra.map(esc).join('<br>') };
};

// ---------- Визуальная новелла ----------
// Портреты для сцен — вырезанные без фона (Higgsfield background remover).
const PORTRAIT = { mc: 'art/scenes/mc_vn.webp', rin: 'art/scenes/rin_vn.webp', hana: 'art/scenes/hana_vn.webp', yue: 'art/scenes/yue_vn.webp', nova: 'art/scenes/nova_vn.webp' };
const NAMES = { mc: 'Маджонг-тян', rin: 'Рин', hana: 'Хана', yue: 'Юэ', nova: 'Нова', me: 'Ты' };
const BGS = { parlor: 'art/scenes/bg_parlor.webp', teahouse: 'art/scenes/bg_teahouse.webp', gym: 'art/scenes/bg_gym.webp', palace: 'art/scenes/bg_palace.webp',
  shrine: 'art/scenes/bg_shrine.webp', festival: 'art/scenes/bg_festival.webp', rooftop: 'art/scenes/bg_rooftop.webp', street: 'art/scenes/bg_street.webp', neon: 'art/bg_neon.webp' };
TW.BGS = BGS;
const CGS = { cg_mc: 'art/scenes/cg_mc.webp', cg_rin: 'art/scenes/cg_rin.webp', cg_hana: 'art/scenes/cg_hana.webp', cg_yue: 'art/scenes/cg_yue.webp', cg_nova: 'art/scenes/cg_nova.webp', cg_finale: 'art/scenes/cg_finale.webp' };
TW.CGS = CGS;
const portraitOf = h => PORTRAIT[h];
let vn = null;
function vnEl() {
  if (vn) return vn;
  vn = document.createElement('div'); vn.id = 'twVN'; vn.className = 'hidden';
  vn.innerHTML = `<div class="vnBg"></div><div class="vnCast"><img class="vnP L" alt=""><img class="vnP R" alt=""></div><div class="vnCg"><img alt=""></div>
    <div class="vnTitle"></div>
    <div class="vnBox"><div class="vnName"></div><div class="vnText"></div><div class="vnChoices"></div><div class="vnNext">▼</div></div>
    <div class="vnTop"><button class="vnLog" title="История">📜</button><button class="vnSkip">Пропустить ⏩</button></div>
    <div class="vnHistory hidden"></div>`;
  document.body.appendChild(vn);
  return vn;
}
function tipScene(id) {
  const k = id.slice(4), lines = (window.TW_TIPS || {})[k];
  return lines ? { title: 'Новая механика', bg: null, lines, tip: true } : null;
}
// Проигрывает список сцен подряд; done вызывается в конце.
TW.playScenes = function (ids, done, opts = {}) {
  const list = ids.map(id => [id, id.startsWith('tip_') ? tipScene(id) : SC()[id]]).filter(x => x[1]);
  const t = TW.st();
  const step = i => {
    if (i >= list.length) { done && done(); return; }
    const [id, sc] = list[i];
    runScene(sc, () => {
      if (!opts.replay) { t.seen[id] = true; onSceneDone(id); typeof save === 'function' && save(); }
      step(i + 1);
    }, opts);
  };
  step(0);
};
function onSceneDone(id) {
  const m = /^ch(\d)_intro$/.exec(id);
  if (m && JOIN[m[1]]) {
    const [h, item] = JOIN[m[1]];
    if (!S.owned[item]) { S.owned[item] = true; typeof toast === 'function' && toast(`Новая героиня: ${NAMES[h]}! Её наряд «${ITEM[item].name}» уже в гардеробе`); }
  }
  TW.onSceneDoneMeta?.(id);
}
function runScene(sc, done, opts) {
  const v = vnEl();
  const box = v.querySelector('.vnBox'), nameEl = v.querySelector('.vnName'), textEl = v.querySelector('.vnText'), chEl = v.querySelector('.vnChoices');
  const pL = v.querySelector('.vnP.L'), pR = v.querySelector('.vnP.R'), cg = v.querySelector('.vnCg'), hist = v.querySelector('.vnHistory');
  const slots = { L: null, R: null };
  let i = 0, typing = null, full = '', finished = false, history = [];
  v.classList.remove('hidden'); v.classList.toggle('tip', !!sc.tip); hist.classList.add('hidden');
  v.querySelector('.vnTitle').textContent = sc.title || '';
  v.querySelector('.vnTitle').classList.remove('show'); void v.offsetWidth; if (sc.title && !sc.tip) v.querySelector('.vnTitle').classList.add('show');
  setBg(sc.bg); cg.classList.remove('show'); pL.className = 'vnP L'; pR.className = 'vnP R'; pL.removeAttribute('src'); pR.removeAttribute('src');
  function setBg(k) { v.querySelector('.vnBg').style.backgroundImage = k && BGS[k] ? `url('${BGS[k]}')` : 'none'; v.querySelector('.vnBg').classList.toggle('black', k === 'black'); }
  function show(h, emo) {
    let side = slots.L === h ? 'L' : slots.R === h ? 'R' : null;
    if (!side) { side = !slots.L ? 'L' : !slots.R ? 'R' : (slots.L === lastSpeaker ? 'R' : 'L'); slots[side] = h; const img = side === 'L' ? pL : pR; img.src = portraitOf(h); }
    for (const s of ['L', 'R']) { const img = s === 'L' ? pL : pR; img.className = 'vnP ' + s + (slots[s] ? ' on' : '') + (s === side ? ' talk e-' + (emo || 'neutral') : ' dim'); }
  }
  let lastSpeaker = null;
  function dimAll() { for (const s of ['L', 'R']) { const img = s === 'L' ? pL : pR; img.className = 'vnP ' + s + (slots[s] ? ' on dim' : ''); } }
  function type(txt) {
    full = txt; textEl.textContent = ''; let k = 0; clearInterval(typing);
    typing = setInterval(() => { k += 2; textEl.textContent = full.slice(0, k); if (k >= full.length) { clearInterval(typing); typing = null; } }, 22);
  }
  function line([sp, emo, txt]) {
    box.classList.toggle('narr', !sp); box.classList.toggle('me', sp === 'me');
    nameEl.textContent = NAMES[sp] || ''; nameEl.style.display = sp ? '' : 'none';
    if (PORTRAIT[sp]) { show(sp, emo); lastSpeaker = sp; } else dimAll();
    history.push((NAMES[sp] ? NAMES[sp] + ': ' : '') + txt);
    type(txt);
    document.dispatchEvent(new CustomEvent('tw:line', { detail: { speaker: sp, emotion: emo, text: txt } })); // для озвучки
  }
  function choice(list) {
    chEl.innerHTML = ''; box.classList.add('choosing'); textEl.textContent = ''; nameEl.style.display = 'none';
    list.forEach(o => {
      const b = document.createElement('button'); b.textContent = o.t;
      b.onclick = e => {
        e.stopPropagation(); chEl.innerHTML = ''; box.classList.remove('choosing');
        history.push('Ты: ' + o.t);
        if (o.aff && !opts.replay) for (const [h, n] of Object.entries(o.aff)) TW.addAff?.(h, n * 5, true);
        if (o.r) { line(o.r); } else next();
      };
      chEl.appendChild(b);
    });
  }
  function next() {
    if (typing) { clearInterval(typing); typing = null; textEl.textContent = full; return; }
    if (box.classList.contains('choosing')) return;
    if (i >= sc.lines.length) return finish();
    const L = sc.lines[i++];
    if (Array.isArray(L)) return line(L);
    if ('bg' in L) { setBg(L.bg); return next(); }
    if ('cg' in L) { if (L.cg && CGS[L.cg]) { cg.querySelector('img').src = CGS[L.cg]; cg.classList.add('show'); TW.unlockCg?.(L.cg); } else cg.classList.remove('show'); return next(); }
    if (L.choice) return choice(L.choice);
    next();
  }
  function finish() { if (finished) return; finished = true; clearInterval(typing); v.classList.add('hidden'); v.onclick = null; done(); }
  v.onclick = e => { if (e.target.closest('.vnTop') || e.target.closest('.vnHistory')) return; next(); };
  v.querySelector('.vnSkip').onclick = e => { e.stopPropagation(); finish(); };
  v.querySelector('.vnLog').onclick = e => { e.stopPropagation(); hist.innerHTML = history.map(h => `<p>${esc(h)}</p>`).join('') || '<p>Пока пусто</p>'; hist.classList.toggle('hidden'); };
  hist.onclick = e => { e.stopPropagation(); hist.classList.add('hidden'); };
  next();
}

// ---------- Экран «Сюжет»: главы и карта уровней ----------
let mapCh = 0;
function chapterOf(id) { return +String(id).split('-')[0] || 1; }
TW.renderMap = function () {
  const box = $q('#screen-story'); if (!box || typeof S === 'undefined') return;
  const t = TW.st();
  const curCh = chapterOf(t.cur);
  if (!mapCh) mapCh = curCh;
  const chs = CH().length ? CH() : [1, 2, 3, 4, 5, 6].map(id => ({ id, title: 'Глава ' + id, hero: 'mc', blurb: '' }));
  const tabs = chs.map(c => {
    const lv = TW.chapterLevels(c.id), st = lv.reduce((s, l) => s + (t.stars[l.id] || 0), 0), open = c.id <= curCh;
    return `<button class="chTab${c.id === mapCh ? ' active' : ''}${open ? '' : ' locked'}" data-ch="${c.id}">${open ? '' : '🔒 '}${c.id}. ${esc(c.title)}<small>★ ${st}/36</small></button>`;
  }).join('');
  const c = chs.find(x => x.id === mapCh) || chs[0];
  const lv = TW.chapterLevels(c.id);
  // Змейка из 12 узлов поверх карты города: 3 ряда по 4.
  const nodes = lv.map((l, i) => {
    const row = i / 4 | 0, col = row % 2 ? 3 - (i % 4) : i % 4;
    const x = 14 + col * 24, y = 20 + row * 30;
    const open = TW.isOpen(l.id), s = t.stars[l.id] || 0, cur = l.id === t.cur;
    const pre = TW.preScenes(l).filter(id => !id.startsWith('tip_')).length ? '<i class="sc">💬</i>' : '';
    const mechNew = TW.preScenes(l).filter(id => id.startsWith('tip_') && !t.seen[id]).length ? '<i class="nw">!</i>' : '';
    return `<button class="node${open ? '' : ' locked'}${cur ? ' cur' : ''}${l.boss ? ' boss' : ''}" style="left:${x}%;top:${y}%" data-id="${l.id}" ${open ? '' : 'disabled'}>
      ${pre}${mechNew}<b>${l.boss ? '👑' : l.n}</b><span>${open ? '★'.repeat(s) + '☆'.repeat(3 - s) : '🔒'}</span></button>`;
  }).join('');
  const path = lv.map((l, i) => { const row = i / 4 | 0, col = row % 2 ? 3 - (i % 4) : i % 4; return `${14 + col * 24},${20 + row * 30}`; }).join(' ');
  const scenes = ['intro', 'mid', 'end'].map(k => `ch${c.id}_${k}`).filter(id => t.seen[id]);
  const heroImg = `art/${c.hero || 'mc'}_base.webp`;
  box.innerHTML = `<div class="chTabs">${tabs}</div>
    <div class="chHead"><img src="${heroImg}" alt=""><div><h2>Глава ${c.id}. ${esc(c.title)}</h2><p>${esc(c.blurb || '')}</p>
      <div class="chBtns">${c.id <= curCh ? `<button class="primary" data-go="${c.id === curCh ? t.cur : lv[0].id}">▶ ${c.id === curCh ? 'Продолжить' : 'Играть'}</button>` : ''}
      ${scenes.map(id => `<button data-replay="${id}">💬 ${{ intro: 'Пролог', mid: 'Середина', end: 'Финал' }[id.split('_')[1]]}</button>`).join('')}</div></div></div>
    <div class="mapWrap"><svg viewBox="0 0 100 100" preserveAspectRatio="none"><polyline points="${path}" /></svg>${nodes}</div>
    <div class="mapExtra">
      <button data-mode="daily">🗓 Испытание дня</button>
      ${t.storyDone ? `<button data-mode="endless">♾ Бесконечный режим · ${t.endless}</button>` : '<span class="muted">♾ Бесконечный режим откроется после главы 6</span>'}
    </div>`;
  box.querySelectorAll('.chTab:not(.locked)').forEach(b => b.onclick = () => { mapCh = +b.dataset.ch; TW.renderMap(); });
  box.querySelectorAll('.node:not(.locked)').forEach(b => b.onclick = () => TW.startLevel('story', b.dataset.id));
  box.querySelectorAll('[data-go]').forEach(b => b.onclick = () => TW.startLevel('story', b.dataset.go));
  box.querySelectorAll('[data-replay]').forEach(b => b.onclick = () => TW.playScenes([b.dataset.replay], null, { replay: true }));
  box.querySelectorAll('[data-mode]').forEach(b => b.onclick = () => TW.startLevel(b.dataset.mode));
};
// Запуск уровня из любого экрана: выставляем режим и переключаемся на поле.
TW.startLevel = function (mode, id) {
  const t = TW.st();
  t.mode = mode;
  if (mode === 'story' && id) t.play = id;
  if (mode === 'event' && id && TW.ev) TW.ev().play = id;
  typeof save === 'function' && save();
  TW.goScreen('play');
  $q('#winModal')?.classList.add('hidden');
  typeof newGame === 'function' && newGame();
};
TW.goScreen = function (name) {
  const b = document.querySelector(`nav button[data-screen="${name}"]`);
  if (b) b.click();
  else document.querySelectorAll('.screen').forEach(s => s.classList.toggle('active', s.id === 'screen-' + name));
};

// ---------- Вставка в интерфейс (без правки index.html) ----------
// Скрипт грузится до game.js, поэтому кнопки, добавленные сейчас, получат обработчик навигации game.js.
TW.addScreen = function (name, label, onShow, first) {
  const nav = document.querySelector('nav');
  if (!document.getElementById('screen-' + name)) {
    const sec = document.createElement('section'); sec.id = 'screen-' + name; sec.className = 'screen tw-screen';
    const anchor = document.getElementById('screen-play');
    (anchor?.parentNode || document.getElementById('app') || document.body).insertBefore(sec, anchor ? anchor.nextSibling : null);
  }
  if (nav && !nav.querySelector(`[data-screen="${name}"]`)) {
    const b = document.createElement('button'); b.dataset.screen = name; b.textContent = label; b.className = 'tw-nav';
    if (first) nav.insertBefore(b, nav.firstChild); else nav.appendChild(b);
    b.addEventListener('click', () => {
      // запасной переключатель на случай, если навигация game.js изменится
      setTimeout(() => {
        if (!document.getElementById('screen-' + name).classList.contains('active')) {
          document.querySelectorAll('.screen').forEach(s => s.classList.toggle('active', s.id === 'screen-' + name));
          document.querySelectorAll('nav button').forEach(x => x.classList.toggle('active', x === b));
        }
        onShow();
      }, 0);
    });
  }
};
TW.addScreen('story', 'Сюжет', () => { mapCh = 0; TW.renderMap(); }, true);

// Кнопка «К карте» в окне победы.
function addWinMapBtn() {
  const card = $q('#winModal .modalCard'); if (!card || $q('#twMapBtn')) return;
  const b = document.createElement('button'); b.id = 'twMapBtn'; b.className = 'tw-secondary'; b.textContent = '🗺 К карте';
  b.onclick = () => { $q('#winModal').classList.add('hidden'); const m = TW.st().mode; TW.goScreen(m === 'event' ? 'events' : 'story'); typeof newGame === 'function' && newGame(); };
  card.appendChild(b);
}

// Предупреждение для повторного запуска: сцены показываем после того, как game.js запустил первую доску.
document.addEventListener('DOMContentLoaded', () => {
  TW.ready = true;
  addWinMapBtn();
  TW.flushQueue();
});
})();
