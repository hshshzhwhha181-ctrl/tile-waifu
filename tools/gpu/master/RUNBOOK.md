# Мастер-модель стиля `tw_master_v1` — ранбук запуска (HANDOFF §22, §24)

Всё, что не стоит кредитов, готово заранее: подписи 337 картинок (`tools/art/master_captions`), 40 промптов сцен
(`tools/art/master_scenes/scenes.json`), конфиг обучения, скрипты бокса, тест из 50 промптов и критерии трёх оценщиков
(`tools/gpu/master/eval_prompts.json`, `EVAL_RUBRIC.md`). Ниже — порядок действий, когда главный тред выделит кредиты.
Ветка с китом: `gh-pages` после вливания, до него `claude/project-thread-ugde4m` (переменная `KIT_BRANCH`).

## 0. Бюджет (оценка, уточняется по скорости шага на 100-м шаге)

| Шаг | Как | Кредиты |
|---|---|---|
| Сцены, 40 шт. | gpt_image_2_6, high, 2k, по 2 варианта = 80 картинок × 2 кр | ~160 (+~15 на перегенерацию брака) |
| GPU: установка, кэш, латенты | 15–20 мин | 20–45 |
| GPU: обучение 6000 шагов, rank 128, 512/768/1024 | L40S ≈ 2,5–3,5 ч / H200 ≈ 1–1,5 ч | L40S ~180–250 / H200 ~135–200 |
| GPU: тест 50 промптов × 4–6 вариантов | L40S ≈ 30 мин / H200 ≈ 12 мин | 25–35 |
| Итого v1 | | **≈ 400–480** |
| Экономный вариант | v1 без сцен (сцены — только если оценщики попросят в v2), ранняя остановка по промежуточному тесту | ≈ 230–300 |

H200 (134 кр/ч) выгоднее L40S (71 кр/ч) не по цене часа, а по возможности гонять тест промежуточных чекпоинтов
**параллельно** с обучением (141 ГБ памяти) и остановить обучение, как только чекпоинт прошёл гейты.

## 1. Сцены (Higgsfield, без GPU)

1. Прочитать `tools/art/master_scenes/scenes.json` (40 сцен: промпт, соотношение сторон, элементы основательниц `<<<id>>>`,
   стилевые референсы — job id из MANIFEST датасета, подпись, на что смотреть аудиторам).
2. `generate_image_batch` пачками по 12: `{"model":"gpt_image_2_6","prompt":…,"aspect_ratio":…,"quality":"high","resolution":"2k",
   "medias":[{"role":"image_references","value":<style_ref job id>}…]}` — два элемента запроса на сцену (варианты 1 и 2). `jobs_wait` по 12.
3. `python3 tools/art/master_scenes/collect.py download jobs.json <scratch>/scenes_raw` → двойной аудит анатомии: два независимых
   агента на картинку (пальцы/руки/ноги по кропам, взрослое лицо, без текста, красные линии HEROINES.md, совпадение с подписью).
   Проходит вариант, который оба признали чистым; если оба варианта брак — одна перегенерация с поправленным промптом.
4. `python3 tools/art/master_scenes/collect.py finalize scenes.json selection.json` → `tools/art/master_captions/scenes/` (подписи +
   MANIFEST.tsv со ссылками). Подпись поправить под реальную картинку. Закоммитить и запушить: бокс берёт подписи из git.

## 2. GPU-бокс

Перед арендой: `gpu_my` — не трогать чужие боксы (UI-LoRA ведёт главный тред). `/workspace` общий для всех боксов,
наши пути: `/workspace/tw/{kit,data/master_v1,output/tw_master_v*,eval,backups,hf_home,logs}`; кэш базовой модели —
общий `/workspace/tw/base_models` главного треда (`hf_env.sh` находит его сам, повторно 20+ ГБ не качаем).

1. `gpu_rent` (H200 или L40S, `auto_pause_minutes: 60`), `gpu_rental` до статуса working.
2. Кит (одна команда `gpu_rental_exec`):
   ```
   B=claude/project-thread-ugde4m; mkdir -p /workspace/tw/logs && cd /workspace/tw && rm -rf kit && git clone -q --depth 1 --filter=blob:none --sparse -b $B https://github.com/hshshzhwhha181-ctrl/tile-waifu.git kit && cd kit && git sparse-checkout set tools/gpu tools/art/master_captions tools/art/master_scenes && ls tools/gpu/master
   ```
