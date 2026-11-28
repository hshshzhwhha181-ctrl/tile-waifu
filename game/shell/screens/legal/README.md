# Legal Screen (`game/shell/screens/legal/`) — P108 / MP PM21

Экран юридической информации и единый журнал согласий для Tile Waifu (v11 shell).

## Состав
- `spec.tres` — `ScreenSpec` экрана `id = "legal"` (обнаруживается автоматически `TWScreens.scan()`).
- `legal_data.gd` (`TWLegalData`) — загрузчик и валидатор 13 русских документов-шаблонов из `res://data/legal/` (`manifest.json` + `legal_bundle.json`, синхронизируемых из `data/legal/` скриптом `tools/sync_legal_bundle.py`). Проверяет целостность SHA-256, защиту от `..` в путях, обязательный дисклеймер, дословную оговорку C16 и гейт `real_payments_enabled` + `[ЗАПОЛНИТЬ`.
- `legal_consent.gd` (`TWLegalConsent`) — тонкий shell-адаптер поверх единого ядра `TWConsent` (`TWState.data["tw_consents"]`, `mod_ver.consent = 1`, `mod_ver.legal = 1`, `SAVE_VER = 8`), единый формат экспорта МСК и раздельные явные акты согласия (152-ФЗ: ПДн отдельно от Оферты, 18+ только при подтверждённом взрослом `TWAge`, аналитика отдельным переключателем).
- `legal_doc_modal.gd` (`TWLegalDocModal`) — модальный просмотр документа на базе `TWModal` + `TWSheet` (открывается строго через `ModalStack.open`).
- `legal_screen.gd` (`TWLegalScreen`) — экран `TWScreen`: список всех 13 документов, валидация пакета в runtime (fail-closed при подмене), встроенный ридер/модалка, раздельные кнопки согласий с проверкой открытия документов и просмотр журнала.

## Важно
Все 13 текстов в `data/legal/` являются **шаблонами, не юридическая консультация, требуют проверки юристом** до включения реальных платежей (`real_payments_enabled = false` до закрытия входных ворот P1).
