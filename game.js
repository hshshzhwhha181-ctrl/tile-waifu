// Tile Waifu — прототип маджонг-пасьянса с героиней и гачей. Без сборки, работает оффлайн (PWA).
'use strict';

// ---------- Арт ----------
const ART = {
  A: 'art/mc_base.webp',
  B: 'art/style_b.webp',
  C: 'art/style_c.webp',
  D: 'art/style_d.webp',
};
const ART_STYLE = new URLSearchParams(location.search).get('style') || 'A';
const FALLBACK_ART = 'data:image/svg+xml;utf8,' + encodeURIComponent(
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 360"><rect width="240" height="360" fill="#ffe0ec"/>
  <circle cx="120" cy="110" r="52" fill="#ffb3cf"/><circle cx="62" cy="90" r="26" fill="#ff8fb8"/><circle cx="178" cy="90" r="26" fill="#ff8fb8"/>
  <path d="M60 360 Q60 190 120 180 Q180 190 180 360Z" fill="#3fb59a"/><text x="120" y="330" font-size="18" text-anchor="middle" fill="#fff" font-family="sans-serif">арт-заглушка</text></svg>`);

// ---------- Предметы гачи ----------
const ITEMS = [
  // наряды: у каждого свой арт из Higgsfield (стиль A). Героиня определяется надетым нарядом.
  { id: 'o_base',   cat: 'outfit', hero: 'mc',   rar: 'R',   name: 'Ципао наставницы', ico: '👘', img: 'art/mc_base.webp', owned: true },
  { id: 'o_tutor',  cat: 'outfit', hero: 'mc',   rar: 'SR',  name: 'Репетитор после уроков', ico: '📚', img: 'art/mc_tutor.webp' },
  { id: 'o_cafe',   cat: 'outfit', hero: 'mc',   rar: 'SR',  name: 'Официантка чайной', ico: '☕', img: 'art/mc_cafe.webp' },
  { id: 'o_dragon', cat: 'outfit', hero: 'mc',   rar: 'SSR', name: 'Императрица дракона', ico: '🐉', img: 'art/mc_dragon.webp' },
  { id: 'r_base',   cat: 'outfit', hero: 'rin',  rar: 'R',   name: 'Хозяйка чайной', ico: '🍵', img: 'art/rin_base.webp' },
  { id: 'r_maid',   cat: 'outfit', hero: 'rin',  rar: 'SR',  name: 'Горничная', ico: '🎀', img: 'art/rin_maid.webp' },
  { id: 'r_agent',  cat: 'outfit', hero: 'rin',  rar: 'SSR', name: 'Городской агент', ico: '🕶️', img: 'art/rin_agent.webp' },
  { id: 'r_idol',   cat: 'outfit', hero: 'rin',  rar: 'SSR', name: 'Звёздная айдол', ico: '🎤', img: 'art/rin_idol.webp' },
  { id: 'h_base',   cat: 'outfit', hero: 'hana', rar: 'R',   name: 'Спортивный стиль', ico: '🏀', img: 'art/hana_base.webp' },
  { id: 'h_street', cat: 'outfit', hero: 'hana', rar: 'SR',  name: 'Уличный раннер', ico: '🎧', img: 'art/hana_street.webp' },
  { id: 'h_beach',  cat: 'outfit', hero: 'hana', rar: 'SR',  name: 'Летний пляж', ico: '🏖️', img: 'art/hana_beach.webp' },
  { id: 'y_base',   cat: 'outfit', hero: 'yue',  rar: 'SR',  name: 'Лунная принцесса', ico: '🌙', img: 'art/yue_base.webp' },
  { id: 'y_duel',   cat: 'outfit', hero: 'yue',  rar: 'SSR', name: 'Драконья дуэлянтка', ico: '⚔️', img: 'art/yue_duel.webp' },
  { id: 'y_queen',  cat: 'outfit', hero: 'yue',  rar: 'SSR', name: 'Королева лунной ночи', ico: '👑', img: 'art/yue_queen.webp' },
  { id: 'r_after',  cat: 'outfit', hero: 'rin',  rar: 'SR',  name: 'После работы', ico: '🍸', img: 'art/rin_after.webp' },
  { id: 'h_gym',    cat: 'outfit', hero: 'hana', rar: 'SSR', name: 'Чемпионка зала', ico: '💪', img: 'art/hana_gym.webp' },
  { id: 'n_base',   cat: 'outfit', hero: 'nova', rar: 'SR',  name: 'Нетраннер', ico: '💾', img: 'art/nova_base.webp' },
  { id: 'n_ssr',    cat: 'outfit', hero: 'nova', rar: 'SSR', name: 'Неоновый форсаж', ico: '🏍️', img: 'art/nova_ssr.webp' },
  // скины фишек
  { id: 's_sakura', cat: 'skin', rar: 'R',   name: 'Сакура', ico: '🌸', tile: '#fffaf0', back: '#ff9cc2', owned: true },
  { id: 's_mint',   cat: 'skin', rar: 'R',   name: 'Мятные', ico: '🍃', tile: '#f4fff9', back: '#5fd3ae' },
  { id: 's_lemon',  cat: 'skin', rar: 'R',   name: 'Лимонные', ico: '🍋', tile: '#fffde8', back: '#f2cf3c' },
  { id: 's_night',  cat: 'skin', rar: 'SR',  name: 'Полночь', ico: '🌙', tile: '#eef0ff', back: '#6a5cff' },
  { id: 's_neon',   cat: 'skin', rar: 'SR',  name: 'Неон', ico: '🔮', tile: '#1b1830', back: '#2ef2ff' },
  { id: 's_gold',   cat: 'skin', rar: 'SSR', name: 'Золото дракона', ico: '💛', tile: '#fff6d6', back: '#e0a100' },
  // фоны
  { id: 'b_default', cat: 'bg', rar: 'R',   name: 'Розовое утро', ico: '🌅', cls: '', owned: true },
  { id: 'b_tea',     cat: 'bg', rar: 'R',   name: 'Чайный сад', ico: '🍵', cls: 'bg-tea' },
  { id: 'b_beach',   cat: 'bg', rar: 'SR',  name: 'Пляж', ico: '🏖️', cls: 'bg-beach' },
  { id: 'b_neon',    cat: 'bg', rar: 'SSR', name: 'Неоновый город', ico: '🌃', cls: 'bg-neon' },
  { id: 'b_night',   cat: 'bg', rar: 'SSR', name: 'Ночной город', ico: '🏮', cls: 'bg-night' },
];
(window.TW_EXTRA_ITEMS || []).forEach(i => { if (!ITEMS.some(x => x.id === i.id)) ITEMS.push(i); }); // наряды за симпатию (meta.js)
const ITEM = Object.fromEntries(ITEMS.map(i => [i.id, i]));
const CAT_NAME = { outfit: 'Наряды', skin: 'Фишки', bg: 'Фоны' };
const HEROES = { mc: 'Маджонг-тян', rin: 'Рин', hana: 'Хана', yue: 'Юэ', nova: 'Нова' };
const NEON_BG = 'art/bg_neon.webp';
const BANNER_IMG = 'art/yue_queen.webp';

// ---------- Сохранение ----------
const SAVE_KEY = 'tilewaifu.v1';
const today = () => new Date().toISOString().slice(0, 10);
const defaultState = () => ({
  gems: 500, owned: Object.fromEntries(ITEMS.filter(i => i.owned).map(i => [i.id, true])),
  equipped: { outfit: 'o_base', skin: 's_sakura', bg: 'b_default' },
  pity: 0, level: 1, aff: 0, lastDay: '', questDay: '', questPairs: 0, questDone: false, sound: true,
  vip: false, passXP: 0, passPremium: false, passClaimed: {}, stars: {},
});
let S;
try { S = Object.assign(defaultState(), JSON.parse(localStorage.getItem(SAVE_KEY) || '{}')); } catch { S = defaultState(); }
const save = () => { try { localStorage.setItem(SAVE_KEY, JSON.stringify(S)); } catch {} };

// ---------- Раскладки (единица = половина фишки, фишка занимает 2×2) ----------
function rect(x0, y0, w, h, z) { const r = []; for (let i = 0; i < w; i++) for (let j = 0; j < h; j++) r.push([x0 + 2 * i, y0 + 2 * j, z]); return r; }
const LAYOUTS = [
  { name: 'Чашка чая', pos: () => [...rect(0, 0, 6, 4, 0), ...rect(2, 2, 4, 2, 1), ...rect(4, 3, 2, 1, 2)] },
  { name: 'Бабочка', pos: () => [...rect(0, 0, 4, 6, 0), ...rect(10, 0, 4, 6, 0), ...rect(8, 2, 1, 4, 0),
      ...rect(2, 2, 2, 4, 1), ...rect(12, 2, 2, 4, 1), [3, 4, 2], [13, 4, 2]] },
  { name: 'Пагода', pos: () => [...rect(0, 0, 8, 6, 0), ...rect(2, 2, 6, 4, 1), ...rect(4, 4, 4, 2, 2), ...rect(6, 5, 2, 1, 3), [-2, 5, 0], [16, 5, 0]] },
  { name: 'Крепость', pos: () => [...rect(0, 0, 10, 6, 0), ...rect(2, 2, 8, 4, 1), ...rect(6, 4, 4, 2, 2), ...rect(8, 5, 2, 1, 3)] },
];
// Кривая сложности: первые уровни маленькие и с малым числом разных фишек, дальше больше фишек, лёд и большие раскладки.
function levelCfg(lv) {
  const order = [0, 0, 1, 1, 2, 1, 2, 3, 2, 3];
  const layout = lv <= order.length ? order[lv - 1] : [1, 2, 3][(lv - 1) % 3];
  return { layout, faces: Math.min(FACES.length, 5 + lv * 3), ice: lv < 4 ? 0 : Math.min(12, (lv - 3) * 2) };
}
const FACES = ['🌸','🌺','🌼','🌻','🌷','🍀','🍁','🌙','⭐','☀️','🌈','❄️','🔥','💧','⚡','🍡','🍰','🍓','🍑','🍒','🍋','🍵','🧋','🎀','💎','👑','🔔','🎐','🏮','🐱','🐰','🦊','🐼','🐉','🐟','🦋'];
// Картинки фишек (нарезка листов Higgsfield), порядок совпадает с FACES. ?emoji в адресе = старые эмодзи.
const TILE_ART = ['sakura','plum','chrysanthemum','sunflower','tulip','clover','maple','moon','star','sun','rainbow','snowflake','fire','water','lightning','dango','cake','strawberry','peach','cherry','lemon','matcha','bubbletea','bow','diamond','crown','bell','windchime','lantern','cat','rabbit','fox','panda','dragon','koi','butterfly'];
const USE_TILE_ART = !new URLSearchParams(location.search).has('emoji');
const tileImg = i => `art/tiles/${S.equipped.skin === 's_neon' ? 'neon' : 'ivory'}/${String(i).padStart(2, '0')}_${TILE_ART[i]}.png`;

// ---------- Логика поля ----------
let tiles = [];      // {id,x,y,z,face,alive,el}
let selected = null, undoStack = [], combo = 0, lastMatch = 0, hintsUsed = 0, hintCharges = 3, freeShuffles = 1, startTime = 0, feverUntil = 0, curCfg = null;
const selectable = t => t.alive && !(t.ice > 0) && isFree(t, tiles) && (!window.TW?.canSelect || TW.canSelect(t));
const sameFace = (a, b) => (window.TW?.same ? TW.same(a, b) : a.face === b.face); // levels.js: цветы-группы, ключи

const isFree = (t, set) => {
  for (const o of set) {
    if (o === t || !o.alive) continue;
    if (o.z === t.z + 1 && Math.abs(o.x - t.x) < 2 && Math.abs(o.y - t.y) < 2) return false;
  }
  let left = false, right = false;
  for (const o of set) {
    if (o === t || !o.alive || o.z !== t.z || Math.abs(o.y - t.y) >= 2) continue;
    if (o.x === t.x - 2) left = true;
    if (o.x === t.x + 2) right = true;
  }
  return !(left && right);
};
const shuffleArr = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.random() * (i + 1) | 0; [a[i], a[j]] = [a[j], a[i]]; } return a; };

// Раздаёт лица так, чтобы расклад гарантированно решался: снимаем случайные свободные пары «в обратную сторону».
function assignSolvable(list, nFaces = FACES.length) {
  for (let attempt = 0; attempt < 200; attempt++) {
    list.forEach(t => (t.alive = true));
    const faces = shuffleArr([...FACES]).slice(0, nFaces);
    const order = [];
    let ok = true;
    for (let k = 0; k < list.length / 2; k++) {
      const free = list.filter(t => t.alive && isFree(t, list));
      if (free.length < 2) { ok = false; break; }
      shuffleArr(free);
      const [a, b] = free; a.alive = b.alive = false;
      const f = faces[k % faces.length]; a.face = f; b.face = f; a.step = b.step = k; order.push([a, b]);
    }
    if (ok) { list.forEach(t => (t.alive = true)); return true; }
  }
  list.forEach(t => (t.alive = true));
  return false;
}

function newGame() {
  const B = window.TW?.build?.(); // levels.js/story.js: сюжетный уровень с препятствиями
  curCfg = B ? B.cfg : levelCfg(S.level);
  const L = B ? B.layout : LAYOUTS[curCfg.layout];
  if (B) tiles = B.tiles; else {
  tiles = L.pos().map(([x, y, z], id) => ({ id, x, y, z, face: '', alive: true, ice: 0 }));
  assignSolvable(tiles, curCfg.faces);
  // Лёд: фишка тает на 1 с каждой собранной парой. Значение не больше шага, на котором фишку снимает решатель, поэтому расклад остаётся решаемым.
  shuffleArr(tiles.filter(t => t.step >= 2)).slice(0, curCfg.ice).forEach(t => (t.ice = 1 + (Math.random() * t.step | 0)));
  }
  selected = null; undoStack = []; combo = 0; hintsUsed = 0; hintCharges = 3; freeShuffles = 1; startTime = Date.now();
  if (!B && S.level === 4) setTimeout(() => say(['Новинка: ледяные фишки! Они тают с каждой парой.', 'こおり!'], true), 600);
  $('#levelInfo').textContent = B ? B.title : `Уровень ${S.level} · ${L.name}`;
  render();
  say(pick(LINES.start));
  window.TW?.afterNewGame?.();
}

// ---------- Рендер ----------
const $ = s => document.querySelector(s);
const UX = 26, UY = 33, DZ = 5;
function render() {
  const board = $('#board');
  board.innerHTML = '';
  const alive = tiles.filter(t => t.alive);
  const minX = Math.min(...tiles.map(t => t.x)), minY = Math.min(...tiles.map(t => t.y));
  for (const t of alive) {
    const el = document.createElement('div');
    el.className = 'tile ' + (isFree(t, tiles) ? 'free' : 'blocked') + (t.ice > 0 ? ' iced' : '') + (selected === t ? ' sel' : '');
    const fi = USE_TILE_ART ? FACES.indexOf(t.face) : -1;
    if (fi >= 0) { el.classList.add('art'); const im = document.createElement('i'); im.className = 'face'; im.style.backgroundImage = `url('${tileImg(fi)}')`; el.appendChild(im); }
    else el.textContent = t.face;
    if (t.ice > 0) { const b = document.createElement('span'); b.className = 'ice'; b.textContent = '❄' + t.ice; el.appendChild(b); }
    el.style.left = (t.x - minX) * UX - t.z * DZ + 10 + 'px';
    el.style.top = (t.y - minY) * UY - t.z * DZ + 10 + 'px';
    el.style.zIndex = t.z * 1000 + t.y * 20 + t.x + 50;
    el.onclick = () => clickTile(t);
    t.el = el;
    window.TW?.decorate?.(t, el);
    board.appendChild(el);
  }
  fit();
  const left = alive.length / 2;
  $('#pairsLeft').textContent = `Пар осталось: ${left}`;
  $('#combo').textContent = Date.now() < feverUntil ? `🔥 ФИВЕР ×2 💎` : combo > 1 ? `Комбо ×${combo}!` : '';
  $('#btnHint').textContent = S.vip ? '💡 Подсказка ∞' : hintCharges > 0 ? `💡 Подсказка (${hintCharges})` : '💡 Подсказка · 20💎';
  $('#btnShuffle').textContent = freeShuffles > 0 ? `🔀 Перемешать (${freeShuffles})` : '🔀 Перемешать · 30💎';
}
function fit() {
  const wrap = $('#boardWrap'), board = $('#board');
  const maxX = Math.max(...tiles.map(t => t.x)) - Math.min(...tiles.map(t => t.x));
  const maxY = Math.max(...tiles.map(t => t.y)) - Math.min(...tiles.map(t => t.y));
  const bw = maxX * UX + 48 + 30, bh = maxY * UY + 62 + 30;
  const sc = Math.min(wrap.clientWidth / bw, wrap.clientHeight / bh, 1.5);
  board.style.transform = `translate(${(wrap.clientWidth - bw * sc) / 2}px,${(wrap.clientHeight - bh * sc) / 2}px) scale(${sc})`;
}
addEventListener('resize', fit);

// ---------- Ходы ----------
function clickTile(t) {
  if (!selectable(t)) { blip(180, .05); if (t.ice > 0) say(['Это лёд! Собери ещё пары, и он растает.', 'まだだよ'], false); return; }
  if (!selected) { selected = t; blip(660, .05); render(); return; }
  if (selected === t) { selected = null; render(); return; }
  if (sameFace(selected, t)) {
    const a = selected, b = t;
    a.el.classList.add('gone'); b.el.classList.add('gone');
    a.alive = b.alive = false; selected = null;
    undoStack.push({ pair: [a, b], ice: tiles.map(x => x.ice) });
    tiles.forEach(x => { if (x.alive && x.ice > 0) x.ice--; });
    const now = Date.now(); combo = now - lastMatch < 4000 ? combo + 1 : 1; lastMatch = now;
    onMatch();
    window.TW?.onPair?.(a, b);
    setTimeout(() => { render(); checkState(); }, 300);
  } else { selected = t; blip(520, .05); render(); }
}
function onMatch() {
  if (combo >= 5 && Date.now() >= feverUntil) { feverUntil = Date.now() + 6000; document.body.classList.add('fever'); setTimeout(() => document.body.classList.remove('fever'), 6000); toast('🔥 Фивер! 6 секунд двойных 💎'); }
  S.gems += Date.now() < feverUntil ? 2 : 1; S.aff += 1; S.questPairs += 1; S.passXP += 1;
  blip(880 + combo * 60, .08); setTimeout(() => blip(1320 + combo * 60, .08), 70);
  if (combo >= 5) { heroReact('big'); say(pick(LINES.combo), true); sparkle(8); }
  else if (combo >= 3) { heroReact('react'); say(pick(LINES.combo), true); sparkle(4); }
  else if (Math.random() < .45) { heroReact('react'); say(pick(LINES.match), true); sparkle(2); }
  if (!S.questDone && S.questPairs >= 40) { S.questDone = true; S.gems += 150; toast('Задание дня выполнено: +150 💎'); }
  if (!window.TW?.aff && S.aff % 50 === 0) { toast(`Симпатия выросла до ${1 + S.aff / 50 | 0}!`); say(pick(LINES.aff), true); }
  updateHud(); save();
}
function checkState() {
  const alive = tiles.filter(t => t.alive);
  if (!alive.length) return win();
  if (!findPair()) { say('Ходов нет… давай перемешаем!', true); toast('Ходов нет. Перемешиваю бесплатно.'); setTimeout(shuffleBoard, 900); }
}
function findPair() {
  const free = tiles.filter(selectable);
  for (let i = 0; i < free.length; i++) for (let j = i + 1; j < free.length; j++) if (sameFace(free[i], free[j])) return [free[i], free[j]];
  return null;
}
function win() {
  const secs = (Date.now() - startTime) / 1000, par = tiles.length * 2.5;
  const stars = secs <= par && hintsUsed === 0 ? 3 : secs <= par * 1.6 ? 2 : 1;
  const H = window.TW?.onWin?.(stars, secs, par); // story.js: прогресс по главам, ивент, симпатия
  const reward = H ? H.reward : 40 + S.level * 5 + stars * 15;
  if (!H) { S.stars[S.level] = Math.max(S.stars[S.level] || 0, stars); S.level += 1; }
  S.gems += reward; S.passXP += 10; save(); updateHud();
  heroReact('big'); sparkle(14); say(pick(LINES.win), true);
  $('#winText').innerHTML = `<span class="stars">${'★'.repeat(stars)}${'☆'.repeat(3 - stars)}</span><br>${Math.round(secs)} с (на 3★ нужно за ${Math.round(par)} с без подсказок)<br>+${reward} 💎 · +10 очков пропуска${H && H.extra ? '<br>' + H.extra : ''}`;
  $('#winModal').classList.remove('hidden');
}
function shuffleBoard() {
  if (window.TW?.reshuffle) { TW.reshuffle(); selected = null; undoStack = []; render(); return; }
  const alive = tiles.filter(t => t.alive);
  alive.forEach(t => (t.ice = 0)); // при перемешивании лёд тает, чтобы не было тупика
  assignSolvable(alive, curCfg.faces); selected = null; undoStack = []; render();
}

const spend = n => { if (S.gems < n) { toast(`Нужно ${n} 💎`); return false; } S.gems -= n; save(); updateHud(); return true; };
$('#btnHint').onclick = () => {
  const p = findPair(); if (!p) return checkState();
  if (!S.vip) { if (hintCharges > 0) hintCharges--; else if (!spend(20)) return; }
  hintsUsed++; render(); findPair().forEach(t => t.el.classList.add('hint')); say('Вот эти две, смотри~');
};
$('#btnUndo').onclick = () => { const u = undoStack.pop(); if (!u) return; u.pair.forEach(t => (t.alive = true)); tiles.forEach((t, i) => (t.ice = u.ice[i])); window.TW?.afterUndo?.(); combo = 0; render(); };
$('#btnShuffle').onclick = () => { if (freeShuffles > 0) freeShuffles--; else if (!spend(30)) return; shuffleBoard(); };
$('#btnRestart').onclick = newGame;
$('#btnNext').onclick = () => { $('#winModal').classList.add('hidden'); newGame(); };
$('#btnSound').onclick = () => { S.sound = !S.sound; save(); $('#btnSound').textContent = S.sound ? '🔊' : '🔇'; };

// ---------- Героиня: реплики, голос, анимации ----------
// Реплика: [текст в пузыре, фраза для голоса (японский, синтез речи браузера как заглушка озвучки)]
const LINES = {
  start: [['Начнём? Я в тебя верю!', 'がんばって!'], ['Я Маджонг-тян, твоя наставница. Ищи одинаковые свободные фишки!', 'いくよ!'], ['Ну что, сыграем?', 'あそぼう!']],
  match: [['Отлично!', 'いいね!'], ['Есть пара!', 'やった!'], ['Умничка~', 'すごい!'], ['Хи-хи, легко!', 'ナイス!']],
  combo: [['Комбо! Не останавливайся!', 'コンボ!'], ['Ого, как быстро!', 'はやい!'], ['Ты в ударе!', 'すごいすごい!']],
  win: [['Победа! Ты лучший!', 'やったー!'], ['Ура! Я так рада!', 'うれしい!']],
  aff: [['Мне с тобой так весело…', 'たのしいね'], ['Спасибо, что играешь со мной!', 'ありがとう!']],
};
const pick = a => a[Math.random() * a.length | 0];
let jpVoice = null;
function loadVoice() { const v = speechSynthesis?.getVoices?.() || []; jpVoice = v.find(x => /ja/i.test(x.lang)) || null; }
if ('speechSynthesis' in window) { loadVoice(); speechSynthesis.onvoiceschanged = loadVoice; }
function say(line, voice) {
  const [txt, jp] = Array.isArray(line) ? line : [line, null];
  const b = $('#bubble'); b.textContent = txt; b.classList.remove('pop'); void b.offsetWidth; b.classList.add('pop');
  if (voice && jp && S.sound && jpVoice) {
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(jp); u.voice = jpVoice; u.lang = jpVoice.lang; u.pitch = 1.8; u.rate = 1.15; u.volume = .8;
    speechSynthesis.speak(u);
  }
}
function heroReact(kind) { const img = $('#heroImg'); img.classList.remove('react', 'big'); void img.offsetWidth; img.classList.add(kind); }
function sparkle(n) {
  const box = $('#sparkles');
  for (let i = 0; i < n; i++) {
    const s = document.createElement('span'); s.className = 'spark'; s.textContent = pick(['✨', '💖', '⭐', '🌸']);
    s.style.left = Math.random() * 90 + '%'; s.style.top = 40 + Math.random() * 50 + '%'; s.style.animationDelay = Math.random() * .3 + 's';
    box.appendChild(s); setTimeout(() => s.remove(), 1400);
  }
}
let actx;
function blip(freq, dur) {
  if (!S.sound) return;
  try {
    actx = actx || new (window.AudioContext || window.webkitAudioContext)();
    const o = actx.createOscillator(), g = actx.createGain();
    o.type = 'triangle'; o.frequency.value = freq; g.gain.setValueAtTime(.12, actx.currentTime); g.gain.exponentialRampToValueAtTime(.0001, actx.currentTime + dur + .1);
    o.connect(g).connect(actx.destination); o.start(); o.stop(actx.currentTime + dur + .12);
  } catch {}
}

// ---------- Экипировка ----------
function applyEquip() {
  const o = ITEM[S.equipped.outfit], sk = ITEM[S.equipped.skin], bg = ITEM[S.equipped.bg];
  const img = $('#heroImg');
  if (img.dataset.src !== o.img) { img.dataset.src = o.img; img.onerror = () => { img.onerror = null; img.src = FALLBACK_ART; }; img.src = o.img; }
  $('#heroName').firstChild.textContent = HEROES[o.hero] + ' ';
  $('#outfitName').textContent = `· ${o.name}`;
  document.documentElement.style.setProperty('--tile', sk.tile);
  document.documentElement.style.setProperty('--tileBack', sk.back);
  document.body.className = bg.cls + (S.vip ? ' vip' : '');
  document.body.style.backgroundImage = bg.cls === 'bg-neon' ? `linear-gradient(#120f1fcc,#120f1f99),url('${NEON_BG}')` : '';
}
function updateHud() {
  $('#gems').textContent = S.gems;
  $('#pity').textContent = 60 - S.pity;
  const lvl = 1 + (S.aff / 50 | 0);
  $('#affBar').style.width = (S.aff % 50) * 2 + '%';
  $('#affText').textContent = `Симпатия ${lvl}`;
  $('#quest').textContent = S.questDone ? '✅ Задание дня выполнено. Возвращайся завтра!' : `📜 Задание дня: собери 40 пар (${Math.min(S.questPairs, 40)}/40) → 150 💎`;
}

// ---------- Гача ----------
function rollRarity(forceSR) {
  S.pity++;
  const ssrRate = S.pity >= 60 ? 1 : S.pity > 45 ? .03 + (S.pity - 45) * .06 : .03;
  const r = Math.random();
  if (r < ssrRate) { S.pity = 0; return 'SSR'; }
  if (forceSR || r < ssrRate + .15) return 'SR';
  return 'R';
}
function pull(n) {
  const cost = n === 10 ? 900 : 100;
  if (S.gems < cost) { toast('Не хватает 💎. Пройди пару уровней!'); return; }
  S.gems -= cost;
  const res = [];
  for (let i = 0; i < n; i++) {
    const needSR = n === 10 && i === 9 && !res.some(x => x.rar !== 'R');
    const rar = rollRarity(needSR);
    const pool = ITEMS.filter(it => it.rar === rar && !it.owned); // стартовые вещи не выпадают
    const it = pick(pool);
    const dup = !!S.owned[it.id];
    if (dup) S.gems += 20; else S.owned[it.id] = true;
    res.push({ ...it, dup });
  }
  save(); updateHud(); showPull(res);
}
function showPull(res) {
  const box = $('#pullResult'); box.innerHTML = '';
  res.forEach((it, i) => {
    const c = document.createElement('div'); c.className = `card r-${it.rar}`;
    c.innerHTML = `<div class="cardInner"><div class="cardFace cardBack">🀄</div>
      <div class="cardFace cardFront">${it.img ? `<div class="thumb" style="background-image:url('${it.img}')"></div>` : `<div class="ico">${it.ico}</div>`}<div>${it.name}</div><div class="rar">${it.rar} · ${it.hero ? HEROES[it.hero] : CAT_NAME[it.cat]}</div>${it.dup ? '<div class="dup">повтор → +20 💎</div>' : '<div class="dup">новое!</div>'}</div></div>`;
    box.appendChild(c);
    setTimeout(() => { c.classList.add('flip'); blip(it.rar === 'SSR' ? 1500 : it.rar === 'SR' ? 1100 : 700, it.rar === 'SSR' ? .3 : .08); }, 400 + i * 220);
  });
  const best = res.find(r => r.rar === 'SSR') || res.find(r => r.rar === 'SR');
  if (res.some(r => r.rar === 'SSR')) { const f = document.createElement('div'); f.className = 'ssrFlash'; document.body.appendChild(f); setTimeout(() => f.remove(), 1600); }
  if (best) setTimeout(() => say(best.rar === 'SSR' ? ['Ах! Это же SSR! Надень на меня скорее!', 'すごーい!'] : ['О, редкая вещь!', 'かわいい!'], true), 400 + res.length * 220);
}
$('#pull1').onclick = () => pull(1);
$('#pull10').onclick = () => pull(10);

// ---------- Гардероб ----------
function renderWardrobe() {
  const box = $('#wardrobe'); box.innerHTML = '';
  for (const cat of ['outfit', 'skin', 'bg']) {
    const h = document.createElement('div'); h.className = 'wCat'; h.textContent = CAT_NAME[cat]; box.appendChild(h);
    const list = ITEMS.filter(i => i.cat === cat);
    for (const it of list) {
      if (cat === 'outfit' && (list.indexOf(it) === 0 || list[list.indexOf(it) - 1].hero !== it.hero)) {
        const sh = document.createElement('div'); sh.className = 'wCat'; sh.style.fontWeight = 600; sh.textContent = '— ' + HEROES[it.hero]; box.appendChild(sh);
      }
      const own = !!S.owned[it.id], eq = S.equipped[cat] === it.id;
      const d = document.createElement('div');
      d.className = 'wItem' + (own ? '' : ' locked') + (eq ? ' equipped' : '');
      d.innerHTML = `${it.img ? `<div class="thumb" style="background-image:url('${it.img}')${own ? '' : ';filter:brightness(0) opacity(.25)'}"></div>` : `<div class="ico">${own ? it.ico : '❓'}</div>`}<div>${own ? it.name : '???'}</div><small>${it.rar}${eq ? ' · надето' : ''}</small>`;
      if (own) d.onclick = () => { S.equipped[cat] = it.id; save(); applyEquip(); renderWardrobe(); if (cat === 'outfit') say(['Как я тебе?', 'どう?'], true); };
      box.appendChild(d);
    }
  }
}

// ---------- Сезонный пропуск и VIP (демо: без реальной оплаты) ----------
const PASS_STEP = 30;
const PASS = Array.from({ length: 10 }, (_, i) => ({
  free: i % 3 === 2 ? { item: ['s_mint', 'b_tea', 's_lemon'][(i / 3) | 0] } : { gems: 40 + i * 10 },
  prem: i === 4 ? { item: 'r_after' } : i === 9 ? { item: 'n_ssr' } : { gems: 120 + i * 15 },
}));
const rewardLabel = r => r.item ? `${ITEM[r.item].ico} ${ITEM[r.item].name}` : `${r.gems} 💎`;
function giveReward(r) { if (r.item) { if (S.owned[r.item]) S.gems += 20; else S.owned[r.item] = true; } else S.gems += r.gems; }
function renderPass() {
  const tier = Math.min(10, S.passXP / PASS_STEP | 0);
  $('#passInfo').textContent = `Уровень пропуска ${tier}/10 · ${S.passXP % PASS_STEP}/${PASS_STEP} очков до следующего (1 за пару, 10 за победу)`;
  $('#passPremBtn').textContent = S.passPremium ? 'Премиум-пропуск активен ✓' : 'Открыть премиум-ряд (демо, без оплаты)';
  $('#vipBtn').textContent = S.vip ? 'VIP активен ✓' : 'Включить VIP (демо, без оплаты)';
  const box = $('#passTrack'); box.innerHTML = '';
  PASS.forEach((p, i) => {
    const col = document.createElement('div'); col.className = 'pTier' + (i < tier ? ' reached' : '');
    const mk = (row, r, locked) => {
      const key = row + i, got = S.passClaimed[key];
      const b = document.createElement('button'); b.className = 'pCell ' + row + (got ? ' got' : '');
      b.innerHTML = `${rewardLabel(r)}<small>${got ? 'получено' : locked ? '🔒' : i < tier ? 'забрать' : ''}</small>`;
      b.disabled = got || locked || i >= tier;
      b.onclick = () => { giveReward(r); S.passClaimed[key] = true; save(); updateHud(); renderPass(); toast('Получено: ' + rewardLabel(r)); };
      return b;
    };
    col.innerHTML = `<div class="pNum">${i + 1}</div>`;
    col.appendChild(mk('f', p.free, false)); col.appendChild(mk('p', p.prem, !S.passPremium));
    box.appendChild(col);
  });
}
$('#passPremBtn').onclick = () => { S.passPremium = true; save(); renderPass(); };
$('#vipBtn').onclick = () => { S.vip = true; save(); renderPass(); applyEquip(); render(); toast('VIP включён: безлимит подсказок, +100 💎 в день, золотая рамка'); };

// ---------- Навигация ----------
document.querySelectorAll('nav button').forEach(b => b.onclick = () => {
  document.querySelectorAll('nav button').forEach(x => x.classList.toggle('active', x === b));
  document.querySelectorAll('.screen').forEach(s => s.classList.toggle('active', s.id === 'screen-' + b.dataset.screen));
  if (b.dataset.screen === 'wardrobe') renderWardrobe();
  if (b.dataset.screen === 'pass') renderPass();
  if (b.dataset.screen === 'play') fit();
});
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toast.h); toast.h = setTimeout(() => t.classList.remove('show'), 2600); }

// ---------- Старт ----------
{ const b = $('#bannerImg'); b.onerror = () => { b.onerror = null; b.src = FALLBACK_ART; }; b.src = BANNER_IMG; }
if (S.lastDay !== today()) { if (S.lastDay) { const g = 100 + (S.vip ? 100 : 0); S.gems += g; toast(`Ежедневный подарок: +${g} 💎${S.vip ? ' (VIP)' : ''}`); } S.lastDay = today(); }
if (S.questDay !== today()) { S.questDay = today(); S.questPairs = 0; S.questDone = false; }
$('#btnSound').textContent = S.sound ? '🔊' : '🔇';
save(); applyEquip(); updateHud(); newGame();
if ('serviceWorker' in navigator && location.protocol.startsWith('http')) navigator.serviceWorker.register('sw.js').catch(() => {});
