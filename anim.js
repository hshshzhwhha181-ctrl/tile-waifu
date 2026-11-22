// Tile Waifu — анимация героинь (Higgsfield Kling 3.0): бесшовные idle-циклы нарядов и сцена гача-призыва.
// Подключается после game.js и voice.js. game.js не меняет: оборачивает applyEquip, heroReact и showPull.
'use strict';
(() => {
  // Видео-циклы для нарядов (id из ITEMS в game.js). Нет видео — показывается обычный арт.
  const IDLE = {
    o_base: 'anim/mc_base.mp4', o_tutor: 'anim/mc_tutor.mp4', o_cafe: 'anim/mc_cafe.mp4', o_dragon: 'anim/mc_dragon.mp4',
    r_base: 'anim/rin_base.mp4', r_maid: 'anim/rin_maid.mp4', r_after: 'anim/rin_after.mp4', r_agent: 'anim/rin_agent.mp4', r_idol: 'anim/rin_idol.mp4',
    h_base: 'anim/hana_base.mp4', h_street: 'anim/hana_street.mp4', h_beach: 'anim/hana_beach.mp4', h_gym: 'anim/hana_gym.mp4',
    y_base: 'anim/yue_base.mp4', y_duel: 'anim/yue_duel.mp4', y_queen: 'anim/yue_queen.mp4',
    n_base: 'anim/nova_base.mp4', n_ssr: 'anim/nova_ssr.mp4',
  };
  const SUMMON = { normal: 'anim/summon.mp4', ssr: 'anim/summon_ssr.mp4' };
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const css = `
.heroVid{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:top;opacity:0;transition:opacity .45s;pointer-events:none;transform-origin:50% 100%;border-radius:inherit}
#heroFrame.vidReady .heroVid{opacity:1}
.heroVid.react{animation:twHop .5s ease}
.heroVid.big{animation:twBig .8s ease}
#heroFrame.talking .heroVid,#heroFrame.talking #heroImg{animation:twTalk .32s ease-in-out infinite alternate}
@keyframes twHop{30%{transform:translateY(-12px) scale(1.03)}60%{transform:translateY(0) scale(.99)}}
@keyframes twBig{30%{transform:scale(1.08) rotate(-2deg)}60%{transform:scale(1.08) rotate(2deg)}}
@keyframes twTalk{to{transform:translateY(-1.5px) scale(1.008)}}
#summonFx{position:fixed;inset:0;z-index:60;display:grid;place-items:center;background:#0b0816;cursor:pointer;animation:twFadeIn .25s ease;overflow:hidden}
#summonFx video{width:100%;height:100%;object-fit:cover}
#summonFx.sr video{filter:hue-rotate(35deg) saturate(1.25)}
#summonFx::after{content:"";position:absolute;inset:0;pointer-events:none;background:radial-gradient(circle at 50% 50%,transparent 45%,#0b0816cc 100%)}
#summonFx .sfxSkip{position:absolute;bottom:max(18px,env(safe-area-inset-bottom));left:0;right:0;text-align:center;color:#fff9;font:600 13px/1 system-ui,sans-serif;letter-spacing:.06em;z-index:2;text-shadow:0 1px 4px #000}
#summonFx .sfxRar{position:absolute;top:22%;left:0;right:0;text-align:center;z-index:2;font:900 clamp(36px,9vw,84px)/1 system-ui,sans-serif;letter-spacing:.08em;color:#fff;opacity:0;text-shadow:0 0 18px #fff,0 0 42px #f5b942}
#summonFx.ssr .sfxRar{animation:twRar 1.4s 2.6s ease-out forwards;background:linear-gradient(90deg,#fff3b0,#f5b942,#ffd6f0,#9ff3ff);-webkit-background-clip:text;background-clip:text;color:transparent}
#summonFx.out{animation:twFadeOut .45s ease forwards}
#summonFx.out::before{content:"";position:absolute;inset:0;z-index:3;background:#fff;animation:twFlash .45s ease-out forwards}
@keyframes twFlash{0%{opacity:.9}100%{opacity:0}}
#summonFx.noVid{background:radial-gradient(circle,#ffd6e8 0,#7c4dff 35%,#0b0816 75%)}
#summonFx.noVid.ssr{background:radial-gradient(circle,#fff6c9 0,#f5b942 35%,#2a1606 75%)}
#summonFx.noVid:not(.out)::before{content:"";position:absolute;width:60vmin;height:60vmin;border-radius:50%;border:3px solid #fff8;box-shadow:0 0 40px #fff,inset 0 0 40px #fff;animation:twRing 1.6s ease-in infinite}
@keyframes twRing{from{transform:scale(.2) rotate(0);opacity:1}to{transform:scale(1.6) rotate(180deg);opacity:0}}
@keyframes twRar{0%{opacity:0;transform:scale(2)}40%{opacity:1;transform:scale(1)}100%{opacity:1;transform:scale(1.05)}}
@keyframes twFadeIn{from{opacity:0}}
@keyframes twFadeOut{to{opacity:0}}
@media (prefers-reduced-motion: reduce){#heroFrame.talking .heroVid,#heroFrame.talking #heroImg{animation:none}}`;
  const st = document.createElement('style'); st.id = 'animCss'; st.textContent = css; document.head.appendChild(st);

  // ---------- Idle-видео героини ----------
  const frame = document.getElementById('heroFrame');
  const img = document.getElementById('heroImg');
  let vid = null;
  if (frame && img && !reduced) {
    vid = document.createElement('video');
    vid.className = 'heroVid'; vid.muted = true; vid.loop = true; vid.playsInline = true; vid.preload = 'auto';
    vid.setAttribute('muted', ''); vid.setAttribute('playsinline', ''); vid.setAttribute('aria-hidden', 'true');
    vid.disablePictureInPicture = true;
    img.insertAdjacentElement('afterend', vid);
    vid.addEventListener('playing', () => frame.classList.add('vidReady'));
    vid.addEventListener('error', () => frame.classList.remove('vidReady'));
  }
  function syncIdle() {
    if (!vid) return;
    let id; try { id = S.equipped.outfit; } catch { return; }
    const src = IDLE[id];
    if (!src) { frame.classList.remove('vidReady'); vid.pause(); vid.removeAttribute('src'); vid.dataset.src = ''; vid.load(); return; }
    if (vid.dataset.src === src) return;
    frame.classList.remove('vidReady');
    vid.dataset.src = src; vid.src = src;
    const p = vid.play(); if (p && p.catch) p.catch(() => {});
  }
  document.addEventListener('visibilitychange', () => {
    if (!vid || !vid.dataset.src) return;
    if (document.hidden) vid.pause(); else { const p = vid.play(); if (p && p.catch) p.catch(() => {}); }
  });
  // мобильные браузеры могут не запустить autoplay до первого касания — пробуем снова
  document.addEventListener('pointerdown', () => { if (vid && vid.dataset.src && vid.paused && !document.hidden) vid.play().catch(() => {}); }, { passive: true });

  const prevApply = window.applyEquip;
  if (typeof prevApply === 'function') window.applyEquip = function () { const r = prevApply.apply(this, arguments); syncIdle(); return r; };
  const prevReact = window.heroReact;
  if (typeof prevReact === 'function') window.heroReact = function (kind) {
    const r = prevReact.apply(this, arguments);
    if (vid) { vid.classList.remove('react', 'big'); void vid.offsetWidth; vid.classList.add(kind); }
    return r;
  };

  // ---------- Сцена гача-призыва ----------
  let actx;
  function whoosh(ssr) {
    try { if (S.sound === false) return; } catch {}
    try {
      actx = actx || new (window.AudioContext || window.webkitAudioContext)();
      const t = actx.currentTime, o = actx.createOscillator(), g = actx.createGain(), f = actx.createBiquadFilter();
      o.type = 'sawtooth'; o.frequency.setValueAtTime(120, t); o.frequency.exponentialRampToValueAtTime(ssr ? 1800 : 1100, t + 3.2);
      f.type = 'lowpass'; f.frequency.setValueAtTime(400, t); f.frequency.exponentialRampToValueAtTime(5000, t + 3.4);
      g.gain.setValueAtTime(.0001, t); g.gain.exponentialRampToValueAtTime(.06, t + 2.8); g.gain.exponentialRampToValueAtTime(.0001, t + 3.8);
      o.connect(f).connect(g).connect(actx.destination); o.start(t); o.stop(t + 3.9);
      // финальный «звон»
      [0, 4, 7, 12].forEach((n, i) => {
        const oo = actx.createOscillator(), gg = actx.createGain(); const tt = t + 3.3 + i * .06;
        oo.type = 'triangle'; oo.frequency.value = (ssr ? 880 : 660) * Math.pow(2, n / 12);
        gg.gain.setValueAtTime(.08, tt); gg.gain.exponentialRampToValueAtTime(.0001, tt + 1.2);
        oo.connect(gg).connect(actx.destination); oo.start(tt); oo.stop(tt + 1.3);
      });
    } catch {}
  }
  const prevShowPull = window.showPull;
  function summon(res) {
    const ssr = res.some(r => r.rar === 'SSR'), sr = !ssr && res.some(r => r.rar === 'SR');
    const fx = document.createElement('div'); fx.id = 'summonFx'; fx.className = ssr ? 'ssr' : sr ? 'sr' : '';
    fx.setAttribute('role', 'button'); fx.setAttribute('aria-label', 'Пропустить анимацию призыва');
    fx.innerHTML = `<div class="sfxRar">SSR</div><div class="sfxSkip">Нажми, чтобы пропустить</div>`;
    let done = false;
    const finish = () => {
      if (done) return; done = true;
      fx.classList.add('out'); setTimeout(() => fx.remove(), 420);
      prevShowPull.call(window, res);
    };
    if (!reduced) {
      const v = document.createElement('video');
      v.muted = true; v.playsInline = true; v.setAttribute('playsinline', ''); v.setAttribute('muted', ''); v.preload = 'auto';
      v.src = ssr ? SUMMON.ssr : SUMMON.normal;
      v.addEventListener('ended', finish);
      v.addEventListener('error', () => { fx.classList.add('noVid'); setTimeout(finish, 1800); });
      fx.prepend(v);
      const p = v.play(); if (p && p.catch) p.catch(() => { fx.classList.add('noVid'); setTimeout(finish, 1800); });
    } else { fx.classList.add('noVid'); setTimeout(finish, 900); }
    fx.addEventListener('click', finish);
    document.body.appendChild(fx);
    setTimeout(finish, 6500); // страховка
    whoosh(ssr);
    try { window.Voice && Voice.play('gacha'); } catch {}
  }
  if (typeof prevShowPull === 'function') window.showPull = summon;

  window.Anim = { IDLE, SUMMON, syncIdle, summon };
  syncIdle();
})();
