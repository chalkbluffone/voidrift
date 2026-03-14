extends Node

## ObjectPool - Generic object pool that recycles scene instances to reduce
## instantiate/queue_free churn. Keyed by pool name, each pool holds a stack
## of dormant Node instances removed from the scene tree.
##
## Usage:
##   var node: Node = ObjectPool.acquire("projectile", PROJECTILE_SCENE)
##   ObjectPool.release("projectile", node)

## Pool storage: { pool_name: Array[Node] }
var _pools: Dictionary = {}

## Stats tracking: { pool_name: { "acquired": int, "recycled": int } }
var _stats: Dictionary = {}

## Max dormant cap per pool name (set via register_pool_cap)
var _caps: Dictionary = {}

## Generation counter per node instance_id.  Incremented on every release so
## a stale deferred remove_child (from an earlier release) becomes a no-op
## when the node has been re-acquired and re-parented in the same frame.
var _release_gen: Dictionary = {}

## Default cap when none registered
const _DEFAULT_CAP: int = 128


func _ready() -> void:
	# Register known pool caps from GameConfig
	_caps["projectile"] = GameConfig.POOL_MAX_DORMANT_PROJECTILES
	_caps["damage_number"] = GameConfig.POOL_MAX_DORMANT_DAMAGE_NUMBERS
	_caps["tothian_mine"] = GameConfig.POOL_MAX_DORMANT_EFFECTS
	_caps["space_nuke"] = GameConfig.POOL_MAX_DORMANT_EFFECTS


## Acquire a node from the pool. Returns a recycled instance if available,
## otherwise instantiates a new one from the scene. The node is NOT added
## to the scene tree — the caller must call add_child() themselves.
func acquire(pool_name: String, scene: PackedScene) -> Node:
	_ensure_stats(pool_name)
	_stats[pool_name]["acquired"] += 1

	if _pools.has(pool_name) and not _pools[pool_name].is_empty():
		while not _pools[pool_name].is_empty():
			var node_ref: Variant = _pools[pool_name].pop_back()
			if not is_instance_valid(node_ref):
				continue
			var node: Node = node_ref as Node
			_stats[pool_name]["recycled"] += 1
			# Bump the generation so any pending deferred remove becomes stale
			var nid: int = node.get_instance_id()
			_release_gen[nid] = _release_gen.get(nid, 0) + 1
			# If the deferred remove hasn't fired yet, remove immediately
			if node.is_inside_tree():
				node.get_parent().remove_child(node)
			node.set_process(true)
			node.set_physics_process(true)
			node.visible = true
			if node.has_method("reset"):
				node.reset()
			return node

	# No dormant instance available — create new
	return scene.instantiate()


## Release a node back to the pool instead of queue_free(). Removes it from
## the scene tree, disables processing, and stores it for reuse.
func release(pool_name: String, node: Node) -> void:
	if not is_instance_valid(node):
		return

	_ensure_stats(pool_name)

	# Disable processing while dormant
	node.set_process(false)
	node.set_physics_process(false)
	node.visible = false

	# Remove from scene tree (deferred to avoid physics callback errors).
	# Each release stamps a generation ID — if the node gets re-acquired before
	# the deferred call fires, the generation won't match and the remove is skipped.
	# We use a Callable (lambda) so all context is captured cleanly without
	# call_deferred marshalling issues.
	var parent: Node = node.get_parent()
	if parent:
		var nid: int = node.get_instance_id()
		var pid: int = parent.get_instance_id()
		var gen: int = _release_gen.get(nid, 0) + 1
		_release_gen[nid] = gen
		var pool_ref: Node = self
		(func() -> void:
			var n: Node = instance_from_id(nid) as Node
			if n == null:
				return
			if pool_ref._release_gen.get(nid, -1) != gen:
				return
			var p: Node = instance_from_id(pid) as Node
			if p != null and n.get_parent() == p:
				p.remove_child(n)
		).call_deferred()

	# Enforce cap
	var cap: int = _caps.get(pool_name, _DEFAULT_CAP)
	if not _pools.has(pool_name):
		_pools[pool_name] = []

	# Guard against double-release: skip if node is already in this pool
	if node in _pools[pool_name]:
		return

	if _pools[pool_name].size() >= cap:
		# Pool full — actually free this node
		node.queue_free()
		return

	_pools[pool_name].append(node)


## Register a custom dormant cap for a pool.
func register_pool_cap(pool_name: String, cap: int) -> void:
	_caps[pool_name] = cap


## Drain (queue_free) all dormant instances for a specific pool.
func drain(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return
	for node in _pools[pool_name]:
		if is_instance_valid(node):
			node.queue_free()
	_pools[pool_name].clear()


## Drain all pools. Call on run-end / scene transitions.
func drain_all() -> void:
	var logger: Node = get_node_or_null("/root/FileLogger")
	if logger:
		logger.log_info("ObjectPool", "drain_all — pool stats:")
		for pool_name in _stats:
			var s: Dictionary = _stats[pool_name]
			var dormant: int = _pools[pool_name].size() if _pools.has(pool_name) else 0
			logger.log_info("ObjectPool", "  %s: acquired=%d recycled=%d dormant=%d" % [pool_name, s["acquired"], s["recycled"], dormant])

	for pool_name in _pools:
		for node in _pools[pool_name]:
			if is_instance_valid(node):
				node.queue_free()
		_pools[pool_name].clear()
	_release_gen.clear()
	_stats.clear()


## Get current pool statistics for debugging.
func get_stats() -> Dictionary:
	var result: Dictionary = {}
	for pool_name in _stats:
		var dormant: int = _pools[pool_name].size() if _pools.has(pool_name) else 0
		result[pool_name] = {
			"acquired": _stats[pool_name]["acquired"],
			"recycled": _stats[pool_name]["recycled"],
			"dormant": dormant,
		}
	return result


func _ensure_stats(pool_name: String) -> void:
	if not _stats.has(pool_name):
		_stats[pool_name] = {"acquired": 0, "recycled": 0}
