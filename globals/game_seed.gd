extends Node

var seed_string: String = ""
var seed_int: int = 0
var _rng_cache: Dictionary = {}

func set_seed_from_string(s: String) -> void:
	seed_string = s
	seed_int = _fnv1a_32(s)
	_rng_cache.clear()

func set_seed_from_int(n: int) -> void:
	# Normalize to a positive 31-bit int so seeds are consistent
	seed_int = int(n) & 0x7FFFFFFF
	seed_string = str(seed_int)
	_rng_cache.clear()

# Use a stable hash so it’s deterministic across platforms/versions
func _fnv1a_32(s: String) -> int:
	var hash_value: int = 0x811C9DC5
	for b in s.to_utf8_buffer():
		hash_value = hash_value ^ int(b)
		hash_value = int(hash_value * 0x01000193) & 0xFFFFFFFF
	# Godot ints are signed; keep it positive-ish
	return hash_value & 0x7FFFFFFF

# Derive a deterministic per-system seed (so systems don't affect each other)
func derive_seed(ns: String) -> int:
	return _fnv1a_32("%s|%s" % [seed_string, ns])

func rng(ns: String) -> RandomNumberGenerator:
	if _rng_cache.has(ns):
		return _rng_cache[ns] as RandomNumberGenerator
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = derive_seed(ns)
	_rng_cache[ns] = r
	return r
