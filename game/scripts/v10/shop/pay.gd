class_name V10ShopPay
extends RefCounted

# V10ShopPay — which payment provider the Лавка runs on (spec 0.10 Л1, Ф7). Facade over v10-economy's
# V10PaymentProvider / V10StubPay so the screen never decides it itself.
#
#   store build (OS feature "tw_store"):  provider "none" → every ₽ card is hidden (С-2, Ф7), RuStore Pay in 1.0
#   test build  (OS feature "tw_test", the editor, or force_test for the demo runner): V10StubPay with force=true,
#                plate «ТЕСТ · деньги не списываются» and the 4-outcome picker in the confirm sheet
#   anything else (an exported APK without a flag): "none" — the safe default, like the economy stub itself.

static var force_test: = false
static var force_store: = false     # selftests / demo: simulate the store build in the editor binary


static func is_store() -> bool:
	return force_store or (OS.has_feature("tw_store") and not force_test)


static func is_test() -> bool:
	if is_store():
		return false
	return force_test or OS.has_feature("tw_test") or OS.has_feature("editor")


static func make_provider() -> V10PaymentProvider:
	if is_test():
		var p: = V10StubPay.new()
		p.force = true
		return p
	return V10PaymentProvider.new()


static func cash_visible(provider: V10PaymentProvider) -> bool:
	return provider != null and provider.is_available() and not is_store()