3. Параллельно в фоне (каждая — отдельный `gpu_rental_exec`, всё идемпотентно, в конце строка *_OK):
   ```
   nohup bash /workspace/tw/kit/tools/gpu/master/box_setup.sh > /workspace/tw/logs/setup.log 2>&1 &
   nohup bash /workspace/tw/kit/tools/gpu/master/fetch_dataset.sh > /workspace/tw/logs/dataset.log 2>&1 &
   ```
   После `SETUP_OK`: `nohup bash /workspace/tw/kit/tools/gpu/master/cache_base.sh > /workspace/tw/logs/cache.log 2>&1 &` (нужен huggingface_hub).
   Ожидаемо в `dataset.log`: heroines 121, environments 82, tiles_fx 61, ui 73, scenes 40 (если сцены готовы).
4. Обучение после `SETUP_OK`, `DATASET_OK`, `CACHE_OK`: `bash /workspace/tw/kit/tools/gpu/master/run_train.sh`
   (переопределения через переменные — см. шапку скрипта). Лог: `tail -c 3000 /workspace/tw/logs/tw_master_v1.log`.
   На ~100-м шаге записать сек/шаг и пересчитать бюджет. Если не укладываемся — перезапуск с `STEPS=4000` (resume сохранит шаги).
   Остановка только `kill $(cat /workspace/tw/logs/tw_master_v1.pid)`; **никогда** `pkill -f run.py`.
5. Промежуточный тест (только H200, параллельно обучению) на чекпоинтах 3000 и 4000:
   ```
   cd /workspace/tw/kit/tools/gpu/master && source hf_env.sh && nohup python3 gen_eval.py --prompts eval_prompts.json --out /workspace/tw/eval/tw_master_v1 --lora base=none --lora s3000=/workspace/tw/output/tw_master_v1/tw_master_v1_000003000.safetensors > /workspace/tw/logs/eval.log 2>&1 &
   ```
   На L40S — тот же тест после конца обучения: `--lora base=none --lora s3000=… --lora s4000=… --lora s5000=… --lora s6000=…/tw_master_v1.safetensors`,
   затем лучшему шагу ещё `--lora sBEST_w08=…@0.8`.
6. Упаковка для оценщиков: `media_upload` (filename `tw_master_v1_eval.zip`, source_type `file_input`, workspace `d56c6962-fcec-4bcb-a0d6-fd78e2c43e29`)
   → `bash pack_eval.sh tw_master_v1 "<upload_url>"` → после `UPLOAD_HTTP_200` `media_confirm` (type file) → скачать по ссылке в контейнер.

## 3. Оценка и решение

Три независимых оценщика по `EVAL_RUBRIC.md` (единство стиля, качество и анатомия, верность игре) — воркфлоу, каждый получает
папку с картинками, контактные листы и эталонный лист датасета. Гейты и выбор шага/веса — механически по рубрике.
Не прошли гейты → v2 по плейбуку рубрики (`NAME=tw_master_v2 … run_train.sh`), максимум две доработки (v2, v3). Старые версии не перезаписывать.

## 4. Бэкап весов (обязательно, HANDOFF §24)

1. `media_upload` (filename `tw_master_v1.zip`, file_input, тот же workspace) → `bash backup_weights.sh tw_master_v1 <лучший_чекпоинт> "<upload_url>"`
   → `UPLOAD_HTTP_200` → `media_confirm`. Копия на постоянном диске: `/workspace/tw/backups/tw_master_v1/` (+ SHA256SUMS).
2. Ссылку записать в `docs/STYLE_SYSTEM.md`, таблица «Где лежат веса», и отметить боевую версию.
3. Кэш базовой модели — `/workspace/tw/base_models` (сделан главным тредом) или `/workspace/tw/hf_home`; `cache_base.sh` докачивает
   только недостающее, запуск без интернета к HF — `TW_OFFLINE=1`.

## 5. Конец

`gpu_rental_stop` сразу после бэкапа (и при любом обрыве), проверить `gpu_my`. Рецепты генерации — в `docs/STYLE_SYSTEM.md` §4.
