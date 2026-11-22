// Оффлайн-кэш: все файлы игры, включая арт, кладутся в кэш при установке.
const C = 'tilewaifu-v6';
const CORE = ['./', 'index.html', 'style.css', 'game.js', 'manifest.webmanifest', 'icon.svg'];
// Весь арт лежит локально в art/ и кладётся в кэш при установке — игра целиком работает без сети.
const ART_FILES = [
  'art/banner_neon.webp',
  'art/bg_neon.webp',
  'art/hana_base.webp',
  'art/hana_beach.webp',
  'art/hana_gym.webp',
  'art/hana_street.webp',
  'art/icons/calendar.png',
  'art/icons/coin.png',
  'art/icons/gem.png',
  'art/icons/gift.png',
  'art/icons/heart.png',
  'art/icons/hint.png',
  'art/icons/home.png',
  'art/icons/mail.png',
  'art/icons/settings.png',
  'art/icons/shuffle.png',
  'art/icons/sound.png',
  'art/icons/star.png',
  'art/icons/ticket.png',
  'art/icons/trophy.png',
  'art/icons/undo.png',
  'art/icons/wardrobe.png',
  'art/keyart.webp',
  'art/logo.webp',
  'art/mc_base.webp',
  'art/mc_cafe.webp',
  'art/mc_dragon.webp',
  'art/mc_tutor.webp',
  'art/nova_base.webp',
  'art/nova_ssr.webp',
  'art/rin_after.webp',
  'art/rin_agent.webp',
  'art/rin_base.webp',
  'art/rin_idol.webp',
  'art/rin_maid.webp',
  'art/style_b.webp',
  'art/style_c.webp',
  'art/style_d.webp',
  'art/tiles/ivory/00_sakura.png',
  'art/tiles/ivory/01_plum.png',
  'art/tiles/ivory/02_chrysanthemum.png',
  'art/tiles/ivory/03_sunflower.png',
  'art/tiles/ivory/04_tulip.png',
  'art/tiles/ivory/05_clover.png',
  'art/tiles/ivory/06_maple.png',
  'art/tiles/ivory/07_moon.png',
  'art/tiles/ivory/08_star.png',
  'art/tiles/ivory/09_sun.png',
  'art/tiles/ivory/10_rainbow.png',
  'art/tiles/ivory/11_snowflake.png',
  'art/tiles/ivory/12_fire.png',
  'art/tiles/ivory/13_water.png',
  'art/tiles/ivory/14_lightning.png',
  'art/tiles/ivory/15_dango.png',
  'art/tiles/ivory/16_cake.png',
  'art/tiles/ivory/17_strawberry.png',
  'art/tiles/ivory/18_peach.png',
  'art/tiles/ivory/19_cherry.png',
  'art/tiles/ivory/20_lemon.png',
  'art/tiles/ivory/21_matcha.png',
  'art/tiles/ivory/22_bubbletea.png',
  'art/tiles/ivory/23_bow.png',
  'art/tiles/ivory/24_diamond.png',
  'art/tiles/ivory/25_crown.png',
  'art/tiles/ivory/26_bell.png',
  'art/tiles/ivory/27_windchime.png',
  'art/tiles/ivory/28_lantern.png',
  'art/tiles/ivory/29_cat.png',
  'art/tiles/ivory/30_rabbit.png',
  'art/tiles/ivory/31_fox.png',
  'art/tiles/ivory/32_panda.png',
  'art/tiles/ivory/33_dragon.png',
  'art/tiles/ivory/34_koi.png',
  'art/tiles/ivory/35_butterfly.png',
  'art/tiles/neon/00_sakura.png',
  'art/tiles/neon/01_plum.png',
  'art/tiles/neon/02_chrysanthemum.png',
  'art/tiles/neon/03_sunflower.png',
  'art/tiles/neon/04_tulip.png',
  'art/tiles/neon/05_clover.png',
  'art/tiles/neon/06_maple.png',
  'art/tiles/neon/07_moon.png',
  'art/tiles/neon/08_star.png',
  'art/tiles/neon/09_sun.png',
  'art/tiles/neon/10_rainbow.png',
  'art/tiles/neon/11_snowflake.png',
  'art/tiles/neon/12_fire.png',
  'art/tiles/neon/13_water.png',
  'art/tiles/neon/14_lightning.png',
  'art/tiles/neon/15_dango.png',
  'art/tiles/neon/16_cake.png',
  'art/tiles/neon/17_strawberry.png',
  'art/tiles/neon/18_peach.png',
  'art/tiles/neon/19_cherry.png',
  'art/tiles/neon/20_lemon.png',
  'art/tiles/neon/21_matcha.png',
  'art/tiles/neon/22_bubbletea.png',
  'art/tiles/neon/23_bow.png',
  'art/tiles/neon/24_diamond.png',
  'art/tiles/neon/25_crown.png',
  'art/tiles/neon/26_bell.png',
  'art/tiles/neon/27_windchime.png',
  'art/tiles/neon/28_lantern.png',
  'art/tiles/neon/29_cat.png',
  'art/tiles/neon/30_rabbit.png',
  'art/tiles/neon/31_fox.png',
  'art/tiles/neon/32_panda.png',
  'art/tiles/neon/33_dragon.png',
  'art/tiles/neon/34_koi.png',
  'art/tiles/neon/35_butterfly.png',
  'art/yue_base.webp',
  'art/yue_duel.webp',
  'art/yue_queen.webp',
];
// Сюжет, уровни, симпатия и ивент (тред сюжета)
CORE.push('levels.js', 'story_main.js', 'story_side.js', 'story.js', 'meta.js', 'content.css');
ART_FILES.push(
  'art/scenes/mc_vn.webp', 'art/scenes/rin_vn.webp', 'art/scenes/hana_vn.webp', 'art/scenes/yue_vn.webp', 'art/scenes/nova_vn.webp',
  'art/scenes/bg_parlor.webp',
  'art/scenes/bg_teahouse.webp',
  'art/scenes/bg_gym.webp',
  'art/scenes/bg_palace.webp',
  'art/scenes/bg_shrine.webp',
  'art/scenes/bg_festival.webp',
  'art/scenes/bg_rooftop.webp',
  'art/scenes/bg_street.webp',
  'art/scenes/map_town.webp',
  'art/scenes/cg_mc.webp',
  'art/scenes/cg_rin.webp',
  'art/scenes/cg_hana.webp',
  'art/scenes/cg_yue.webp',
  'art/scenes/cg_nova.webp',
  'art/scenes/cg_finale.webp',
  'art/mc_cozy.webp',
  'art/rin_yukata.webp',
  'art/hana_winter.webp',
  'art/yue_ball.webp',
  'art/nova_offline.webp',
);
// Интерфейс (ui-тред): стили, эффекты, шрифты, фоны сцен и иконки приложения.
CORE.push('ui.css', 'ui.js',
  'fonts/nunito-cyr.woff2', 'fonts/nunito-lat.woff2', 'fonts/playfair-i-cyr.woff2', 'fonts/playfair-i-lat.woff2',
  'art/ui/bg_menu.webp', 'art/ui/bg_menu_wide.webp', 'art/ui/bg_table.webp', 'art/ui/bg_summon.webp', 'art/ui/bg_victory.webp',
  'art/ui/card_back.webp', 'art/ui/mc_cut.webp', 'art/ui/logo_gold.webp',
  'art/ui/icon-180.png', 'art/ui/icon-192.png', 'art/ui/icon-512.png', 'art/ui/icon-maskable-512.png');
