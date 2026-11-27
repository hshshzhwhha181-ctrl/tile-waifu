# Tile Waifu 0.12.0 — онлайн-сервер

Аккаунты (гость → регистрация с сохранением прогресса), вход через **Яндекс ID / Google / VK ID / Telegram**,
облачные сохранения, рейтинги (PvP и рейд), PvP по WebSocket (подбор по ELO, приватные комнаты, умный бот).
Протокол для клиента — [`PROTOCOL.md`](PROTOCOL.md).

* Node.js **24+**, **ноль npm-зависимостей**: `node:http`, `node:sqlite` (WAL), собственный WebSocket (RFC 6455).
* База — один файл SQLite `data/tilewaifu.db` (переопределяется `DB_PATH`). Бэкап = копия файла (или `sqlite3 .backup`).
* Пароли — scrypt с солью, токены — 32 случайных байта (в базе хранится только SHA-256 токена), срок 90 дней.

## 1. Быстрый старт (локально)

```bash
cd server
node server.mjs            # http://127.0.0.1:8787/api/v1/health
node e2e_test.mjs          # полный сквозной тест → E2E_OK
```

Локально включён тестовый вход `POST /api/v1/auth/oauth/sandbox` (`ALLOW_DEV_OAUTH=1`), поэтому все 4 кнопки входа
можно проверить без ключей. Настройки — в `.env` (скопируйте `.env.example` → `.env`), сервер читает его сам.

## 2. Ключи OAuth

Во всех случаях адрес возврата (redirect URI) = `PUBLIC_URL` + `/auth/<провайдер>/callback`.
Пример ниже для `PUBLIC_URL=https://tw.example.ru`. Нужен **HTTPS** (кроме локальных тестов).

### 2.1 Яндекс ID
1. Откройте <https://oauth.yandex.ru/client/new> (войдите под Яндекс-аккаунтом), «Создать приложение».
2. Название «Tile Waifu», иконка. Платформа — **«Веб-сервисы»**.
3. Redirect URI: `https://tw.example.ru/auth/yandex/callback`. Suggest Hostname: `tw.example.ru`.
4. Доступы: «Доступ к логину, имени и фамилии, полу» (`login:info`), «Доступ к адресу электронной почты» (`login:email`),
   по желанию «Доступ к портрету пользователя» (`login:avatar`).
5. Сохраните, скопируйте **ClientID** и **Client secret** в `.env`:
   ```
   YANDEX_CLIENT_ID=...
   YANDEX_CLIENT_SECRET=...
   ```

### 2.2 Google
1. <https://console.cloud.google.com/> → создайте проект «Tile Waifu».
2. «APIs & Services» → **OAuth consent screen**: тип External, название, e-mail поддержки, домен `example.ru`,
   scopes: `openid`, `email`, `profile`. Опубликуйте (Publish app), иначе войти смогут только тест-пользователи.
3. «Credentials» → «Create credentials» → **OAuth client ID** → тип **Web application**.
4. Authorized redirect URIs: `https://tw.example.ru/auth/google/callback`.
5. Скопируйте Client ID и Client secret:
   ```
   GOOGLE_CLIENT_ID=....apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=...
   ```

### 2.3 VK ID
1. <https://id.vk.com/about/business/go> → «Перейти в кабинет» → «Добавить приложение».
2. Платформа **«Web»**, название «Tile Waifu».
3. Базовый домен: `tw.example.ru`; **Доверенный Redirect URL**: `https://tw.example.ru/auth/vk/callback`.
4. В разделе «Доступы» включите **почту** (`email`) — необязательно.
5. Скопируйте **ID приложения** (и при желании «Защищённый ключ» — серверу он не обязателен, вход идёт по PKCE):
   ```
   VK_CLIENT_ID=51234567
   VK_CLIENT_SECRET=...
   ```

