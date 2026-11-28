class_name V10PaymentProvider
extends RefCounted

# V10PaymentProvider — the interface every payment backend implements (RuStore Pay SDK later: needs ИП, КЭП and the
# Gradle build, CEO_PLAN §6). V10Shop only talks to this; swapping the stub for RuStore is one line.
#
# Flow (all asynchronous; a provider may answer at once or minutes later, even after an app restart):
#   shop.buy(sku) → provider.purchase(product_id, order_id)
#   provider emits purchase_result({order_id, status, purchase_id, product_id, token, t, error})
#       status: "paid" | "cancelled" | "failed" | "pending"
#   shop delivers the goods (idempotent on purchase_id), writes the receipt, then provider.confirm(purchase_id)
#       (RuStore: confirmPurchase for consumables; subscriptions/non-consumables are acknowledged)
#   on start: shop.reconcile() → provider.get_purchases(): anything "paid" but not confirmed is delivered + confirmed;
#       confirmed non-consumables restore entitlements on a fresh install
#   refunds: provider emits refund_notice(purchase_id) (server webhook / RuStore status) → shop.refund()
#
# Server verification (CEO_PLAN №18) plugs into verify(): until then it only checks the fields are there.

signal purchase_result(res: Dictionary)
signal refund_notice(purchase_id: String)


func id() -> String:
	return "none"


func is_available() -> bool:
	return false


func purchase(_product_id: String, _order_id: String) -> void:
	purchase_result.emit({"order_id": _order_id, "status": "failed", "error": "no_provider"})


func confirm(_purchase_id: String) -> bool:
	return false


# [{purchase_id, product_id, order_id, status: "paid"|"confirmed", t}]
func get_purchases() -> Array:
	return []


func verify(res: Dictionary) -> bool:
	return String(res.get("purchase_id", "")) != "" and String(res.get("product_id", "")) != ""
