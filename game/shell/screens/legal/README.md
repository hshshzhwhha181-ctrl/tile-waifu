# Legal Screen (`game/shell/screens/legal/`) — P108 / MP PM21

Экран юридической информации и журнал согласий для Tile Waifu (v11 shell).

## Состав
- `spec.tres` — `ScreenSpec` экрана `id = "legal"` (обнаруживается автоматически `TWScreens.scan()`).
- `legal_data.gd` (`TWLegalData`) — загрузчик и валидатор 13 русских документов-шаблонов из `data/legal/` (`manifest.json` + `01_offer.md`..`13_beta_rules.md`).
- `legal_consent.gd` (`TWLegalConsent`) — append-only журнал согласий с версией оферты (`offer_ver`), версией документа, хэшем текста и отметкой времени `TWClock`. Хранится в `TWState.data["legal_consents"]` под модульной версией `mod_ver.legal = 1` (`SAVE_VER` остаётся `8`).
- `legal_doc_modal.gd` (`TWLegalDocModal`) — модальный просмотр документа на базе `TWModal` + `TWSheet` (открывается строго через `ModalStack.open`).
- `legal_screen.gd` (`TWLegalScreen`) — экран `TWScreen`: список всех 13 документов, встроенный ридер (или модалка при наличии `ctx.service("modals")`), принятие пакета согласий и просмотр/экспорт журнала согласий.

## Важно
Все 13 текстов в `data/legal/` являются **шаблонами, не юридической консультацией, требуют проверки юристом** до включения реальных платежей (`real_payments_enabled = false` до закрытия входных ворот P1).