// Голоса и анимация героинь (тред озвучки): voice.js, anim.js, 80 японских реплик и 14 видеоклипов.
CORE.push('voice.js', 'anim.js',
  'audio/hana_aff1.mp3', 'audio/hana_combo1.mp3', 'audio/hana_combo2.mp3', 'audio/hana_fever1.mp3', 'audio/hana_gacha1.mp3', 'audio/hana_greet1.mp3', 'audio/hana_greet2.mp3', 'audio/hana_hint1.mp3', 'audio/hana_lose1.mp3', 'audio/hana_match1.mp3', 'audio/hana_match2.mp3', 'audio/hana_match3.mp3', 'audio/hana_outfit1.mp3', 'audio/hana_ssr1.mp3', 'audio/hana_win1.mp3', 'audio/hana_win2.mp3', 'audio/mc_aff1.mp3', 'audio/mc_combo1.mp3', 'audio/mc_combo2.mp3', 'audio/mc_fever1.mp3', 'audio/mc_gacha1.mp3', 'audio/mc_greet1.mp3', 'audio/mc_greet2.mp3', 'audio/mc_hint1.mp3', 'audio/mc_lose1.mp3', 'audio/mc_match1.mp3', 'audio/mc_match2.mp3', 'audio/mc_match3.mp3', 'audio/mc_outfit1.mp3', 'audio/mc_ssr1.mp3', 'audio/mc_win1.mp3', 'audio/mc_win2.mp3', 'audio/nova_aff1.mp3', 'audio/nova_combo1.mp3', 'audio/nova_combo2.mp3', 'audio/nova_fever1.mp3', 'audio/nova_gacha1.mp3', 'audio/nova_greet1.mp3', 'audio/nova_greet2.mp3', 'audio/nova_hint1.mp3', 'audio/nova_lose1.mp3', 'audio/nova_match1.mp3', 'audio/nova_match2.mp3', 'audio/nova_match3.mp3', 'audio/nova_outfit1.mp3', 'audio/nova_ssr1.mp3', 'audio/nova_win1.mp3', 'audio/nova_win2.mp3', 'audio/rin_aff1.mp3', 'audio/rin_combo1.mp3', 'audio/rin_combo2.mp3', 'audio/rin_fever1.mp3', 'audio/rin_gacha1.mp3', 'audio/rin_greet1.mp3', 'audio/rin_greet2.mp3', 'audio/rin_hint1.mp3', 'audio/rin_lose1.mp3', 'audio/rin_match1.mp3', 'audio/rin_match2.mp3', 'audio/rin_match3.mp3', 'audio/rin_outfit1.mp3', 'audio/rin_ssr1.mp3', 'audio/rin_win1.mp3', 'audio/rin_win2.mp3', 'audio/yue_aff1.mp3', 'audio/yue_combo1.mp3', 'audio/yue_combo2.mp3', 'audio/yue_fever1.mp3', 'audio/yue_gacha1.mp3', 'audio/yue_greet1.mp3', 'audio/yue_greet2.mp3', 'audio/yue_hint1.mp3', 'audio/yue_lose1.mp3', 'audio/yue_match1.mp3', 'audio/yue_match2.mp3', 'audio/yue_match3.mp3', 'audio/yue_outfit1.mp3', 'audio/yue_ssr1.mp3', 'audio/yue_win1.mp3', 'audio/yue_win2.mp3',
  'anim/hana_base.mp4', 'anim/hana_gym.mp4', 'anim/mc_base.mp4', 'anim/mc_dragon.mp4', 'anim/nova_base.mp4', 'anim/nova_ssr.mp4', 'anim/rin_agent.mp4', 'anim/rin_base.mp4', 'anim/rin_idol.mp4', 'anim/summon.mp4', 'anim/summon_ssr.mp4', 'anim/yue_base.mp4', 'anim/yue_duel.mp4', 'anim/yue_queen.mp4',
  'anim/mc_tutor.mp4', 'anim/mc_cafe.mp4', 'anim/rin_maid.mp4', 'anim/rin_after.mp4', 'anim/hana_street.mp4', 'anim/hana_beach.mp4');
