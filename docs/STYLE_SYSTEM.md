# Единая система стиля — как вся будущая графика остаётся в одном стиле

Цель владельца: вся игра — дизайн, HUD, героини, будущие правки — в ОДНОМ идеальном стиле.
Три слоя «памяти стиля», которыми ОБЯЗАН пользоваться каждый агент при генерации:

## 1. Элементы-персонажи Higgsfield (идентичность героинь)
Использование: в промпте gpt_image_2_6 вставить `<<<id>>>` (Higgsfield подставит референсы сам; в medias их не класть).
| Героиня | element id |
|---|---|
| Маджонг-тян | 7df3cc78-06be-4080-87f0-49d3c1da4ff0 |
| Рин | 4d50001c-c2be-4758-a1e5-6d2c7d5f70be |
| Хана | ded72d02-6c3a-45e4-874a-0afdc3936c07 |
| Юэ | 8edeacc2-f24b-4a41-a166-66896711f259 |
| Нова | 0c657961-8e36-4535-a0c3-0059ce5df987 |
Новые богини (волна 1+) добавлять сюда же после утверждения финальных карточек (elements_create, category character, только арты без брака).

## 2. LoRA на GPU (стиль рисовки)
- `tw_heroines_v2b` (`twaifu4 style`) — героини, рецепт v4. Следующая — `tw_heroines_v3`: переобучить на расширенном одобренном наборе
  (датасет v2b + финальные карточки волны 1 + исправленные арты + витрины комбо v2 + перерисовки МТ), 3000 шагов, rank 64.
- `tw_ui_v1` (`twui style`) — интерфейс HUD v2 (обучается, воркфлоу tw-ui-lora).

## 3. Документы-правила (текстовая память)
UX_RULES.md (иерархия, имена, покупки), HUD_V2.md (плашки, типографика, макеты), ART_DIRECTION_v2.md + ROSTER_20.md §2.1 (рецепт v4),
LEGWEAR.md (ножки и горячие жесты), POSES.md (уникальные позы), HEROINES.md (красные линии), concepts/hud_v2 (эталонные макеты).

## Петля улучшения
Каждый новый одобренный ассет (после аудита) → добавляется в датасет (tools/art/captions_*, docs/concepts) и в элемент героини →
при накоплении 20–30 новых — переобучение LoRA. Брак в датасет не попадает никогда (двойной аудит анатомии).

## 4. Мастер-модель `tw_master` (вся игра в одном стиле) — HANDOFF §22, §24
**Статус (2026-11-24 23:00 UTC):** всё подготовлено, обучение отложено до пополнения кредитов (решение владельца: кредиты по приоритету 0.10).
Порядок запуска — `tools/gpu/master/RUNBOOK.md` (оценка ≈ 400–480 кр с 40 сценами, ≈ 230–300 без сцен).

- **Что это:** одна LoRA на Z-Image Turbo, которая рисует все 5 категорий игры: героини, локации, UI, фишки/столы/FX, сцены.
  Триггер — `twmaster style, <категория>, …`, категория ∈ `heroines | environments | ui | tiles_fx | scenes`.
- **Датасет v1:** 337 картинок после двойного аудита (heroines 121, environments 82, tiles_fx 61, ui 73) + 40 сцен (промпты готовы,
  `tools/art/master_scenes/scenes.json`). Подписи и MANIFEST с job id источников — `tools/art/master_captions/<категория>/`;
  картинки — архив A (HANDOFF §26), на боксе раскладываются `fetch_dataset.sh`. Подписи в git — главные: правка подписи доезжает до следующего обучения.
- **Обучение v1:** `tools/gpu/master/train_master_v1.yaml` — rank 128, 6000 шагов, lr 1e-4, adamw8bit, разрешения 512/768/1024,
  баланс повторами (heroines ×2, environments ×2, ui ×2, tiles_fx ×2, scenes ×3), чекпоинт каждые 500 шагов, все сохраняются.
- **Проверка:** 50 фиксированных промптов (`tools/gpu/master/eval_prompts.json`, ~40% близко к датасету, ~60% новое: новые богини,
  локации и экраны 0.10) на чекпоинтах 3000–6000 и на базовой модели как контроле; три оценщика и гейты — `tools/gpu/master/EVAL_RUBRIC.md`;
  до двух доработок (v2, v3) по плейбуку рубрики.

### Рецепт генерации (действует после обучения; шаг и вес — из итогов оценки)
Z-Image Turbo, 9 шагов, guidance 0, LoRA `tw_master_vN` с весом 1.0 (или 0.8, если оценщики выберут), скрипт `tools/gpu/master/gen_eval.py`
(или `tools/gpu/gen.py`). Промпт = `twmaster style, <категория>, <сюжет>, <хвост категории>`. Хвосты (из подписей датасета, не менять):
- **heroines:** `anime gacha heroine card art, cute adult Japanese gacha face with soft gradient iris, thin warm-colored lineart, soft painterly shading on a cel-shaded base, matte skin, highlights only in eyes and lips, detailed layered costume fabrics, heroine is the brightest and sharpest element, muted desaturated hazy background, no text`
- **environments:** `muted desaturated painted anime gacha background, lowered saturation and contrast, light atmospheric haze, gentle darkening toward the edges, fewer details in the distance, thin warm-colored lineart, lost edges in highlights, soft painterly shading on a cel-shaded base, matte surfaces, empty scene, no characters, no text`
- **tiles_fx:** `painted anime gacha game art, thin warm-colored lineart, soft painterly shading on a cel-shaded base, matte surfaces, restrained highlights, quiet luxurious palette of night plum, ivory, muted gold, jade green and dusty rose, soft light from the top left, no text, no logos, no people`
- **ui:** `quiet lacquer mobile game ui, near-black night background, graphite lacquer plates with one thin low-opacity gold hairline on the top edge, 4px corner radius, dusty rose pill only on the primary button with dark text, elegant high-contrast editorial serif display type, clean rounded sans ui text, cream text, grey captions, soft gold numerals, thin monoline icons, no thick frames, no outlines or shadows on text, calm expensive editorial minimalism, crisp pixel-sharp rendering`
- **scenes:** хвост heroines, но `anime gacha story CG` вместо `heroine card art` (см. подписи сцен).
Героини-основательницы описываются внешностью и именем, как в подписях датасета (элементы Higgsfield на нашем GPU не работают).
Текст в UI рисует движок, не модель: надписи в генерации — только заглушки.

### Где лежат веса
| LoRA | Триггер | Постоянный диск (/workspace) | Постоянная ссылка (cloudfront) | Статус |
|---|---|---|---|---|
| tw_heroines_v2b | `twaifu4 style` | /workspace/tw/output/tw_heroines_v2b/tw_heroines_v2b.safetensors | нет — сделать `backup_weights.sh` при следующей аренде | боевая для героинь до tw_master |
| tw_ui_v1 | `twui style` | /workspace/tw/output/tw_ui_v1/ | — (ведёт главный тред) | обучается |
| tw_master_v1 | `twmaster style` | /workspace/tw/backups/tw_master_v1/ (после обучения) | — | ждёт кредитов |
| базовая Z-Image Turbo + адаптер | — | /workspace/tw/hf_home (`cache_base.sh`) | — | кэшировать при первой аренде |
Правило: LoRA не перезаписывать, новая версия — новый номер; `backup_weights.sh` отказывается перезаписать отличающийся бэкап.
