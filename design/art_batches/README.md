# design/art_batches: пакеты заданий для арт-батчей (P59)

Один JSON на батч. Утром владелец утверждает **числа** (потолок, число кандидатов, пилот, критерий отсева), см. `design/ART_BATCHES.md`.
Ничего из этого не запускает генерацию: файлы только описывают задания. Расход: 0 кр.

## Файлы

| файл | что |
|---|---|
| `H0_…` `H1_…` `H2_wardrobe` `H3_…` `H4_…` | героини, **тир Full** (`design/ART_TIER_FULL.md`): золотые композиты, канон-набор, гардероб 10 × 7 нарядов, комбо T1-T3, SSR key-art; нейтрального тира больше нет |
| `E0_…` `E1_…` `E2_…` | LoRA v2: обучение (GPU), продакшн-прогон окружений/тайлов/FX, upscale финалистов |
| `UI_U1_ui_kit.json` | UI-кит (батч U1): иконки, обложки режимов, мелочи |
| `V1_…` `V2_…` `V3_…` | голос: слепой тест, Beta-24, Launch-60 флагманов |
| `M1_music_priority.json` `S1_sfx.json` `X1_video_pilots.json` | музыка, SFX, видео-пилоты |
| `schema.json` | JSON Schema файла батча |
| `index.json` | сводка (генерируется) |
| `src/heroines_v2.json` | урезанная копия данных 10 героинь из `lora-v2/heroines_v2.json` (внешность, наряды, кадры); сборщик читает только её |
| `SPEND_LOG.csv` | сюда пишется фактический расход каждого запуска (заголовок, строк нет) |

JSON не редактируется руками: `python3 tools/art/build_art_batches.py` пересобирает все файлы (детерминированно: сиды от crc32 id), `python3 tools/art/validate_batches.py` проверяет (`--selftest` показывает, что проверки реагируют на дефекты).

## Поля батча

`batch_id`, `package`, `status` (`ready_for_owner_approval` | `blocked_owner_decision` | …), `blocked_by` (что мешает ЗАПУСКУ; числа можно утверждать и раньше), `depends_on`,
`owner_gate`, `budget` {`nominal_cr`, `hard_stop_cr` = номинал + 15%, предпосылки}, `candidates_policy`, `selection` {`keep_per_task`, `gate`, `criteria[]`: критерий отсева},
`pilot` {`task_ids`, `candidates_per_task`, `max_cr` ≤ 10% номинала, `go_rule`}, `guards`, `tasks[]`.

## Поля задания

`id` (`H1.rin_base.search`), `stage` (search / final / post / generate …), `kind`, `media` (image / audio / video / post / gpu), `tool`, `model`, `prompt`,
`element_ids` (`<<<uuid>>>` из HANDOFF §2.2 стоит в самом промпте; в `medias` элемент не дублируется), `heroine`, `lora` (`null` у героинь: LoRA искажает тела и лица),
`size` {aspect, resolution, width, height}, `seed` (для кандидата n: seed + n; у финала `seed_policy`: подставить сид выбранного кандидата), `candidates`,
`unit_cost_cr`, `unit_cost_basis` (`quoted` | `assumed`), `quota_cr` = candidates x unit_cost_cr, `max_credits` (= quota; котировка выше этого числа: не запускать),
`quote_ref` (заполняется при запуске из `estimate_*_cost`), `status`, `output` (`assets/incoming/<batch>/<task>/…`), по необходимости `depends_on_task`, `duration_s`, `text`.

## Как запускать батч (кто и что делает)

1. Утверждены числа в `ART_BATCHES.md`; `blocked_by` пуст.
2. Пилот: задания из `pilot.task_ids`, по `candidates_per_task` кандидатов. Смотрит владелец или AD: красные линии, лица, текст в кадре.
3. Остальное по `stage` (сначала `search`, потом `final` на выбранном сиде). Перед каждым заданием `estimate_*_cost` -> `quote_ref`, если котировка выше `max_credits`, стоп.
4. Результат в `assets/incoming`, расход строкой в `SPEND_LOG.csv`, превышение номинала батча на 15% = стоп и вопрос.
5. Не прошёл критерий отсева: правка промпта в сборщике, пересборка, повторный пилот; JSON не правится руками.

## Ограничения и честные оговорки

- **Промпты не проверены генерацией.** Именно поэтому в каждом батче есть пилот из 2-3 кадров.
- Хвост героинь по умолчанию `v4c` (recipe v4, ROSTER_20 §2.1, только «no school elements» заменено на «adult everyday setting», `V4_FACE` не используется: общая фраза лица делает всех героинь одним лицом). Глянцевая альтернатива `--tail v2g`.
- Идентичность героини целиком в тексте промпта плюс `<<<element_id>>>`; описание лица в карточке может спорить с заказанной эмоцией (например, у МТ «wide open-mouth smile»), смотреть на пилоте.
- Цены, не котированные ночью, помечены `unit_cost_basis: assumed` (upscale 2 кр, стемы 5 кр, ElevenLabs v4, text2speech_v2, Kling/Seedance, GPU).
- В V1/V2/V3 не заданы `voice_id` и тексты JP (V1: 10 фраз написаны, V2/V3: тексты из реестра P44, `text_status: pending_P44`).
- X1: цены видео из R2/PS расходятся с VIDEO_BIBLE; перед запуском `estimate_video_cost`.


## Тир Full (P50b, 2026-11-28)

Все героинские батчи H0-H4 собираются в тире Full (`"tier": "full"`, хвост `v5f`, таблицы нарядов `tools/art/full_tier_wardrobe.py`). Валидатор для таких файлов разрешает костюмные слова (garter, stockings, bikini, bunny, curvy, hourglass...) и держит жёсткие запреты (школа, несовершеннолетние, нагота, сексуальные акты, текст). У поисковых заданий H2 поле `prompt_variants` = три позы одного наряда, кандидат n берёт вариант n.
