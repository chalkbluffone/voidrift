---
name: state-machine-generator
description: Generate modular GDScript state machines following Voidrift's explicit typing conventions, signal architecture, and data-driven design patterns.
---

# State Machine Generator Skill

Use this skill when asked to create a state machine for any game entity — enemies, bosses, UI flows, or ship behavior modes. All generated code must follow Voidrift's GDScript conventions.

## State Machine Architecture

### Base State Class

Every state machine uses an abstract `State` base class:

```gdscript
class_name State
extends Node

## Reference to the state machine managing this state.
var state_machine: StateMachine = null

## Called when this state becomes active.
func enter() -> void:
    pass

## Called when this state is exited.
func exit() -> void:
    pass

## Called every frame while this state is active.
func update(delta: float) -> void:
    pass

## Called every physics frame while this state is active.
func physics_update(delta: float) -> void:
    pass

## Called when unhandled input is received while this state is active.
func handle_input(event: InputEvent) -> void:
    pass
```

### StateMachine Node

The state machine is a `Node` that manages transitions:

```gdscript
class_name StateMachine
extends Node

## Emitted when the state changes.
signal state_changed(old_state: State, new_state: State)

## The initial state to start in (set in inspector).
@export var initial_state: State = null

## The currently active state.
var current_state: State = null

## All registered states, keyed by node name.
var states: Dictionary = {}

func _ready() -> void:
    for child: Node in get_children():
        if child is State:
            states[child.name] = child
            child.state_machine = self
    if initial_state != null:
        current_state = initial_state
        current_state.enter()

func _process(delta: float) -> void:
    if current_state != null:
        current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state != null:
        current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
    if current_state != null:
        current_state.handle_input(event)

## Transition to a new state by name.
func transition_to(state_name: String) -> void:
    if not states.has(state_name):
        FileLogger.log_error("StateMachine", "State not found: %s" % state_name)
        return
    var old_state: State = current_state
    if current_state != null:
        current_state.exit()
    current_state = states[state_name]
    current_state.enter()
    state_changed.emit(old_state, current_state)
```

### Scene Tree Layout

```
Entity (CharacterBody2D)
├── StateMachine (Node)
│   ├── Idle (State)
│   ├── Chase (State)
│   ├── Attack (State)
│   └── Die (State)
├── Sprite2D
└── CollisionShape2D
```

## Voidrift Conventions (Required)

All generated state machine code MUST follow these rules:

1. **Explicit typing** — Every variable, parameter, and return type must be typed. Never use `:=`.
2. **`##` doc comments** — Use `##` above classes, functions, and signals. Never use `"""`.
3. **JSON casting** — If states load configuration from JSON, cast immediately: `float(data.get("speed", 100.0))`
4. **Signal-based transitions** — States should emit signals or call `state_machine.transition_to()`, never directly modify sibling states.
5. **FileLogger for debugging** — Add `FileLogger.log_debug()` calls at state enter/exit for debugging.
6. **snake_case** for functions/variables, **PascalCase** for classes/nodes, **SCREAMING_SNAKE** for constants.

## Example: Enemy State Machine

### Idle State

```gdscript
class_name IdleState
extends State

## Duration to stay idle before looking for targets.
@export var idle_duration: float = 1.0

var _timer: float = 0.0
@onready var FileLogger: Node = get_node("/root/FileLogger")

func enter() -> void:
    _timer = 0.0
    FileLogger.log_debug("IdleState", "Entered idle")

func physics_update(delta: float) -> void:
    _timer += delta
    if _timer >= idle_duration:
        var player: Node2D = _find_player()
        if player != null:
            state_machine.transition_to("Chase")

func _find_player() -> Node2D:
    var players: Array[Node] = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        return players[0] as Node2D
    return null
```

### Chase State

```gdscript
class_name ChaseState
extends State

@export var chase_speed: float = 100.0
@export var attack_range: float = 50.0

var target: Node2D = null
@onready var FileLogger: Node = get_node("/root/FileLogger")

func enter() -> void:
    var players: Array[Node] = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        target = players[0] as Node2D
    FileLogger.log_debug("ChaseState", "Chasing target: %s" % str(target))

func physics_update(delta: float) -> void:
    if target == null or not is_instance_valid(target):
        state_machine.transition_to("Idle")
        return
    var owner_body: CharacterBody2D = owner as CharacterBody2D
    var direction: Vector2 = (target.global_position - owner_body.global_position).normalized()
    owner_body.velocity = direction * chase_speed
    owner_body.move_and_slide()
    if owner_body.global_position.distance_to(target.global_position) <= attack_range:
        state_machine.transition_to("Attack")
```

## Integration with StatsComponent

When the entity has a `StatsComponent`, states should read stats from it:

```gdscript
func enter() -> void:
    var stats: Node = owner.get_node("StatsComponent")
    chase_speed = float(stats.get_stat("speed"))
```

## Data-Driven States

For enemies defined in `data/enemies.json`, states can read their configuration:

```gdscript
func configure_from_data(enemy_data: Dictionary) -> void:
    var base_stats: Dictionary = enemy_data.get("base_stats", {})
    chase_speed = float(base_stats.get("speed", 100.0))
    attack_range = float(base_stats.get("attack_range", 50.0))
```
