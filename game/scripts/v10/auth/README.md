# v10/auth — вход, автовход, аккаунт (дорожка `v10-auth`)

Заставка → экран входа (только первый запуск или после «Выйти») → имя гостя → игра.
Следующие запуски: заставка → **тихий автовход** → карточка-приветствие героини с именем игрока.
Прогресс не теряется ни при одном сценарии (сессия отдельно от сейва; любая проблема сессии → гостевая сессия того же игрока).

## Файлы
| Файл | Класс | Что |
|---|---|---|
| `auth.gd` | `V10Auth` | ядро: запись `G.S.v10_auth`, сессии, флейворы сборки, согласие 152-ФЗ, вход/автовход/выход/удаление, хук возраста |
| `provider.gd` | `V10AuthProvider` | интерфейс AuthProvider (`available`, `sign_in`, `restore`, `link`, `sign_out`; коды результата) |
| `providers.gd` | `V10AuthProviders` | Guest (работает), VKID / YandexID / Google / YandexGames / Email — заглушки `not_available_yet` |
| `flow.gd` | `V10AuthFlow` | `boot(main)`, `relogin(main)`, `open_account(main)`, музыка титула, приветствие |
| `login_screen.gd` | `V10LoginScreen` | экран входа (кнопки по флейвору, согласие, юр. ссылки, 18+) |
| `key_art.gd` + `key_sweep.gdshader` | `V10KeyArt` | живой кей-арт: параллакс (наклон телефона/мышь + дрейф), покачивание и дыхание группы, один блик-свип, мерцание фонарей, лепестки; всё по `S.fx_level` |
| `nick_sheet.gd` | `V10NickSheet` | имя гостя: поле + кубик, «Идеи от героинь» (чип = ник + её аватар), ряд аватаров |
| `auth_nicks.gd` | `V10AuthNicks` | 40 ников в духе пяти основательниц (все проходят `G.nick_error`) |
| `email_sheet.gd` | `V10EmailSheet` | «У меня есть аккаунт»: почта + одноразовый код (UI, сервер позже) + вход в старый импорт по коду восстановления (`V8ProfileCard`) |
| `account_sheet.gd` | `V10AccountSheet` | «Аккаунт»: ник, ID игрока (тап = копия), способ входа, «Привязать аккаунт», согласие, документы, «Выйти», «Удалить аккаунт» (удержание 2 с) |
| `auth_ui.gd` | `V10AuthUI` | лист-модалка, кнопка провайдера с фирменным знаком, чекбокс, ссылка, тост, карточка-приветствие |
| `auth_text.gd` | `V10AuthText` | все строки + приветствия героинь (по 3 на каждую, без стоп-слов V10Lint) |
| `auth_selftest.gd`, `auth_dev.gd/.tscn` | | самотест и dev-сцена (скриншоты, ручной прогон) |
| `game/assets/v10/auth/key_bg.webp` | | фон: чайная на закате, без людей, место под логотип (1520×2688) |
| `game/assets/v10/auth/key_heroes.webp` | | группа пяти основательниц, вырезка с альфой, низ уже растворён (1400×1298) |

## Модель сохранения (`G.S.v10_auth`, см. `V10Auth.defaults()`)
`player_id` (TW-XXXX-XXXX-XXXX-XXXX, crockford base32 из 16 криптослучайных байт), `provider`, `linked {id: {sub, name, at}}`,
`created_at`, `last_login`, `login_count`, `onboarded`, `logged_out`, `consent {pd152, at, doc}`, `deletion {requested_at, player_id}`, `migrated_from`.
Вне сейва: `user://v10_session.json` (provider, token, issued/expires, хеш целостности по install id), `user://v10_device.json` (install id),
`user://v10_auth_outbox.json` (запросы на удаление для будущего сервера).

**SAVE_VER (владеет интегратор, g.gd):** отдельный подъём версии не нужен. `V10Auth.ensure()` идемпотентен (создаёт/чинит ключ, float→int из JSON).
В M1 при общем подъёме 7→8: `V10Save.register("v10_auth", V10Auth.defaults())` и вызвать `V10Auth.ensure()` после `G.load_game()`
(или положиться на ленивый `ensure()` внутри всех вызовов V10Auth). Проверка в `recovery_selftest`: ключ `v10_auth` не обязателен (старые сейвы мигрируют сами).
Старый игрок 0.9 (profile_done / intro_done / unlocked>1) экран входа **не видит**: при первом запуске 0.10 ему тихо создаётся гостевой аккаунт (`migrated_from = "0.9"`).

## Хуки интеграции (горячие файлы правит интегратор)
1. **main.gd `_splash()`** — заменить начало тайтла:
   ```gdscript
   var auth: Dictionary = await V10AuthFlow.boot(self)   # заставка → вход или автовход (+ приветствие)
   if auth.login:   # был экран входа: новый игрок → интро как раньше, иначе на главную
       if not G.S.get("intro_done", false):
           await V6Story.play("intro"); G.S.intro_done = true; G.save()
           go("play", {"level": 0, "partner": "mc"}, false)
       else:
           screen_id = ""; go("home", {}, false)
   return   # старый тайтл «Играть» и V8ProfileCard больше не нужны (имя спрашивает V10NickSheet)
   ```
   Dev-флаги `--shots` / `--pt=` / `--profile_selftest`: оставить ранний `return` до вызова boot; плейтест `--pt=fresh` нужно научить
   нажимать `Btn_guest` и `Btn_play` в `V10NickSheet` (или выставить `V10AuthFlow.skip_splash = true` и вызвать `V10Auth.sign_in_guest()` до boot).
