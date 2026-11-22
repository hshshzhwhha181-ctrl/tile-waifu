// Tile Waifu — уровни: библиотека раскладок, спецфишки и генератор раскладов с гарантированным решением.
// Подключается ДО game.js. Сам ничего не рисует: game.js зовёт хуки window.TW.* (canSelect, same, onPair, decorate, reshuffle…).
'use strict';
(function () {
const TW = window.TW = window.TW || {};

// ---------- Случайность (сидируемая для ежедневного испытания) ----------
function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const seedOf = s => { let h = 2166136261; for (const c of String(s)) h = Math.imul(h ^ c.charCodeAt(0), 16777619); return h >>> 0; };
TW.rngFor = s => mulberry32(seedOf(s));
const shuf = (a, R) => { for (let i = a.length - 1; i > 0; i--) { const j = R() * (i + 1) | 0; [a[i], a[j]] = [a[j], a[i]]; } return a; };

// ---------- Раскладки ----------
// Маска: строки через «|», «#» = фишка. Ярусы выше строятся правилами: h = со сдвигом на полфишки (опора 2×2),
// a = ровно над фишкой, у которой есть все 4 соседа, p = столбики (копия яруса), либо явная маска {o:[dx,dy], m:'…'}.
function mask(m, dx = 0, dy = 0, z = 0) {
  const out = [];
  m.split('|').forEach((row, r) => [...row].forEach((ch, c) => { if (ch === '#') out.push([dx + 2 * c, dy + 2 * r, z]); }));
  return out;
}
function stackUp(base, rules) {
  let all = [...base], cur = base;
  rules.forEach((rule, i) => {
    const z = i + 1, has = new Set(cur.map(([x, y]) => x + ',' + y)), h = (x, y) => has.has(x + ',' + y);
    let nxt = [];
    if (rule === 'h') { for (const [x, y] of cur) if (h(x + 2, y) && h(x, y + 2) && h(x + 2, y + 2)) nxt.push([x + 1, y + 1, z]); }
    else if (rule === 'a') { for (const [x, y] of cur) if (h(x - 2, y) && h(x + 2, y) && h(x, y - 2) && h(x, y + 2)) nxt.push([x, y, z]); }
    else if (rule === 'p') nxt = cur.map(([x, y]) => [x, y, z]);
    else if (typeof rule === 'object') nxt = mask(rule.m, rule.o[0], rule.o[1], z);
    all = all.concat(nxt); cur = nxt;
  });
  if (all.length % 2) { // нечётное число — убираем фишку с самого верха
    const top = Math.max(...all.map(p => p[2])); const i = all.map(p => p[2]).lastIndexOf(top); all.splice(i, 1);
  }
  return all;
}
const LAYOUTS = {
  first:    ['Первые шаги', '####|####|####', []],
  duo:      ['Две грядки', '###.###|###.###|###.###', []],
  teacup:   ['Чашка чая', '######|######|.####.|..##..', ['h']],
  ribbon:   ['Лента', '#######|.#####.|#######', ['a']],
  lantern:  ['Фонарик', '.####.|######|######|######|.####.|..##..', ['h', 'h']],
  moon:     ['Полумесяц', '..#####|.###...|###....|###....|###....|.###...|..#####', ['a']],
  heart:    ['Сердце', '.##...##.|####.####|#########|.#######.|..#####..|...###...|....#....', ['h', 'h']],
  cat:      ['Кошка', '#.......#|##.....##|#########|##.###.##|#########|.#######.|..#####..', ['a', 'h']],
  star:     ['Звезда', '....#....|...###...|#########|.#######.|..#####..|.###.###.|##.....##', ['h']],
  ladder:   ['Лестница', '##########|##########', [{ o: [4, 0], m: '########|########' }, { o: [8, 0], m: '######|######' }, { o: [12, 0], m: '####|####' }]],
  flower:   ['Цветок', '..###..|.#####.|###.###|##...##|###.###|.#####.|..###..', ['h']],
  butterfly:['Бабочка', '##.....##|###...###|####.####|#########|####.####|###...###|##.....##', ['h', 'h']],
  bridge:   ['Мост', '##########|###....###|###....###|##########', ['a', { o: [1, 1], m: '#.......#|#.......#' }]],
  cross:    ['Крест', '...###...|...###...|#########|#########|#########|...###...|...###...', ['a', 'a', 'a']],
  fan:      ['Веер', '##.##.##.##|###########|.#########.|..#######..|...#####...|....###....', ['h', 'h']],
  twins:    ['Близнецы', '####..####|####..####|####..####|####..####', ['h', 'h', 'h']],
  pagoda:   ['Пагода', '########|########|########|########|########|########', ['h', 'h', 'h']],
  arena:    ['Арена', '.########.|##......##|#..####..#|#..####..#|##......##|.########.', ['h', { o: [7, 5], m: '#' }]],
  crown:    ['Корона', '#..#..#..#|##.##.##.##|##########|##########|##########', ['a', 'h']],
  pillars:  ['Колонны', '#.#.#.#|.......|#.#.#.#|.......|#.#.#.#', ['p', 'p', 'p']],
  fortress: ['Крепость', '##########|##########|##########|##########|##########|##########', ['a', 'a', 'h']],
  dragon:   ['Дракон', '############|############|##........##|##.######.##|##.######.##|##........##|############|############', ['a', 'h']],
  chip:     ['Микросхема', '#.#.#.#.#|#########|.#######.|##.###.##|.#######.|#########|#.#.#.#.#', ['a', 'h']],
  tower:    ['Башня', '#####|#####|#####|#####|#####|#####', ['a', 'h', 'h', 'h']],
  temple:   ['Храм', '##########|##########|##########|##########|##########|##########', ['h', 'a', 'h']],
  palace:   ['Лунный дворец', '..######..|.########.|##########|##########|##########|.########.|..######..', ['h', 'a', 'h']],
  festival: ['Фестиваль', '#.##.##.##.#|############|.##########.|############|#.##.##.##.#', ['h', 'a', 'h']],
  bike:     ['Неоновый байк', '..###....###..|.#####..#####.|##############|##############|.#####..#####.|..###....###..', ['h', 'a']],
  skyline:  ['Неоновый город', '#.....#......#|##..#.##..#.##|##.####.####.#|##############|##############', ['a', 'h']],
};
const LAYOUT_POS = {};
for (const [id, [name, m, rules]] of Object.entries(LAYOUTS)) LAYOUT_POS[id] = stackUp(mask(m), rules);
TW.LAYOUTS = Object.fromEntries(Object.keys(LAYOUTS).map(id => [id, { id, name: LAYOUTS[id][0], count: LAYOUT_POS[id].length }]));
TW.layoutPos = id => LAYOUT_POS[id].map(p => p.slice());

// ---------- Описание уровней ----------
// mech: ice — ледяных фишек, flower — групп «чайных цветов», lock — цветов замков (по 2–3 замка), spark — искр,
//       hidden — доля лунных (скрытых) фишек, stone — каменных идолов, coin/heart — бонус-пар.
const CH_LAYOUTS = {
  1: ['first', 'duo', 'teacup', 'ribbon', 'first', 'lantern', 'teacup', 'moon', 'ribbon', 'heart', 'lantern', 'cat'],
  2: ['teacup', 'ribbon', 'lantern', 'moon', 'teacup', 'heart', 'flower', 'star', 'lantern', 'cat', 'flower', 'butterfly'],
  3: ['ribbon', 'star', 'ladder', 'cat', 'heart', 'bridge', 'flower', 'cross', 'ladder', 'fan', 'twins', 'arena'],
  4: ['moon', 'star', 'flower', 'cross', 'butterfly', 'heart', 'fan', 'bridge', 'crown', 'twins', 'pagoda', 'palace'],
  5: ['cat', 'butterfly', 'crown', 'pillars', 'fan', 'cross', 'dragon', 'arena', 'tower', 'twins', 'fortress', 'temple'],
  6: ['heart', 'flower', 'fan', 'crown', 'pagoda', 'bridge', 'arena', 'dragon', 'tower', 'fortress', 'palace', 'festival'],
};
// Пила сложности как в match-3: подъём, передышка, снова подъём, босс в конце главы.
const SAW = [0.0, 0.15, 0.3, 0.2, 0.45, 0.35, 0.55, 0.7, 0.5, 0.75, 0.9, 1.0];
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
function storyMech(ch, n, d) {
  const m = {};
  const k = n - 1; // 0..11
  if (ch === 1) { if (n >= 3) m.coin = n >= 8 ? 3 : 2; if (n >= 6) m.heart = 2; }
  if (ch === 2) { m.ice = Math.round(2 + 8 * d); if (n >= 5) m.flower = n >= 10 ? 2 : 1; m.coin = 2; if (k % 3 === 2) m.heart = 2; }
  if (ch === 3) { m.lock = n >= 9 ? 3 : n >= 4 ? 2 : 1; if (n >= 6) m.spark = n >= 10 ? 2 : 1; if (n >= 3) m.ice = Math.round(3 * d + 1); m.coin = 2; if (k % 3 === 1) m.heart = 2; }
  if (ch === 4) { m.hidden = 0.15 + 0.3 * d; if (n >= 6) m.stone = n >= 10 ? 3 : n >= 8 ? 2 : 1; if (n >= 4) m.lock = 1; m.coin = 2; if (k % 3 === 0) m.heart = 2; }
  if (ch === 5) { m.ice = Math.round(3 + 5 * d); m.lock = 1 + (n >= 7); m.stone = 1 + (n >= 9); m.hidden = 0.15 + 0.15 * d; if (k % 2) m.spark = 1; m.coin = 2; m.heart = 2; }
  if (ch === 6) { m.ice = Math.round(4 + 6 * d); m.lock = 1 + (n >= 5) + (n >= 10); m.stone = 1 + (n >= 8); m.hidden = 0.2 + 0.2 * d; m.flower = 1; m.spark = 1 + (n >= 9); m.coin = 3; m.heart = 2; }
  return m;
}
// Число разных рисунков: меньше — легче (больше вариантов пар), больше — сложнее.
const facesFor = (pairs, diff) => clamp(Math.round(pairs * (0.32 + 0.55 * diff)), 4, 36);

const LEVELS = [];
for (let ch = 1; ch <= 6; ch++) CH_LAYOUTS[ch].forEach((lay, i) => {
  const n = i + 1, d = SAW[i], g = (ch - 1) / 5; // g — общий прогресс по сюжету 0..1
  const pairs = LAYOUT_POS[lay].length / 2;
  LEVELS.push({ id: `${ch}-${n}`, mode: 'story', ch, n, layout: lay, boss: n === 12,
    faces: facesFor(pairs, clamp(0.15 + 0.55 * g + 0.3 * d, 0, 1)), mech: storyMech(ch, n, d) });
});
// Ивент «Неоновая ночь»: 15 уровней, неоновые фишки; «глитч» = лунные скрытые фишки, замки и искры.
const EVENT_LAYOUTS = ['chip', 'ribbon', 'star', 'bike', 'cat', 'skyline', 'chip', 'fan', 'bike', 'cross', 'twins', 'skyline', 'dragon', 'tower', 'temple'];
EVENT_LAYOUTS.forEach((lay, i) => {
  const d = i / 14, pairs = LAYOUT_POS[lay].length / 2;
  LEVELS.push({ id: `N-${i + 1}`, mode: 'event', n: i + 1, layout: lay, boss: i === 14, neon: true,
    faces: facesFor(pairs, 0.35 + 0.5 * d),
    mech: { hidden: 0.15 + 0.25 * d, lock: i >= 3 ? 1 + (i >= 9) : 0, spark: i >= 1 ? 1 + (i >= 7) : 0, stone: i >= 10 ? 1 : 0, coin: 2, chip: 3 } });
});
TW.LEVELS = LEVELS;
TW.LEVEL = Object.fromEntries(LEVELS.map(l => [l.id, l]));
TW.chapterLevels = ch => LEVELS.filter(l => l.mode === 'story' && l.ch === ch);
TW.eventLevels = () => LEVELS.filter(l => l.mode === 'event');

// Бесконечный режим после сюжета и ежедневное испытание — генерируются из номера / даты.
const BIG = ['butterfly', 'cross', 'fan', 'twins', 'pagoda', 'arena', 'crown', 'pillars', 'fortress', 'dragon', 'tower', 'temple', 'palace', 'festival', 'chip', 'bike', 'skyline'];
TW.endlessLevel = k => {
  const R = TW.rngFor('endless' + k), lay = BIG[R() * BIG.length | 0], pairs = LAYOUT_POS[lay].length / 2, d = clamp(0.5 + k / 60, 0, 1);
  return { id: `E-${k}`, mode: 'endless', n: k, layout: lay, faces: facesFor(pairs, d),
    mech: { ice: R() < .6 ? Math.round(3 + 6 * d) : 0, lock: R() < .5 ? 1 + (R() < d) : 0, stone: R() < .4 ? 1 + (R() < d) : 0, hidden: R() < .5 ? 0.2 + 0.2 * d : 0, spark: R() < .5 ? 1 : 0, flower: R() < .3 ? 1 : 0, coin: 2, heart: 1 } };
};
TW.dailyLevel = day => {
  const R = TW.rngFor('daily' + day), pool = ['heart', 'cat', 'star', 'flower', 'butterfly', 'cross', 'fan', 'crown', 'arena', 'bridge', 'twins'];
  const lay = pool[R() * pool.length | 0], pairs = LAYOUT_POS[lay].length / 2;
  const kinds = shuf(['ice', 'lock', 'stone', 'hidden', 'spark', 'flower'], R).slice(0, 2);
  const mech = { coin: 3, heart: 2 };
  for (const k of kinds) mech[k] = { ice: 6, lock: 2, stone: 2, hidden: 0.3, spark: 2, flower: 2 }[k];
  return { id: `D-${day}`, mode: 'daily', n: 0, layout: lay, faces: facesFor(pairs, 0.7), mech, seed: 'daily' + day };
};

// ---------- Генератор ----------
// Идея: проигрываем расклад вперёд, снимая случайные свободные пары, и раздаём рисунки этим парам.
// Получается последовательность, которая точно решает расклад. Все препятствия ставятся с оглядкой на «шаг» решения:
// лёд ≤ шаг фишки, ключ снимается раньше замка, камень трескается раньше, чем понадобится решению, искра горит дольше шага.
const FLOWERS = [0, 1, 2, 3, 4]; // индексы FACES: сакура, слива, хризантема, подсолнух, тюльпан
const freeIn = (t, set) => (typeof isFree === 'function' ? isFree(t, set) : true);
// Шаги снятия: stones живы, пока их hp > числа снятых пар. Возвращает список пар или null.
function solveOrder(list, R) {
  const tiles = list.filter(t => !t.stone), stones = list.filter(t => t.stone);
  if (tiles.length % 2) return null;
  for (let attempt = 0; attempt < 400; attempt++) {
    const alive = new Set(list);
    const order = [];
    let ok = true;
    for (let k = 0; k < tiles.length / 2; k++) {
      stones.forEach(s => { if (s.ice <= k) alive.delete(s); });
      const arr = [...alive];
      const view = arr.map(t => ({ t, alive: true, x: t.x, y: t.y, z: t.z }));
      const free = view.filter(v => !v.t.stone && freeIn(v, view)).map(v => v.t);
      if (free.length < 2) { ok = false; break; }
      // Вес: фишки, которые что-то накрывают или выше, снимаем охотнее — меньше тупиков у генератора.
      const w = free.map(t => 1 + t.z * 1.5 + arr.filter(o => o.z === t.z - 1 && Math.abs(o.x - t.x) < 2 && Math.abs(o.y - t.y) < 2).length);
      const pickW = excl => { let sum = 0; free.forEach((t, i) => { if (t !== excl) sum += w[i]; }); let r = R() * sum; for (let i = 0; i < free.length; i++) { if (free[i] === excl) continue; r -= w[i]; if (r <= 0) return free[i]; } return free.find(t => t !== excl); };
      const a = pickW(null), b = pickW(a);
      alive.delete(a); alive.delete(b); a.step = b.step = k; order.push([a, b]);
    }
    if (ok) return order;
  }
  return null;
}
// Раскладывает фишки в ровные ряды на нижнем ярусе — запасной вариант, если оставшаяся куча геометрически не решается.
function flatten(list) {
  const cols = Math.max(4, Math.ceil(Math.sqrt(list.length * 1.6)));
  list.forEach((t, i) => { t.x = 2 * (i % cols); t.y = 2 * (i / cols | 0); t.z = 0; });
}
function makeTiles(def) {
  return TW.layoutPos(def.layout).map(([x, y, z], id) => ({ id, x, y, z, face: '', alive: true, ice: 0 }));
}
// Строит доску уровня. opts.perks: { iceMinus } от героини.
TW.generate = function (def, opts = {}) {
  const R = def.seed ? TW.rngFor(def.seed) : Math.random;
  const M = def.mech || {};
  let stonesWanted = M.stone || 0;
  for (let tries = 0; tries < 6; tries++) {
    const tiles = makeTiles(def);
    // Камни: на нижних ярусах, число подбирается под чётность остальных фишек.
    let sCount = stonesWanted;
    if ((tiles.length - sCount) % 2) sCount = sCount ? sCount - 1 : 0;
    if ((tiles.length - sCount) % 2) sCount++;
    const pairsTotal = (tiles.length - sCount) / 2;
    shuf(tiles.filter(t => t.z <= 1), R).slice(0, sCount).forEach(t => { t.stone = true; t.ice = 2 + (R() * Math.max(1, Math.min(pairsTotal * 0.5, 10)) | 0); });
    const order = solveOrder(tiles, R);
    if (!order) { stonesWanted = Math.max(0, stonesWanted - 1); continue; }
    assignFaces(order, def, R);
    placeObstacles(tiles, order, def, R, opts);
    tiles.forEach(t => { t.alive = true; });
    return tiles;
  }
  // Совсем запасной путь (не должен срабатывать): ровная раскладка без препятствий.
  const tiles = makeTiles(def); flatten(tiles); const order = solveOrder(tiles, R); assignFaces(order, { faces: def.faces, mech: {} }, R);
  return tiles;
};
function assignFaces(order, def, R) {
  const M = def.mech || {};
  const pairs = shuf(order.slice(), R);
  const special = [];
  // Ключи: по одному на цвет замка, ставятся позже в placeObstacles (там нужен шаг), здесь резервируем пары рисунков.
  // Чайные цветы: группа = 2 пары (4 фишки) с разными цветками, любые два цветка подходят.
  const fl = M.flower || 0;
  for (let g = 0; g < fl && pairs.length > 2; g++) {
    const four = [...pairs.shift(), ...pairs.shift()], fs = shuf(FLOWERS.slice(), R);
    four.forEach((t, i) => { t.face = FACES[fs[i]]; t.grp = 'flw'; });
    special.push(four);
  }
  const pool = shuf([...Array(FACES.length).keys()].filter(i => !(fl && FLOWERS.includes(i))), R).slice(0, Math.max(2, def.faces || 8));
  pairs.forEach(([a, b], k) => { a.face = b.face = FACES[pool[k % pool.length]]; });
}
function placeObstacles(tiles, order, def, R, opts) {
  const M = def.mech || {};
  const normal = tiles.filter(t => !t.stone);
  const N = order.length;
  const used = new Set(); // фишки, на которых уже есть препятствие/бонус
  const pairFree = ([a, b]) => !used.has(a) && !used.has(b) && !a.grp;
  // Замки и ключи
  const nLock = Math.min(M.lock || 0, 3);
  for (let c = 0; c < nLock; c++) {
    const cand = shuf(normal.filter(t => t.step >= 4 && !used.has(t) && !t.grp), R);
    const locks = cand.slice(0, 2 + (R() < .5 ? 1 : 0));
    if (!locks.length) break;
    const minStep = Math.min(...locks.map(t => t.step));
    const keyPairs = order.filter(p => p[0].step < minStep && p[0].step >= Math.floor(minStep * 0.25) && pairFree(p) && !locks.includes(p[0]) && !locks.includes(p[1]));
    if (!keyPairs.length) continue;
    const kp = keyPairs[R() * keyPairs.length | 0];
    kp.forEach(t => { t.face = 'KEY' + c; t.key = c; used.add(t); });
    locks.forEach(t => { t.lock = c + 1; used.add(t); }); // lock хранится как цвет+1, чтобы 0 был «нет замка»
  }
  // Лёд: значение не больше шага, на котором решатель снимает фишку.
  const iceN = M.ice || 0, minus = opts.iceMinus || 0;
  shuf(normal.filter(t => t.step >= 2 && !used.has(t)), R).slice(0, iceN).forEach(t => {
    const v = Math.min(t.step, 1 + (R() * Math.min(t.step, 6) | 0)) - minus;
    if (v > 0) { t.ice = v; used.add(t); }
  });
  // Искры: пара, которую надо собрать до того, как будет снято deadline пар. Решение собирает её на шаге step < deadline.
  const nSpark = M.spark || 0;
  shuf(order.filter(p => p[0].step >= 2 && pairFree(p)), R).slice(0, nSpark).forEach(p => {
    const dl = p[0].step + 3 + (R() * 5 | 0); p.forEach(t => { t.spark = dl; used.add(t); });
  });
  // Бонусы: кристаллы, сердечки, неоновые чипы ивента.
  for (const [kind, cnt] of [['coin', M.coin || 0], ['heart', M.heart || 0], ['chip', M.chip || 0]])
    shuf(order.filter(pairFree), R).slice(0, cnt).forEach(p => p.forEach(t => { t.bonus = kind; used.add(t); }));
  // Лунные (скрытые) фишки: только те, что в начале закрыты. Решаемость не меняют — только прячут рисунок.
  if (M.hidden) {
    const view = tiles.map(t => ({ ...t, alive: true }));
    const closed = tiles.filter((t, i) => !t.stone && !freeIn(view[i], view) && !t.key);
    shuf(closed, R).slice(0, Math.round(normal.length * M.hidden)).forEach(t => { t.hidden = true; });
  }
}

// ---------- Правила для game.js ----------
const tilesNow = () => (typeof tiles !== 'undefined' ? tiles : []);
TW.matchedPairs = () => tilesNow().filter(t => !t.alive && !t.stone).length / 2;
TW.lockOpen = t => !t.lock || !tilesNow().some(o => o.alive && o.key === t.lock - 1);
TW.canSelect = t => !t.stone && TW.lockOpen(t);
TW.same = (a, b) => a !== b && (a.face === b.face || (!!a.grp && a.grp === b.grp));
TW.sparkLeft = t => (t.spark ? t.spark - TW.matchedPairs() : 0);
// Вызывается сразу после снятия пары (лёд и hp камней game.js уже уменьшил).
TW.onPair = function (a, b) {
  tilesNow().forEach(t => { if (t.stone && t.alive && t.ice <= 0) { t.alive = false; t.el?.classList.add('crack'); } });
  const got = { coin: 0, heart: 0, chip: 0, spark: 0, key: a.key !== undefined };
  for (const t of [a, b]) {
    if (t.bonus && !t.bonusTaken) { got[t.bonus]++; t.bonusTaken = true; }
    if (t.spark && !t.sparkTaken && t.spark - (TW.matchedPairs() - 1) > 0) { got.spark++; t.sparkTaken = true; }
  }
  if (got.spark) got.spark = 1;
  if (got.coin) got.coin = 1; if (got.heart) got.heart = 1; if (got.chip) got.chip = 1;
  TW.onReward?.(got, a, b); // story.js / meta.js начисляют награды и показывают реплики
};
TW.afterUndo = () => tilesNow().forEach(t => { if (t.stone) t.alive = t.ice > 0; });
TW.decorate = function (t, el) {
  const free = freeIn(t, tilesNow());
  if (TW.neon) { const f = el.querySelector('.face'); if (f) f.style.backgroundImage = f.style.backgroundImage.replace('/ivory/', '/neon/'); }
  const badge = (cls, txt) => { const s = document.createElement('span'); s.className = 'twb ' + cls; s.textContent = txt; el.appendChild(s); };
  if (t.stone) { el.className = 'tile tw-stone'; el.innerHTML = `<span class="twStone">🗿</span><span class="twb hp">${t.ice}</span>`; return; }
  if (t.key !== undefined) { el.classList.add('tw-key', 'k' + t.key); el.textContent = ''; const k = document.createElement('span'); k.className = 'twKey'; k.textContent = '🔑'; el.appendChild(k); }
  if (t.grp === 'flw') el.classList.add('tw-flw');
  if (t.hidden && !free) { el.classList.add('tw-hidden'); [...el.children].forEach(c => { if (!c.classList.contains('ice')) c.remove(); }); if (!el.querySelector('.ice')) el.textContent = ''; badge('moon', '☾'); }
  if (t.lock && !TW.lockOpen(t)) { el.classList.add('tw-locked', 'k' + (t.lock - 1)); badge('lock k' + (t.lock - 1), '🔒'); }
  if (t.bonus && !t.bonusTaken) badge('bonus', { coin: '💎', heart: '💗', chip: '💠' }[t.bonus]);
  const sl = TW.sparkLeft(t);
  if (t.spark && !t.sparkTaken && sl > 0) { el.classList.add('tw-spark'); badge('spark', '⏳' + sl); }
};
// Перемешивание (ручное или когда нет ходов): рисунки остаются те же, но раздаются заново по решаемой схеме.
// Лёд тает, замки открываются (ключи становятся обычной парой), камни остаются со своим hp.
TW.reshuffle = function () {
  const all = tilesNow(), alive = all.filter(t => t.alive), R = Math.random;
  alive.forEach(t => { if (!t.stone) t.ice = 0; t.lock = 0; });
  const normal = alive.filter(t => !t.stone);
  // Пары рисунков из того, что осталось: одинаковые, затем цветы друг с другом.
  const byFace = {}; normal.forEach(t => (byFace[t.face] = byFace[t.face] || []).push(t));
  const facePairs = [], odd = [];
  for (const arr of Object.values(byFace)) { while (arr.length >= 2) facePairs.push([arr.pop(), arr.pop()]); if (arr.length) odd.push(arr.pop()); }
  while (odd.length >= 2) facePairs.push([odd.pop(), odd.pop()]); // нечётные остатки (цветы) — между собой
  const kinds = facePairs.map(([a, b]) => ({ fa: a.face, fb: b.face, ga: a.grp, gb: b.grp, ka: a.key, kb: b.key, ba: a.bonus, bb: b.bonus }));
  // Камни считаются от текущего числа пар (hp уже уменьшен).
  let order = solveOrder(alive, R);
  if (!order) { flatten(alive); alive.forEach(t => { if (t.stone) { t.alive = false; } }); order = solveOrder(alive.filter(t => !t.stone), R); }
  if (!order) return false;
  shuf(kinds, R);
  order.forEach(([a, b], i) => {
    const k = kinds[i % kinds.length];
    if (k.fa !== k.fb && !k.ga) { k.fb = k.fa; } // страховка: пара всегда совпадает
    Object.assign(a, { face: k.fa, grp: k.ga, key: k.ka }); Object.assign(b, { face: k.fb, grp: k.gb, key: k.kb });
    if (a.key === undefined) delete a.key; if (b.key === undefined) delete b.key;
  });
  normal.forEach(t => { if (t.key !== undefined) { /* ключи без замков — просто пара */ } });
  return true;
};

// ---------- Проверка решаемости (для тестов и отладки) ----------
// Точная проверка: проигрывает записанное генератором решение (поле step) по правилам игры — лёд, замки, камни, свобода фишек.
TW.replayCheck = function (list) {
  const T = list.map(t => ({ ...t, alive: true }));
  const steps = {}; T.forEach(t => { if (!t.stone) (steps[t.step] = steps[t.step] || []).push(t); });
  const n = Object.keys(steps).length;
  for (let k = 0; k < n; k++) {
    const p = steps[k];
    if (!p || p.length !== 2) return 'шаг ' + k + ': нет пары';
    for (const t of p) {
      if (t.stone || t.ice > 0) return 'шаг ' + k + ': лёд ' + t.ice;
      if (t.lock && T.some(o => o.alive && o.key === t.lock - 1)) return 'шаг ' + k + ': замок';
      if (!isFree(t, T)) return 'шаг ' + k + ': фишка закрыта';
      if (t.spark && t.spark - k <= 0) return 'шаг ' + k + ': искра погасла раньше';
    }
    if (!TW.same(p[0], p[1])) return 'шаг ' + k + ': рисунки не совпадают';
    p.forEach(t => (t.alive = false));
    T.forEach(t => { if (t.alive && t.ice > 0) t.ice--; if (t.stone && t.alive && t.ice <= 0) t.alive = false; });
  }
  return T.some(t => t.alive) ? 'остались фишки' : true;
};
// Жадный решатель с откатом: ищет полный путь снятия с учётом льда, замков, камней. Возвращает true/false.
TW.verify = function (list, budget = 20000) {
  const T = list.map(t => ({ ...t }));
  let nodes = 0;
  const live = () => T.filter(t => t.alive);
  const pairs = () => {
    const al = live(), mp = T.filter(t => !t.alive && !t.stone).length / 2;
    const fr = al.filter(t => !t.stone && !(t.ice > 0) && (!t.lock || !T.some(o => o.alive && o.key === t.lock - 1)) && isFree(t, T));
    const out = [];
    for (let i = 0; i < fr.length; i++) for (let j = i + 1; j < fr.length; j++) if (TW.same(fr[i], fr[j])) out.push([fr[i], fr[j]]);
    // эвристика: сначала пары, снимающие что-то сверху/ключи
    return out.sort((p, q) => (q[0].z + q[1].z + (q[0].key !== undefined) * 5) - (p[0].z + p[1].z + (p[0].key !== undefined) * 5));
  };
  const seen = new Set();
  function dfs() {
    if (++nodes > budget) return null;
    const al = live().filter(t => !t.stone);
    if (!al.length) return true;
    const key = T.map(t => (t.alive ? 1 : 0)).join('');
    if (seen.has(key)) return false; seen.add(key);
    for (const [a, b] of pairs()) {
      const iceSnap = T.map(t => t.ice);
      a.alive = b.alive = false;
      T.forEach(t => { if (t.alive && t.ice > 0) t.ice--; if (t.stone && t.alive && t.ice <= 0) t.alive = false; });
      const r = dfs();
      if (r) return true;
      a.alive = b.alive = true; T.forEach((t, i) => { t.ice = iceSnap[i]; if (t.stone) t.alive = t.ice > 0; });
      if (r === null) return null;
    }
    return false;
  }
  return dfs();
};
})();