### 2.4 Telegram
1. В Telegram напишите [@BotFather](https://t.me/BotFather): `/newbot` → имя «Tile Waifu» → username, например `TileWaifuBot`.
   Получите токен вида `123456789:AA...`.
2. Там же: `/setdomain` → выберите бота → отправьте `tw.example.ru` (домен страницы с виджетом входа).
3. В `.env`:
   ```
   TELEGRAM_BOT_TOKEN=123456789:AA...
   TELEGRAM_BOT_NAME=TileWaifuBot
   ```
4. Игра открывает `https://tw.example.ru/auth/telegram/start?state=…` — сервер показывает страницу с виджетом
   Telegram, после входа проверяет подпись (HMAC-SHA256 от SHA256(токена)) и отдаёт результат игре через
   `/api/v1/auth/poll`. HTML5-версия может вызывать `POST /auth/telegram/verify` напрямую.

Проверка: `GET /api/v1/health` → `oauth: {yandex:true, google:true, vk:true, telegram:true}`.
Провайдер без ключей отвечает `503 provider_not_configured`, игра прячет его кнопку.

## 3. Деплой на VPS (Docker + nginx + TLS)

Нужен VPS (Ubuntu 22.04/24.04, 1 vCPU / 512 МБ хватает на тысячи игроков) и домен с A-записью на IP сервера.

```bash
# 1. Docker
curl -fsSL https://get.docker.com | sh

# 2. Код сервера
sudo mkdir -p /opt/tilewaifu && sudo chown $USER /opt/tilewaifu
scp -r server/* server/.env.example user@VPS:/opt/tilewaifu/        # с вашего ПК
cd /opt/tilewaifu && cp .env.example .env && nano .env              # PUBLIC_URL, ключи, ALLOW_DEV_OAUTH=0

# 3. Сборка и запуск (порт слушаем только на localhost — наружу через nginx)
docker build -t tilewaifu-server .
docker run -d --name tilewaifu --restart unless-stopped \
  --env-file .env -p 127.0.0.1:8787:8787 -v tilewaifu-data:/app/data tilewaifu-server
curl http://127.0.0.1:8787/api/v1/health
```

### nginx + Let's Encrypt (HTTPS и wss://)

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo nano /etc/nginx/sites-available/tilewaifu
```

```nginx
map $http_upgrade $connection_upgrade { default upgrade; '' close; }

server {
    listen 80;
    server_name tw.example.ru;
    client_max_body_size 3m;            # облачные сохранения до 2 МБ

    location /ws {                      # WebSocket PvP → wss://tw.example.ru/ws
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 120s;        # сервер пингует каждые 25 с
    }
    location / {
        proxy_pass http://127.0.0.1:8787;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/tilewaifu /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d tw.example.ru          # выпустит сертификат и включит HTTPS + автопродление
curl https://tw.example.ru/api/v1/health
```

В игре укажите адрес сервера `https://tw.example.ru` (клиент сам перейдёт на `wss://tw.example.ru/ws`).

Обновление: `docker build -t tilewaifu-server . && docker rm -f tilewaifu && docker run ...` (та же команда) —
база живёт в томе `tilewaifu-data` и не теряется. Бэкап:
`docker run --rm -v tilewaifu-data:/d -v $PWD:/b alpine cp /d/tilewaifu.db /b/backup-$(date +%F).db`.

## 4. Альтернатива без Docker: systemd

```bash
# Node 24
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - && sudo apt install -y nodejs
sudo useradd -r -m -d /opt/tilewaifu tilewaifu
sudo cp -r server/* /opt/tilewaifu/ && sudo cp /opt/tilewaifu/.env.example /opt/tilewaifu/.env
sudo nano /opt/tilewaifu/.env && sudo chown -R tilewaifu: /opt/tilewaifu
sudo nano /etc/systemd/system/tilewaifu.service
```

```ini
[Unit]
Description=Tile Waifu online server
After=network.target

[Service]
User=tilewaifu
WorkingDirectory=/opt/tilewaifu
Environment=NODE_ENV=production HOST=127.0.0.1
ExecStart=/usr/bin/node /opt/tilewaifu/server.mjs
Restart=always
RestartSec=2
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload && sudo systemctl enable --now tilewaifu
journalctl -u tilewaifu -f
```

nginx и certbot — как в разделе 3.

## 5. Чек-лист продакшена
* `ALLOW_DEV_OAUTH=0` (или `NODE_ENV=production` без этой переменной) — иначе любой может «войти» тестовым входом.
* `PUBLIC_URL` совпадает с адресом в кабинетах провайдеров (https, без слэша в конце).
* Порт 8787 закрыт снаружи (Docker `-p 127.0.0.1:8787:8787`, или `HOST=127.0.0.1`), наружу только 80/443.
* Регулярный бэкап `data/tilewaifu.db`.

## Файлы
| Файл | Что внутри |
|---|---|
| `server.mjs` | точка входа, `export start({port, dbPath, quiet})` → `{port, close()}` |
| `src/db.mjs` | схема SQLite (users, oauth_identities, sessions, player_saves, pvp_matches, leaderboard_raid) |
| `src/users.mjs` | пользователи, scrypt, сессии, привязка провайдеров |
| `src/oauth.mjs` | Яндекс / Google / VK ID (PKCE), Telegram Login Widget, `/auth/poll` |
| `src/api.mjs` | REST `/api/v1/*` |
| `src/ws.mjs` | WebSocket RFC 6455 |
| `src/pvp.mjs`, `src/bot.mjs` | подбор, комнаты, матчи, ELO, бот-соперник |
| `e2e_test.mjs` | сквозной тест (`npm test`) |