2. **main.gd `settings()`** — строка «Аккаунт» (кнопка) → `V10AuthFlow.open_account(self)`. Выход/удаление сами вызывают `V10AuthFlow.relogin(main)`.
3. **Профиль (v08/profile_screen или v10-profile)** — кнопка «Привязать аккаунт» → тот же `V10AuthFlow.open_account(main)`; ID игрока можно показывать из `V10Auth.player_id()`.
4. **home.gd** — ничего обязательного. Приветствие ставится поверх `main.overlay` под шапкой (`V8Header.CONTENT_Y`). Если у главной есть свой слот тостов — можно передать `V10AuthFlow.welcome(host, main)` туда.
5. **play.gd** — не трогается.
6. **Музыка титула** — `V10AuthFlow.title_music = "title"`: играет `res://assets/music/title.ogg`, если дорожка v10-audio её положит, иначе `menu`.
7. **Возраст (дорожка shop)** — если существует `class_name V10AgeGate` со `static func ensure(host) -> void` (можно корутину), он вызывается после входа и после автовхода; сам решает, показывать ли «Мне есть 18».
8. **Время** — `V10Auth.now()` берёт `V10Meta.now_unix()`, если класс есть; иначе системные часы (grep-самотест §2.5: после слияния meta строку с `Time.get_unix_time_from_system` в auth.gd можно удалить).
9. **registry_list.gd** — одна строка, когда появится V10Registry: самотест `auth` → `V10AuthSelftest.run(host)`.
10. **Флейвор сборки** — `V10Auth.flavor()`: `--flavor=`, feature tags экспорта `rustore` / `gplay` / `yagames` (или `web`), `ProjectSettings tile_waifu/flavor`;
    Android по умолчанию = rustore, ПК = dev (все кнопки). В export_presets добавить `custom_features="rustore"` / `"gplay"`.

## Реальные SDK (1.0)
Каждый провайдер переопределяет `sign_in/restore/link/sign_out` в `providers.gd`; остальная игра не меняется.
VK ID: OneTap Android SDK → authorization code + PKCE → обмен на сервере. Яндекс ID: LoginSDK. Google: Credential Manager (только международная сборка — КоАП 13.55).
Яндекс Игры: `ysdk.getPlayer({scopes:false})` через JavaScriptBridge (комментарий в классе). Почта: `request_code/verify` → сервер.
Важно (CEO_PLAN): вход по почте с паролем в РФ-сборке не делаем; здесь почта с одноразовым кодом — решить с юристом, оставлять ли кнопку в RuStore.
Юр. документы: URL в `V10LoginScreen.DOC_URLS` (пока тост «появится к релизу 1.0»).

## Проверка
```
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/auth/auth_dev.tscn -- \
  --auth_selftest=1 --save=user://auth_selftest_save.json --save_wipe=1          # AUTH_SELFTEST 102/102
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 720x1280 res://scripts/v10/auth/auth_dev.tscn -- --auth_shots=<dir> --flavor=rustore \
  --save=user://auth_shots_save.json --save_wipe=1                                 # 11 кадров; --only=login|splash
```
Самотест: первый запуск → гость → перезапуск (автовход) → выход → снова вход; все заглушки провайдеров; согласие и его отзыв;
повреждённая / подделанная / пропавшая / чужая / с другого устройства сессия; истёкшая сессия провайдера → гость с тостом, привязки целы;
офлайн-льгота неистёкшей сессии; миграция сейва 0.9; удаление аккаунта (сейв + бэкап + копия импорта 0.8 + сессия + install id + очередь на сервер, в запросе только id); отзыв согласия гостем с сохранённой привязкой;
уникальность ID; ники; стоп-слова; хук V10AgeGate; UI-смоук экрана входа (3 флейвора), листа имени, листа аккаунта.

## Арт (Higgsfield, gpt_image_2_6, рецепт v4)
| Имя | job id |
|---|---|
| auth_key_bg (фон-чайная, 9:16) | ee1a05b2-7c9b-4545-adb6-287f64fce6d6 |
| auth_key_group (5 основательниц, 1:1; референсы cute_mc, cute_rin, L2a_hana_sport, cute_yue, cute_nova) | e7e8bb75-c06a-49bf-a803-18268ce8760a |
| auth_key_group_cut (вырезка фона) | c667a1a6-0941-406f-afa7-b398df54c9a5 |
Аудит: у всех пяти по две руки, пальцы по 5 (кропы MT/Рин/Хана/Юэ/Нова), взрослые лица, без текста, фишки пустые.
Пост-обработка (`tools`-скрипт не нужен, параметры здесь): голо-фишка Новы возвращена из оригинала по маске яркости, остатки чайника/стола убраны,
низ растворён 1640→1900 px, масштаб 1400 px. Добавить строки в `tools/art/jobs.tsv` при слиянии.
