class_name V10StubPay
extends V10PaymentProvider

# V10StubPay — a fake store for development and selftests. It NEVER works in an exported build, release or debug
# (is_available() is false unless running in the editor binary or force = true), so a shipped APK cannot hand out paid goods for free the way the
# 0.8 shop did (CEO_PLAN §1.1).
#
# Knobs:
#   next_status    "paid" | "cancelled" | "failed" | "pending" for the next purchase(s)
#   instant        true: purchase_result is emitted inside purchase(); false: kept until flush()
#   duplicate      true: a paid result is emitted twice (store retry) — shop must deliver once
#   fail_confirm   confirm() returns false and the purchase stays "paid" (a crash before confirmation)
# Helpers: complete(order_id, status) for a pending order, refund(purchase_id), restart() (drops queued callbacks,
#   keeps the store's records like a real backend would).

var force: = false
var next_status: = "paid"
var instant: = true
var duplicate: = false
var fail_confirm: = false
var t: = 0                        # purchase time stamped on results (tests set it; 0 = system clock)
var records: = {}                 # purchase_id -> {purchase_id, product_id, order_id, status, t}
var _queue: = []
var _seq: = 0
var _pending: = {}                # order_id -> product_id
var confirms: = 0


func id() -> String:
	return "stub"


func is_available() -> bool:
	# not OS.is_debug_build(): a sideloaded debug APK for testers must not hand out month cards and passes either
	return force or OS.has_feature("editor")


func _time() -> int:
	return t if t > 0 else V10Meta.now_unix()


func purchase(product_id: String, order_id: String) -> void:
	if not is_available():
		_emit({"order_id": order_id, "status": "failed", "error": "unavailable"})
		return
	match next_status:
		"paid":
			_emit(_paid(product_id, order_id))
			if duplicate:
				_emit(_paid_again(order_id))
		"pending":
			_pending[order_id] = product_id
			_emit({"order_id": order_id, "status": "pending", "product_id": product_id})
		_:
			_emit({"order_id": order_id, "status": next_status, "product_id": product_id,
				"error": "user_cancelled" if next_status == "cancelled" else "declined"})


func _paid(product_id: String, order_id: String) -> Dictionary:
	_seq += 1
	var pid: = "stub-%06d" % _seq
	var r: = {"purchase_id": pid, "product_id": product_id, "order_id": order_id, "status": "paid", "t": _time()}
	records[pid] = r
	return {"order_id": order_id, "status": "paid", "purchase_id": pid, "product_id": product_id,
		"token": "stub-token-" + pid, "t": r.t}


func _paid_again(order_id: String) -> Dictionary:
	for pid in records:
		if records[pid].order_id == order_id:
			var r: Dictionary = records[pid]
			return {"order_id": order_id, "status": "paid", "purchase_id": pid, "product_id": r.product_id,
				"token": "stub-token-" + pid, "t": r.t}
	return {}


func _emit(res: Dictionary) -> void:
	if res.is_empty():
		return
	if instant:
		purchase_result.emit(res)
	else:
		_queue.append(res)


func flush() -> void:
	var q: = _queue
	_queue = []
	for r in q:
		purchase_result.emit(r)


func restart() -> void:
	_queue.clear()


func complete(order_id: String, status: String = "paid") -> void:
	if not _pending.has(order_id):
		return
	var product: String = _pending[order_id]
	_pending.erase(order_id)
	if status == "paid":
		_emit(_paid(product, order_id))
	else:
		_emit({"order_id": order_id, "status": status, "product_id": product})


func confirm(purchase_id: String) -> bool:
	if fail_confirm or not records.has(purchase_id):
		return false
	records[purchase_id].status = "confirmed"
	confirms += 1
	return true


func get_purchases() -> Array:
	var out: = []
	for pid in records:
		var r: Dictionary = records[pid]
		if r.status != "refunded":
			out.append(r.duplicate())
	return out


func refund(purchase_id: String) -> void:
	if records.has(purchase_id):
		records[purchase_id].status = "refunded"
		refund_notice.emit(purchase_id)
