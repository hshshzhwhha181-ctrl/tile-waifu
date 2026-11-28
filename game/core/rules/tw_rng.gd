class_name TWRng
extends RefCounted

# TWRng (P16 / WP5): the seeded random source of the new rules core. Everything TWBoard deals (faces, gold, ice, secret,
# shard, specials, shuffle) comes from one TWRng, so the same seed gives the same board on every platform and every
# Godot version. It is NOT RandomNumberGenerator: that class belongs to the engine and its sequence is not part of any
# contract; this one is SplitMix64 written out in integer arithmetic (64-bit wrap-around is defined in GDScript), and
# the first values for seed 1 are pinned in the selftest.
#
#   TWRng.make(seed, salt = 0)   a stream; (seed, salt) pairs give independent streams (fork-by-label)
#   next_u32() / rand_i31() / rand_range(lo, hi) / below(n) / rand_f() / chance(p) / shuffle(arr) / pick(arr)
#   (rand_f / rand_i31 / rand_range are not called randf / randi / randi_range on purpose: inside the class such a name
#   would still reach GDScript's global, unseeded function)
#   state                        read / write the stream position (replays, snapshots)
#   TWRng.mix(x) -> int          31-bit integer hash (the same function as V10LevelGen._hash: seed salting)
#   TWRng.fnv(h, v) -> int       one FNV-1a step over a 32-bit value; the base of every state_hash

const _GAMMA: = -7046029254386353131     # 0x9E3779B97F4A7C15
const _M1: = -4658895280553007687        # 0xBF58476D1CE4E5B9
const _M2: = -7723592293110705685        # 0x94D049BB133111EB
const FNV_BASIS: = 2166136261
const FNV_PRIME: = 16777619

var state: int = 0


static func make(seed_: int, salt: int = 0) -> TWRng:
	var r: = TWRng.new()
	r.state = seed_ ^ (salt * _GAMMA)
	r._next64()   # burn one: seeds 0 and 1 must not start correlated
	return r


func fork(salt: int) -> TWRng:
	return make(_next64(), salt)


func _next64() -> int:
	state += _GAMMA
	var z: = state
	z = (z ^ ((z >> 30) & 0x3FFFFFFFF)) * _M1
	z = (z ^ ((z >> 27) & 0x1FFFFFFFFF)) * _M2
	return z ^ ((z >> 31) & 0x1FFFFFFFF)


# uniform 0 .. 2^32-1
func next_u32() -> int:
	return (_next64() >> 32) & 0xFFFFFFFF


# uniform 0 .. 2^31-1
func rand_i31() -> int:
	return (_next64() >> 33) & 0x7FFFFFFF


# uniform 0 .. n-1 (n <= 1 gives 0); the modulo bias is below 2^-20 for the sizes used here and keeps the stream simple
func below(n: int) -> int:
	if n <= 1:
		return 0
	return next_u32() % n


# inclusive on both ends
func rand_range(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + below(hi - lo + 1)


# uniform [0, 1) with 24 random bits
func rand_f() -> float:
	return float(next_u32() >> 8) / 16777216.0


func chance(p: float) -> bool:
	return rand_f() < p


# Fisher-Yates, in place
func shuffle(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var r: = below(k + 1)
		var tmp = a[k]
		a[k] = a[r]
		a[r] = tmp


func pick(a: Array):
	return a[below(a.size())] if not a.is_empty() else null


static func mix(x: int) -> int:
	var h: = (x + 0x9E3779B9) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0x7FFFFFFF
	return h


# one FNV-1a step over the 4 bytes of the low 32 bits of v
static func fnv(h: int, v: int) -> int:
	for sh in [0, 8, 16, 24]:
		h = ((h ^ ((v >> sh) & 0xFF)) * FNV_PRIME) & 0xFFFFFFFF
	return h
