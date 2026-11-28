class_name V10MjClassicSave
extends RefCounted

# Сейв Классики (обёртка V10MjClassicData по единому имени *_save.gd контракта MODES §7.1).

const KEY: = V10MjClassicData.KEY
const DEFAULTS: = V10MjClassicData.DEFAULTS


static func st(S = null) -> Dictionary:
	return V10MjClassicData.st(S)


static func ensure(S: Dictionary) -> Dictionary:
	return V10MjClassicData.st(S)


static func record(result: Dictionary, today: = "") -> Dictionary:
	return V10MjClassicData.record(result, today)
