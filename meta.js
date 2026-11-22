// Tile Waifu — мета-слой: симпатия героинь, ежедневки (календарь, задания, испытание дня) и ивент «Неоновая ночь».
// Подключается ДО game.js, состояние в S.tw. Награды только игровые (кристаллы, наряды), без реальных денег.
'use strict';
(function () {
const TW = window.TW = window.TW || {};
const $q = s => document.querySelector(s);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const day = () => new Date().toISOString().slice(0, 10);
const T = (m) => typeof toast === 'function' && toast(m);
const persist = () => typeof save === 'function' && save();
const HN = { mc: 'Маджонг-тян', rin: 'Рин', hana: 'Хана', yue: 'Юэ', nova: 'Нова' };
const HEROS = ['mc', 'rin', 'hana', 'yue', 'nova'];

// Наряды за симпатию (8-й уровень): не выпадают из гачи (флаг owned в ITEMS = «не в пуле»), выдаются только здесь.
window.TW_EXTRA_ITEMS = [
  { id: 'o_cozy',    cat: 'outfit', hero: 'mc',   rar: 'SR', name: 'Уютный вечер', ico: '🧶', img: 'art/mc_cozy.webp', owned: true, aff: true },
  { id: 'r_yukata',  cat: 'outfit', hero: 'rin',  rar: 'SR', name: 'Фестивальная юката', ico: '🎐', img: 'art/rin_yukata.webp', owned: true, aff: true },
  { id: 'h_winter',  cat: 'outfit', hero: 'hana', rar: 'SR', name: 'Зимний спорт', ico: '🏂', img: 'art/hana_winter.webp', owned: true, aff: true },
  { id: 'y_ball',    cat: 'outfit', hero: 'yue',  rar: 'SR', name: 'Лунный бал', ico: '💃', img: 'art/yue_ball.webp', owned: true, aff: true },
  { id: 'n_offline', cat: 'outfit', hero: 'nova', rar: 'SR', name: 'Офф-лайн', ico: '🎧', img: 'art/nova_offline.webp', owned: true, aff: true },
];
const AFF_OUTFIT = { mc: 'o_cozy', rin: 'r_yukata', hana: 'h_winter', yue: 'y_ball', nova: 'n_offline' };
const BASE_OUTFIT = { mc: 'o_base', rin: 'r_base', hana: 'h_base', yue: 'y_base', nova: 'n_base' };
const MEET = { mc: 'с самого начала', rin: 'в главе 2', hana: 'в главе 3', yue: 'в главе 4', nova: 'в ивенте «Неоновая ночь»' };

// ---------- Симпатия ----------
// Очки: +1 за пару, +8 за пару с сердечком, +15 за победу, +10 за 3★, +25 за подарок, выборы в сценах ×5.
const AFF_LV = [0, 40, 100, 180, 280, 400, 550, 720, 920, 1150];
const MILESTONES = {
  2: { scene: 2, label: 'Сцена «Знакомство»' },
  3: { perk: 1, label: 'Бонус героини' },
  4: { scene: 4, label: 'Сцена «Прогулка»' },
  5: { gems: 10, label: '+10% 💎 за победы с ней' },
  6: { perk: 2, label: 'Бонус героини усилен' },
  7: { scene: 7, label: 'Сцена «Откровенно»' },
  8: { outfit: 1, label: 'Эксклюзивный наряд' },
  9: { gems: 20, label: '+20% 💎 за победы с ней' },
  10: { scene: 10, label: 'Особый вечер + иллюстрация' },
};
const ensure = () => {
  const t = TW.st();
  t.aff = t.aff || { mc: 0, rin: 0, hana: 0, yue: 0, nova: 0 };
  t.cg = t.cg || {};
  t.gifts = t.gifts && t.gifts.day === day() ? t.gifts : { day: day(), n: {} };
  return t;
};
TW.aff = true; // game.js: отключает свой общий тост «Симпатия выросла»
TW.affLevel = pts => { let l = 1; AFF_LV.forEach((v, i) => { if (pts >= v) l = i + 1; }); return l; };
TW.hero = () => { try { return ITEM[S.equipped.outfit].hero; } catch { return 'mc'; } };
TW.addAff = function (h, n, quiet) {
  const t = ensure(); if (!(h in t.aff)) return;
  const before = TW.affLevel(t.aff[h]);
  t.aff[h] += n;
  const after = TW.affLevel(t.aff[h]);
  for (let lv = before + 1; lv <= after; lv++) onAffLevel(h, lv);
  if (!quiet) TW.refreshHud();
  persist();
};
function onAffLevel(h, lv) {
  const m = MILESTONES[lv] || {};
  T(`💗 ${HN[h]}: симпатия ${lv}! ${m.label || ''}`);
  window.Voice?.say?.('aff', h);
  if (m.outfit && !S.owned[AFF_OUTFIT[h]]) S.owned[AFF_OUTFIT[h]] = true;
  if (m.scene) { const id = `aff_${h}_${m.scene}`; const t = TW.st(); if (!t.seen[id] && window.TW_SCENES?.[id]) (TW.queue = TW.queue || []).push(id); setTimeout(() => TW.ready && !document.querySelector('#twVN:not(.hidden)') && TW.flushQueue(), 900); }
}
TW.unlockCg = id => { ensure().cg[id] = true; persist(); };
// Бонусы надетой героини.
TW.perks = function () {
  const t = ensure(), h = TW.hero(), lv = TW.affLevel(t.aff[h] || 0), tier = lv >= 6 ? 2 : lv >= 3 ? 1 : 0;
  const p = { hero: h, tier, gemBonus: lv >= 9 ? 0.2 : lv >= 5 ? 0.1 : 0 };
  if (!tier) return p;
  if (h === 'mc') p.hints = tier;
  if (h === 'rin') p.iceMinus = tier;
  if (h === 'hana') p.comboMs = 1000 + 1000 * tier;
  if (h === 'yue') p.shuffles = tier;
  if (h === 'nova') p.chipBonus = 0.25 * tier;
  return p;
};
const PERK_TEXT = { mc: n => `+${n} бесплатн. подсказка на уровне`, rin: n => `лёд стартует на ${n} меньше`, hana: n => `окно комбо дольше на ${1 + n} с`, yue: n => `+${n} бесплатное перемешивание`, nova: n => `+${25 * n}% неоновых чипов` };
TW.refreshHud = function () {
  const t = ensure(), h = TW.hero(), pts = t.aff[h] || 0, lv = TW.affLevel(pts);
  const lo = AFF_LV[lv - 1], hi = AFF_LV[lv] ?? lo;
  const bar = $q('#affBar'), txt = $q('#affText');
  if (bar) bar.style.width = (hi > lo ? (pts - lo) / (hi - lo) * 100 : 100) + '%';
  if (txt) txt.textContent = `💗 ${HN[h]} · симпатия ${lv}${lv < 10 ? ` (${pts - lo}/${hi - lo})` : ' · макс.'}`;
  renderQuestStrip();
};

// ---------- События поля: пары, бонус-фишки, победы ----------
TW.onReward = function (got, a, b) {
  const t = ensure(), def = TW.cur || {};
  const h = TW.hero(), p = TW.perks();
  TW.addAff(h, 1 + (got.heart ? 8 : 0), true);
  if (got.coin) { S.gems += 15; T('💎 +15 за бонус-фишки'); }
  if (got.heart) T(`💗 ${HN[h]} рада! +8 симпатии`);
  if (got.spark) { S.gems += 25; T('⏳ Искра поймана! +25 💎'); typeof sparkle === 'function' && sparkle(6); }
  if (got.key) T('🔑 Замки этого цвета открыты!');
  if (def.mode === 'event') addChips((1 + (got.chip ? 3 : 0)) * (1 + (p.chipBonus || 0)), true);
  // Хана: окно комбо длиннее — сдвигаем отметку последней пары вперёд.
  if (p.comboMs && typeof lastMatch !== 'undefined') lastMatch = Date.now() + p.comboMs;
  quest('pairs', 1);
  if (got.coin || got.heart || got.spark || got.chip) quest('bonus', 1);
  if (got.key) quest('keys', 1);
  if (typeof combo !== 'undefined' && combo >= 5) quest('combo5', 1, true);
  if (typeof updateHud === 'function') updateHud();
  TW.refreshHud();
  persist();
};
TW.onWinMeta = function (def, stars) {
  const h = TW.hero(), p = TW.perks();
  TW.addAff(h, 15 + (stars === 3 ? 10 : 0), true);
  quest('wins', 1);
  if (stars === 3) quest('stars3', 1);
  quest('hero_' + h, 1);
  let bonus = 0;
  if (p.gemBonus) { bonus = Math.round((40 + stars * 15) * p.gemBonus); S.gems += bonus; }
  TW.refreshHud();
  return `💗 ${HN[h]} +${15 + (stars === 3 ? 10 : 0)} симпатии${bonus ? ` · бонус героини +${bonus} 💎` : ''}`;
};
TW.onSceneDoneMeta = id => { if (/^nn_5$/.test(id) && !S.owned.n_base) { S.owned.n_base = true; T('Нова присоединилась! Наряд «Нетраннер» в гардеробе'); } };

// ---------- Ежедневки ----------
const QUESTS = {
  pairs:   { n: 60, t: 'Собери 60 пар', r: 60 },
  wins:    { n: 3, t: 'Пройди 3 уровня', r: 80 },
  stars3:  { n: 1, t: 'Получи 3★ на уровне', r: 70 },
  combo5:  { n: 1, t: 'Сделай комбо ×5', r: 60 },
  bonus:   { n: 6, t: 'Собери 6 бонус-пар (💎 💗 ⏳ 💠)', r: 60 },
  keys:    { n: 2, t: 'Открой замки 2 раза', r: 70 },
  gift:    { n: 1, t: 'Сделай подарок героине', r: 50 },
  daily:   { n: 1, t: 'Пройди испытание дня', r: 90 },
  hero_mc: { n: 2, t: 'Победи 2 раза с Маджонг-тян', r: 60 },
  hero_rin: { n: 2, t: 'Победи 2 раза с Рин', r: 60 },
  hero_hana: { n: 2, t: 'Победи 2 раза с Ханой', r: 60 },
  hero_yue: { n: 2, t: 'Победи 2 раза с Юэ', r: 60 },
};
const LOGIN = [{ gems: 80 }, { gems: 120 }, { chips: 40 }, { gems: 150 }, { chips: 60 }, { gems: 200 }, { gems: 300, label: 'Большой подарок' }];
const dailyState = () => {
  const t = ensure();
  if (!t.daily || t.daily.day !== day()) {
    const R = TW.rngFor('quests' + day());
    const owned = HEROS.filter(h => Object.values(S.owned).length && S.owned[BASE_OUTFIT[h]]);
    let pool = Object.keys(QUESTS).filter(k => !k.startsWith('hero_') || owned.includes(k.slice(5)));
    const pick = [];
    while (pick.length < 3 && pool.length) { const k = pool.splice(R() * pool.length | 0, 1)[0]; pick.push(k); }
    t.daily = { day: day(), quests: pick, prog: {}, claimed: {}, allClaimed: false, challenge: false };
  }
  t.login = t.login || { count: 0, last: '' };
  return t.daily;
};
function quest(k, n, setMax) {
  const d = dailyState(); if (!d.quests.includes(k)) return;
  const q = QUESTS[k], before = d.prog[k] || 0;
  d.prog[k] = setMax ? Math.max(before, n) : before + n;
  if (before < q.n && d.prog[k] >= q.n) T(`📜 Задание выполнено: ${q.t}. Забери награду в «События»`);
}
TW.onDailyWin = function (stars) {
  const d = dailyState(); quest('daily', 1);
  if (d.challenge) return 20 + stars * 5;
  d.challenge = true; TW.addAff(TW.hero(), 40, true);
  return 150 + stars * 20;
};
function renderQuestStrip() {
  const el = $q('#twQuests'); if (!el || typeof S === 'undefined') return;
  const d = dailyState();
  el.innerHTML = d.quests.map(k => { const q = QUESTS[k], p = Math.min(d.prog[k] || 0, q.n); return `<span class="${p >= q.n ? 'done' : ''}">${p >= q.n ? '✅' : '📜'} ${esc(q.t)} ${p}/${q.n}</span>`; }).join('');
}

// ---------- Ивент «Неоновая ночь» ----------
const EV_START = '2026-11-20', EV_END = '2026-12-21';
const EV_MILES = [
  { at: 100, r: { gems: 150 } }, { at: 250, r: { item: 's_neon' } }, { at: 400, r: { item: 'n_base' } },
  { at: 600, r: { item: 'b_neon' } }, { at: 800, r: { gems: 300 } }, { at: 1000, r: { gems: 500, label: 'Титул «Неоновая легенда»' } },
];
const EV_SHOP = [
  { id: 'gems', t: '120 💎', cost: 60, give: () => { S.gems += 120; } , lim: 5 },
  { id: 'pull', t: 'Билет призыва ×1', cost: 120, give: () => { S.gems += 100; TW.goScreen('gacha'); setTimeout(() => typeof pull === 'function' && pull(1), 150); }, lim: 3 },
  { id: 'gift', t: 'Подарок для Новы (+40 💗)', cost: 50, give: () => TW.addAff('nova', 40), lim: 3, need: () => S.owned.n_base },
  { id: 'skin', t: 'Скин фишек «Неон»', cost: 150, give: () => { S.owned.s_neon = true; }, lim: 1, need: () => !S.owned.s_neon },
  { id: 'bg', t: 'Фон «Неоновый город»', cost: 200, give: () => { S.owned.b_neon = true; }, lim: 1, need: () => !S.owned.b_neon },
];
TW.ev = function () {
  const t = TW.st();
  t.ev = t.ev || { play: 'N-1', cur: 'N-1', stars: {}, chips: 0, earned: 0, miles: {}, shop: {} };
  return t.ev;
};
TW.evActive = () => day() >= EV_START && day() <= EV_END;
const evDaysLeft = () => Math.max(0, Math.ceil((new Date(EV_END + 'T23:59:59') - new Date()) / 864e5));
function addChips(n, quiet) {
  const e = TW.ev(); n = Math.round(n);
  e.chips += n; e.earned += n;
  EV_MILES.forEach((m, i) => { if (e.earned >= m.at && !e.miles[i]) { e.miles[i] = 'ready'; T(`💠 Ивент: открыта награда за ${m.at} чипов!`); } });
  if (!quiet) T(`💠 +${n} неоновых чипов`);
}
TW.onEventWin = function (def, stars, first) {
  const e = TW.ev(), p = TW.perks();
  e.stars[def.id] = Math.max(e.stars[def.id] || 0, stars);
  const ids = TW.eventLevels().map(l => l.id), i = ids.indexOf(def.id);
  if (def.id === e.cur && i < ids.length - 1) e.cur = ids[i + 1];
  e.play = i < ids.length - 1 ? ids[i + 1] : def.id;
  const chips = Math.round((20 + stars * 10 + (def.boss ? 60 : 0)) * (1 + (p.chipBonus || 0)));
  addChips(chips, true);
  return { reward: first ? 40 + def.n * 4 + stars * 15 : 15 + stars * 5, text: `💠 +${chips} неоновых чипов (всего ${e.chips})` };
};
const rewardText = r => r.item ? `${ITEM[r.item].ico} ${ITEM[r.item].name}` : r.chips ? `${r.chips} 💠` : `${r.gems} 💎${r.label ? ' · ' + r.label : ''}`;
function give(r) { if (r.item) { if (S.owned[r.item]) S.gems += 50; else S.owned[r.item] = true; } if (r.gems) S.gems += r.gems; if (r.chips) addChips(r.chips, true); }

// ---------- Экран «Героини» ----------
function renderHeroes() {
  const box = $q('#screen-heroes'); if (!box) return;
  const t = ensure(), P = window.TW_PROFILES || {};
  box.innerHTML = `<h2>Героини</h2><p class="muted">Играй с героиней (надень её наряд), чтобы росла симпатия: сцены, бонусы и эксклюзивный наряд. Сейчас с тобой: <b>${HN[TW.hero()]}</b>.</p><div class="heroGrid"></div>
    <h3>Галерея иллюстраций</h3><div class="cgGrid"></div>`;
  const grid = box.querySelector('.heroGrid');
  for (const h of HEROS) {
    const met = !!S.owned[BASE_OUTFIT[h]] || (h === 'mc');
    const pts = t.aff[h] || 0, lv = TW.affLevel(pts), lo = AFF_LV[lv - 1], hi = AFF_LV[lv] ?? lo, pr = P[h] || {};
    const card = document.createElement('div'); card.className = 'heroCard' + (met ? '' : ' locked') + (TW.hero() === h ? ' current' : '');
    if (!met) { card.innerHTML = `<div class="hcImg" style="background-image:url('${'art/' + h + '_base.webp'}')"></div><div class="hcBody"><h3>???</h3><p>Встретишь ${MEET[h]}.</p></div>`; grid.appendChild(card); continue; }
    const perkTier = lv >= 6 ? 2 : lv >= 3 ? 1 : 0;
    const scenes = [2, 4, 7, 10].map(n => { const id = `aff_${h}_${n}`; const seen = TW.st().seen[id]; return `<button class="mini" ${seen ? `data-replay="${id}"` : 'disabled'}>${seen ? '💬' : '🔒'} ${n}</button>`; }).join('');
    const gifts = t.gifts.n[h] || 0;
    card.innerHTML = `<div class="hcImg" style="background-image:url('art/${h}_base.webp')"></div>
      <div class="hcBody"><h3>${HN[h]} <small>${esc(pr.title || '')}</small></h3>
      <div class="affLine"><div style="width:${hi > lo ? (pts - lo) / (hi - lo) * 100 : 100}%"></div><span>Симпатия ${lv}${lv < 10 ? ` · ${pts - lo}/${hi - lo}` : ' · макс.'}</span></div>
      <p class="bio">${esc(pr.bio || '')}</p>
      ${pr.likes ? `<p class="small">Любит: ${esc(pr.likes)}</p>` : ''}
      <p class="small">Бонус: ${perkTier ? '✅ ' + PERK_TEXT[h](perkTier) : '🔒 откроется на симпатии 3'}${lv >= 5 ? ` · +${lv >= 9 ? 20 : 10}% 💎 за победы` : ''}</p>
      <div class="miles">${Object.entries(MILESTONES).map(([l, m]) => `<span class="${lv >= +l ? 'ok' : ''}" title="${esc(m.label)}">${l}</span>`).join('')}</div>
      <div class="hcBtns">
        <button data-equip="${h}">${TW.hero() === h ? '✓ Играем вместе' : 'Играть с ней'}</button>
        <button data-gift="${h}" ${gifts >= 2 ? 'disabled' : ''}>🎁 ${esc(pr.gift || 'Подарок')} · 60 💎 (${2 - gifts}/2)</button>
      </div>
      <div class="hcScenes">Сцены: ${scenes}</div></div>`;
    grid.appendChild(card);
  }
  grid.querySelectorAll('[data-replay]').forEach(b => b.onclick = () => TW.playScenes([b.dataset.replay], null, { replay: true }));
  grid.querySelectorAll('[data-equip]').forEach(b => b.onclick = () => {
    const h = b.dataset.equip; if (TW.hero() === h) return;
    const own = ITEMS.filter(i => i.cat === 'outfit' && i.hero === h && S.owned[i.id]);
    if (!own.length) return;
    S.equipped.outfit = own[own.length - 1].id; persist(); typeof applyEquip === 'function' && applyEquip(); renderHeroes(); TW.refreshHud();
    T(`Теперь с тобой играет ${HN[h]}`);
  });
  grid.querySelectorAll('[data-gift]').forEach(b => b.onclick = () => {
    const h = b.dataset.gift, t2 = ensure();
    if ((t2.gifts.n[h] || 0) >= 2) return;
    if (S.gems < 60) return T('Нужно 60 💎');
    S.gems -= 60; t2.gifts.n[h] = (t2.gifts.n[h] || 0) + 1; quest('gift', 1);
    const lines = (P[h] || {}).giftLines || [];
    const line = lines[Math.random() * lines.length | 0];
    TW.addAff(h, 25);
    if (line) TW.playScenes(['__gift'], null, { replay: true, scene: line });
    typeof updateHud === 'function' && updateHud(); renderHeroes();
  });
  const cg = box.querySelector('.cgGrid');
  cg.innerHTML = Object.entries(TW.CGS || {}).map(([id, src]) => t.cg[id] ? `<button class="cg" data-cg="${id}" style="background-image:url('${src}')"></button>` : `<div class="cg locked">🔒</div>`).join('');
  cg.querySelectorAll('[data-cg]').forEach(b => b.onclick = () => { window.TW_SCENES.__cg = { lines: [{ cg: b.dataset.cg }, ['', '', '…'], { cg: null }] }; TW.playScenes(['__cg'], null, { replay: true }); });
}
// Подарок: короткая сцена из одной реплики.
const _play = TW.playScenes;
TW.playScenes = function (ids, done, opts = {}) {
  if (opts.scene) { window.TW_SCENES.__gift = { lines: [opts.scene], bg: null, tip: true }; }
  return _play(ids, done, opts);
};

// ---------- Экран «События»: календарь, задания, испытание, ивент ----------
function renderEvents() {
  const box = $q('#screen-events'); if (!box || typeof S === 'undefined') return;
  const t = ensure(), d = dailyState(), e = TW.ev(), EVT = window.TW_EVENT || { title: 'Неоновая ночь', blurb: '' };
  const canLogin = t.login.last !== day();
  const li = t.login.count % 7;
  const allDone = d.quests.every(k => d.claimed[k]);
  const evLv = TW.eventLevels();
  box.innerHTML = `
  <div class="evGrid">
    <div class="panel"><h3>🗓 Календарь входа</h3><div class="login">${LOGIN.map((r, i) => `<div class="lday${i < li || (i === li && !canLogin) ? ' got' : ''}${i === li && canLogin ? ' now' : ''}"><b>День ${i + 1}</b>${rewardText(r)}</div>`).join('')}</div>
      <button class="primary" id="twLogin" ${canLogin ? '' : 'disabled'}>${canLogin ? 'Забрать подарок дня' : 'Получено, приходи завтра'}</button></div>
    <div class="panel"><h3>📜 Задания дня</h3>${d.quests.map(k => { const q = QUESTS[k], p = Math.min(d.prog[k] || 0, q.n); return `<div class="qrow"><span>${esc(q.t)} <small>${p}/${q.n}</small></span><button data-q="${k}" ${p >= q.n && !d.claimed[k] ? '' : 'disabled'}>${d.claimed[k] ? '✓' : `${q.r} 💎${TW.evActive() ? ' +15 💠' : ''}`}</button></div>`; }).join('')}
      <div class="qrow"><span>Все три задания</span><button id="twQAll" ${allDone && !d.allClaimed ? '' : 'disabled'}>${d.allClaimed ? '✓' : '100 💎'}</button></div></div>
    <div class="panel"><h3>⚡ Испытание дня</h3><p>Особая раскладка с двумя препятствиями, новая каждый день. Первая победа: 150 💎+ и +40 симпатии.</p>
      <button class="primary" data-mode="daily">${d.challenge ? 'Пройдено ✓ · сыграть ещё' : 'Играть'}</button></div>
  </div>
  <div class="panel neonPanel" style="background-image:linear-gradient(90deg,#120f1fee 30%,#120f1f88),url('art/bg_neon.webp')">
    <h2>💠 ${esc(EVT.title)}</h2><p>${esc(EVT.blurb || '')}</p>
    <p class="small">${TW.evActive() ? `До конца ивента: ${evDaysLeft()} дн.` : 'Ивент завершён'} · Неоновые чипы: <b>${e.chips} 💠</b> (заработано всего ${e.earned})</p>
    <div class="evLevels">${evLv.map(l => { const open = TW.eventLevels().findIndex(x => x.id === l.id) <= TW.eventLevels().findIndex(x => x.id === e.cur); const s = e.stars[l.id] || 0;
      return `<button class="enode${open ? '' : ' locked'}${l.id === e.cur ? ' cur' : ''}${l.boss ? ' boss' : ''}" data-ev="${l.id}" ${open && TW.evActive() ? '' : 'disabled'}><b>${l.boss ? '👑' : l.n}</b><span>${open ? '★'.repeat(s) + '☆'.repeat(3 - s) : '🔒'}</span></button>`; }).join('')}</div>
    <h3>Награды за чипы</h3><div class="miles2">${EV_MILES.map((m, i) => `<div class="mile${e.miles[i] === 'got' ? ' got' : e.miles[i] ? ' ready' : ''}"><b>${m.at} 💠</b><span>${rewardText(m.r)}</span>${e.miles[i] === 'ready' ? `<button data-mile="${i}">Забрать</button>` : e.miles[i] === 'got' ? '<small>получено</small>' : ''}</div>`).join('')}</div>
    <h3>Неоновая лавка</h3><div class="shop">${EV_SHOP.filter(s => !s.need || s.need()).map(s => { const n = e.shop[s.id] || 0; return `<button data-shop="${s.id}" ${n >= s.lim || e.chips < s.cost ? 'disabled' : ''}>${esc(s.t)}<small>${s.cost} 💠 · ${s.lim - n}/${s.lim}</small></button>`; }).join('')}</div>
    <div class="evScenes">${['nn_1', 'nn_2', 'nn_3', 'nn_4', 'nn_5'].filter(id => TW.st().seen[id]).map((id, i) => `<button class="mini" data-replay="${id}">💬 Эпизод ${i + 1}</button>`).join('')}</div>
  </div>`;
  const re = () => { persist(); typeof updateHud === 'function' && updateHud(); renderEvents(); };
  box.querySelector('#twLogin')?.addEventListener('click', () => { const r = LOGIN[t.login.count % 7]; give(r); t.login.count++; t.login.last = day(); T('Подарок дня: ' + rewardText(r)); re(); });
  box.querySelectorAll('[data-q]').forEach(b => b.onclick = () => { const k = b.dataset.q; d.claimed[k] = true; S.gems += QUESTS[k].r; if (TW.evActive()) addChips(15, true); T(`+${QUESTS[k].r} 💎`); re(); });
  box.querySelector('#twQAll')?.addEventListener('click', () => { d.allClaimed = true; S.gems += 100; T('Все задания дня: +100 💎'); re(); });
  box.querySelectorAll('[data-mode]').forEach(b => b.onclick = () => TW.startLevel(b.dataset.mode));
  box.querySelectorAll('[data-ev]').forEach(b => b.onclick = () => TW.startLevel('event', b.dataset.ev));
  box.querySelectorAll('[data-mile]').forEach(b => b.onclick = () => { const i = +b.dataset.mile; give(EV_MILES[i].r); e.miles[i] = 'got'; T('Получено: ' + rewardText(EV_MILES[i].r)); re(); });
  box.querySelectorAll('[data-shop]').forEach(b => b.onclick = () => {
    const s = EV_SHOP.find(x => x.id === b.dataset.shop); if (e.chips < s.cost) return;
    e.chips -= s.cost; e.shop[s.id] = (e.shop[s.id] || 0) + 1; s.give();
    const sl = (window.TW_EVENT?.shopLines || []); if (sl.length && typeof say === 'function') say(sl[Math.random() * sl.length | 0][2]);
    T('Куплено: ' + s.t); re();
  });
  box.querySelectorAll('[data-replay]').forEach(b => b.onclick = () => TW.playScenes([b.dataset.replay], null, { replay: true }));
}

TW.addScreen('heroes', 'Героини', renderHeroes);
TW.addScreen('events', 'События', renderEvents);
document.addEventListener('DOMContentLoaded', () => {
  // Полоска заданий дня под полем.
  const q = $q('#quest');
  if (q && !$q('#twQuests')) { const d = document.createElement('div'); d.id = 'twQuests'; q.parentNode.insertBefore(d, q.nextSibling); }
  TW.refreshHud();
  // Красная точка на «События», если есть что забрать.
  const dot = () => { const b = document.querySelector('nav [data-screen="events"]'); if (!b || typeof S === 'undefined') return;
    const t = ensure(), d = dailyState(), e = TW.ev();
    const has = t.login.last !== day() || d.quests.some(k => !d.claimed[k] && (d.prog[k] || 0) >= QUESTS[k].n) || Object.values(e.miles).includes('ready');
    b.classList.toggle('tw-dot', has); };
  dot(); setInterval(dot, 3000);
});
})();
