extends "res://scripts/screens/play.gd"

# V10DuelPlay — the play screen of «Дуэли 2.0», Route A of the README (no edits to play.gd): the integrator
# registers it as main.SCREENS["duel2"] (+ PLAY_BACK["duel2"] = "duels") and the duel screens go
#   main.go("duel2", V10Duel.start(offer, partner))
# It is play.gd with the duel hooks H1–H7 as overrides: the cfg of V10DuelCfg (fixed seed), the global RNG seeded
# right before the deal, 4 slots and no outfit passives in ranked, V10DuelRun instead of V6Duel. The run node
# then normalizes the helps (no prices), strips the specials and owns the exit (= loss) and the result.

const C: = preload("res://scripts/v10/duels/duel_cfg.gd")
const D: = preload("res://scripts/v10/duels/duel_state.gd")
const RUN: = preload("res://scripts/v10/duels/duel_run.gd")


func build(m, args: Dictionary) -> void:
	super.build(m, args)
	if C.is_duel2(args0):
		RUN.adopt(self, false)


# H1: the duel table of V10DuelCfg (play.gd keeps mode "duel": ranked V9 Приём, the overflow rule, the end)
func _v6_setup(args: Dictionary) -> bool:
	if not C.is_duel2(args):
		return false
	mode = "duel"
	cfg = C.cfg_for(args, partner)
	return true


# H4: ranked is 4 slots for everyone (no mc +1 slot)
func _slot_count() -> int:
	if C.normalized(args0):
		return C.SLOTS
	return super._slot_count()


# H2: the faces of TrayBoard._assign still come from the global RNG: seed it from the deal
func _make_board() -> void:
	if bool(cfg.get("seed_locked", false)):
		seed(int(cfg.seed))
	super._make_board()


# ranked: no partner perks, album bonuses or outfit passives (V10DuelRun.normalize sets the helps 1 / 0 / 0)
func _apply_perk() -> void:
	if C.normalized(args0):
		return
	super._apply_perk()


# H7: leaving counts through V10Duel (the run node's own exit), never twice
func _v8_record_loss() -> void:
	if C.is_duel2(args0) and duel != null and is_instance_valid(duel) and duel.has_method("_exit_now"):
		duel._exit_now()
		return
	super._v8_record_loss()


# H8: the line of the «Выйти из партии?» confirm
func leave_text() -> String:
	return D.leave_text()