CORE.push(...ART_FILES);
self.addEventListener('install', e => e.waitUntil(caches.open(C).then(c => c.addAll(CORE)).then(() => self.skipWaiting())));
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  if (e.request.headers.get('range')) return e.respondWith(rangeFromCache(e.request)); // видео в Safari просит диапазоны
  e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request).then(res => {
    const copy = res.clone(); caches.open(C).then(c => c.put(e.request, copy)); return res;
  }).catch(() => hit)));
});
// Ответ 206 на Range-запросы видео/аудио из кэша (Safari иначе не играет офлайн-видео)
async function rangeFromCache(req) {
  const hit = await caches.match(req.url);
  if (!hit) return fetch(req);
  const buf = await hit.arrayBuffer(), size = buf.byteLength;
  const m = /bytes=(\d*)-(\d*)/.exec(req.headers.get('range') || '');
  let start = m && m[1] ? +m[1] : 0, end = m && m[2] ? +m[2] : size - 1;
  if (m && !m[1] && m[2]) { start = size - +m[2]; end = size - 1; }
  end = Math.min(end, size - 1);
  return new Response(buf.slice(start, end + 1), { status: 206, headers: {
    'Content-Type': hit.headers.get('Content-Type') || 'application/octet-stream',
    'Content-Range': `bytes ${start}-${end}/${size}`, 'Content-Length': String(end - start + 1), 'Accept-Ranges': 'bytes' } });
}
