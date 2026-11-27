# Tile Waifu 0.12.0 — Online protocol (server ⇄ Godot client)

Base URL: `http://127.0.0.1:8787` (env `PORT`, default 8787). All bodies are JSON (`Content-Type: application/json`).
Auth: `Authorization: Bearer <token>` (sessions table, 90-day expiry). Every JSON response has `ok: bool`;
errors: `{ok:false, error:"<code>", msg:"<human text, ru>"}` with a fitting HTTP status (400/401/404/409/429/503).
CORS: `Access-Control-Allow-Origin: *` + OPTIONS preflight (HTML5 export).

## User object (`user`)
```json
{"id": 12, "nick": "Гость-4821", "email": "", "avatar": "mc", "rp": 0, "pvp_elo": 1000, "wins": 0, "losses": 0,
 "guest": true, "providers": ["yandex", "telegram"], "created_at": 1764190000}
```
`guest` = no password and no linked provider.

## REST
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/v1/health` | – | `{ok:true, version:"0.12.0", online_players:<ws authed sockets>, db:"sqlite", oauth:{yandex:bool,google:bool,vk:bool,telegram:bool}, sandbox:bool}` |
| POST | `/api/v1/auth/guest` | `{nick?, avatar?}` | `{ok, token, user}` |
| POST | `/api/v1/auth/register` | `{nick, email?, password}` (+Bearer of a guest ⇒ **upgrade same user id, save kept**) | `{ok, token, user}` ; 409 `nick_taken`/`email_taken`; 400 `weak_password` (<6) |
| POST | `/api/v1/auth/login` | `{login, password}` (login = nick or email) | `{ok, token, user}` ; 401 `bad_credentials` |
| POST | `/api/v1/auth/logout` | – (Bearer) | `{ok}` |
| POST | `/api/v1/auth/oauth/sandbox` | `{provider, provider_uid?, name?, avatar?}` (+Bearer ⇒ link to that user; else find-or-create) | `{ok, token, user, provider, linked:true}` ; 403 `sandbox_disabled` when `ALLOW_DEV_OAUTH!=1` |
| GET | `/api/v1/auth/poll?state=<nonce>` | – | `{ok:true, pending:true}` until the OAuth callback with that state completes, then `{ok, token, user, provider}` once |
| GET | `/api/v1/me` | Bearer | `{ok, user}` |
| PATCH | `/api/v1/me` | `{nick?, avatar?}` | `{ok, user}` |
| GET | `/api/v1/save` | Bearer | `{ok, save:<object or null>, version:int, updated_at:int}` |
| PUT | `/api/v1/save` | `{save:<object>, version:<base version>, force?:bool}` | `{ok, version, updated_at}` ; 409 `{ok:false, error:"conflict", version, save, updated_at}` when base < server and not force. Max body 2 MB. |
| GET | `/api/v1/leaderboard?board=pvp\|raid&limit=50` | Bearer optional | `{ok, board, rows:[{rank, user_id, nick, avatar, value, wins, losses, stage_idx}], me:{rank, value}\|null}` pvp: value = pvp_elo; raid: value = damage (best), ordered stage_idx desc, damage desc |
| POST | `/api/v1/raid/score` | `{stage_idx, damage}` | `{ok, best:{stage_idx, damage}, improved:bool, rank}` (keeps max) |

## OAuth2 (real providers)
`GET /auth/{yandex|google|vk}/start?state=<client nonce>&link=<token optional>` → 302 to the provider consent page
(Yandex `https://oauth.yandex.ru/authorize`, Google `https://accounts.google.com/o/oauth2/v2/auth` (openid email profile),
VK ID `https://id.vk.com/authorize` with PKCE S256). If the provider has no keys in env → 503 `provider_not_configured`.
`GET /auth/{p}/callback?code&state` → exchanges the code, fetches the profile, links/creates the user, stores the result for
`/api/v1/auth/poll?state=…`, and shows a small HTML page «Вход выполнен — вернитесь в игру».
`POST /auth/telegram/verify` body = Telegram Login Widget fields `{id, first_name, last_name?, username?, photo_url?, auth_date, hash}`
(+Bearer to link). Verification: `secret = SHA256(BOT_TOKEN)`, `data_check_string` = sorted `key=value` lines (all fields except
`hash`) joined by `\n`, `hash == hex(HMAC_SHA256(secret, data_check_string))`, `auth_date` not older than 86400 s → `{ok, token, user, provider:"telegram"}`;
401 `bad_signature` / `expired`; 503 when `TELEGRAM_BOT_TOKEN` is empty.
Game flow: the client makes a random `state`, opens `/auth/{p}/start?state=…&link=<token>` with `OS.shell_open`, then polls
`/api/v1/auth/poll?state=…` every 2 s for up to 3 min.

## WebSocket PvP `ws://host:8787/ws?token=<token>`
Text frames, one JSON object each, key `t` = type. A socket without a valid token gets `{t:"error", code:"unauthorized"}` and is closed.

Client → server:
| t | fields |
|---|---|
| `ping` | – → `pong` |
| `matchmake_join` | – (ELO window ±100 widening +50/s; after **6 s** without a human → bot match) |
| `matchmake_cancel` | – → `{t:"queue_left"}` |
| `room_create` | – → `{t:"room_created", code:"123456"}` (6 digits) |
| `room_join` | `code` → `match_start` to both, or `{t:"error", code:"room_not_found"}` |
| `progress` | `tiles_left, tiles_total, score, combo` (forwarded to the opponent as `opponent_progress`) |
| `sabotage` | `kind:"ice"\|"fog"` (forwarded as `sabotage`; server rate-limits 1 per 4 s per player) |
| `emote` | `id` (one of `"laugh","angry","heart","cool"`; forwarded as `emote`, 1 per 1.5 s) |
| `match_finish` | `cleared:bool, tiles_left, score` — cleared ⇒ that player wins now; cleared:false (tray overflow / surrender) ⇒ the opponent wins |
| `leave` | – leave queue/room/match (in a match = forfeit) |

Server → client:
| t | fields |
|---|---|
| `welcome` | `user` (sent right after connect) |
| `queued` | `elo, eta_s:6` |
| `room_created` | `code` |
| `match_start` | `match_id, seed, board_cfg:{shape, cols, rows, layers, fill, faces, gold, ice, seed}, duration_s:180, you:{id,nick,avatar,pvp_elo}, opponent:{id,nick,avatar,pvp_elo,bot:bool}, mode:"ranked"\|"room"` |
| `opponent_progress` | `tiles_left, tiles_total, score, combo` |
| `sabotage` | `kind, from` |
| `emote` | `id, from` |
| `match_end` | `match_id, winner_id, you_won:bool, reason:"cleared"\|"overflow"\|"timeout"\|"forfeit", your_score, opp_score, elo_before, elo_after, elo_delta` |
| `error` | `code, msg` |

Bot opponent («умный спарринг-соперник»): nick from a pool (e.g. «Сакура-бот», «Лунная Лиса»), `bot:true`, ELO = player ELO ± 40,
removes a pair every 1.6–3.4 s (faster at higher ELO, combo bursts), sends `opponent_progress`, sometimes `sabotage` (≈ every
25–40 s) and `emote`; never finishes before 45 s; loses the race against a decent player most of the time.
ELO: K = 32, expected = 1/(1+10^((Rb-Ra)/400)); bot matches update ELO with K = 16. Room matches are ranked too (K = 32).
Every finished match is a row in `pvp_matches` (p2_id NULL for bots, `p2_bot_nick` column).
Timeout (duration_s): fewer tiles_left wins, tie → higher score.
