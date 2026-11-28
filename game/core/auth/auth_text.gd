class_name V10AuthText
extends RefCounted

# Every visible string of the auth lane in one table (later: localisation, V10Lint scan).
#   V10AuthText.s("login.guest")             -> text
#   V10AuthText.s("toast.welcome", [nick])   -> text % args
# Heroine lines never mention purchases and never guilt the player (docs/0.10-spec.md §2.7 V10Lint.BANNED):
# the selftest scans GREET and every string here against that list.

const T: = {
	"login.guest": "Играть как гость",
	"login.guest_sub": "Прогресс сохранится на этом телефоне",
	"login.vkid": "Войти через VK ID",
	"login.yandex": "Войти через Яндекс ID",
	"login.google": "Войти через Google",
	"login.yagames": "Играть с Яндекс Играми",
	"login.have": "У меня есть аккаунт",
	"login.or": "или войти, чтобы играть на любом устройстве",
	"login.consent": "Согласен(на) на обработку персональных данных для входа (152-ФЗ)",
	"login.consent_need": "Отметь согласие на обработку данных, чтобы войти через аккаунт",
	"login.legal": "Продолжая, ты принимаешь Условия и Политику конфиденциальности",
	"login.terms": "Условия",
	"login.privacy": "Конфиденциальность",
	"login.age": "18+",
	"login.connecting": "Подключаемся…",
	"login.tap": "Коснись, чтобы продолжить",

	"stub.not_available_yet": "%s скоро появится. Пока играй как гость — прогресс сохранится и привяжется позже",
	"stub.network": "Нет связи. Играем как гость, прогресс на месте",
	"stub.cancelled": "Вход отменён",
	"stub.email_soon": "Вход по почте заработает вместе с сервером. Пока играй как гость",
	"stub.legal_soon": "Документ появится к релизу 1.0",

	"nick.title": "Как тебя зовут?",
	"nick.why": "Это имя увидят героини и соперники",
	"nick.ideas": "Идеи от героинь",
	"nick.play": "В чайную!",
	"nick.play_sub": "Имя можно сменить в профиле",

	"email.title": "Вход по почте",
	"email.ask": "Почта, к которой привязан аккаунт",
	"email.hint": "Пришлём одноразовый код. Пароль не нужен",
	"email.bad": "Похоже, в адресе опечатка",
	"email.send": "Получить код",
	"email.code": "Код из письма",
	"email.enter": "Войти",
	"email.back": "Назад",
	"email.restore": "Есть код восстановления?",

	"acc.title": "Аккаунт",
	"acc.id": "ID игрока",
	"acc.copied": "ID скопирован",
	"acc.via": "Вход: %s",
	"acc.since": "С нами с %s",
	"acc.guest_note": "Гостевой прогресс живёт на этом телефоне. Привяжи аккаунт, чтобы не потерять его при смене устройства",
	"acc.link": "Привязать аккаунт",
	"acc.linked": "Привязан",
	"acc.logout": "Выйти",
	"acc.delete": "Удалить аккаунт",
	"acc.logout_q": "Выйти из аккаунта?",
	"acc.logout_guest": "Прогресс останется на этом телефоне. На экране входа нажми «Играть как гость», чтобы продолжить с того же места.",
	"acc.logout_prov": "Прогресс сохранён и привязан к %s. Войди снова тем же способом.",
	"acc.logout_yes": "Выйти",
	"acc.cancel": "Остаться",
	"acc.del_q": "Удалить аккаунт навсегда?",
	"acc.del_text": "Удалятся профиль, наряды, валюта, симпатия и вся история. Это нельзя отменить. Данные на сервере (когда он появится) удаляются в течение 30 дней.",
	"acc.del_hold": "Удерживай, чтобы удалить",
	"acc.del_done": "Аккаунт удалён. Спасибо, что играл(а) с нами",
	"acc.terms": "Условия использования",
	"acc.privacy": "Политика конфиденциальности",
	"acc.consent_off": "Отозвать согласие на обработку данных",
	"acc.consent_on": "Согласие на обработку данных дано",

	"toast.expired": "Вход через %s истёк. Играем как гость — прогресс на месте",
	"toast.restored": "Сессия восстановлена, прогресс на месте",
	"toast.linked": "%s привязан, прогресс сохранён",

	"prov.guest": "гостевой",
	"prov.vkid": "VK ID",
	"prov.yandex": "Яндекс ID",
	"prov.google": "Google",
	"prov.yagames": "Яндекс Игры",
	"prov.email": "почта",
}

# heroine greeting after an automatic sign-in: one is picked by the player's avatar heroine; %s = nick
const GREET: = {
	"mc": [
		"С возвращением, %s! Стол уже накрыт, фишки ждут.",
		"%s, привет! Садись, восточный ветер сегодня за нас.",
		"О, %s! Сыграем партию, пока чай горячий?",
	],
	"rin": [
		"%s. Чай заварен ровно к твоему приходу.",
		"Добрый вечер, %s. Улун сегодня особенно хорош.",
		"%s, присаживайся. Пиала тёплая.",
	],
	"hana": [
		"%s! На старт, внимание — играем!",
		"Привет-привет, %s! Разминка окончена, к столу!",
		"%s, ты вовремя! Эстафету принимаешь?",
	],
	"yue": [
		"Любопытно… %s снова здесь. Луна довольна.",
		"%s. Ночь длинная, а партия короткая.",
		"Приветствую, %s. Дворец открыт для тебя.",
	],
	"nova": [
		"Вход выполнен: %s. Скачано.",
		"%s онлайн. Пинг идеальный, можно играть.",
		"Привет, %s! Сессия восстановлена без потерь.",
	],
}


static func s(key: String, args = null) -> String:
	var t: String = T.get(key, key)
	if args == null:
		return t
	if args is Array:
		return t % args
	return t % [args]


static func greet(hero: String, nick: String, rng: RandomNumberGenerator = null) -> String:
	var arr: Array = GREET.get(hero, GREET.mc)
	var i: = (rng.randi() if rng else randi()) % arr.size()
	return String(arr[i]) % nick


static func provider_name(id: String) -> String:
	return s("prov." + id) if T.has("prov." + id) else id
