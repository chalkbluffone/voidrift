---
name: ui-screen-creator
description: Step-by-step procedure for creating new UI screens, popups, and overlays in Super Cool Space Game with correct signal wiring, synthwave styling, and hover FX patterns.
---

# UI Screen Creator Skill

Use this skill when asked to create a new UI screen, popup, overlay, or card-based selection interface. All UI in Super Cool Space Game follows a CanvasLayer + signal-driven pattern with synthwave styling.

## When to Activate

- Creating a new UI screen (menu, popup, overlay)
- Adding a card-based selection interface (like level-up or station buff)
- Creating HUD additions or overlays

## Existing UI Screens (Reference)

| Screen       | Script                  | Type               | Pattern                          |
| ------------ | ----------------------- | ------------------ | -------------------------------- |
| HUD          | `hud.gd`                | Persistent overlay | Signal listeners → label updates |
| Level-Up     | `level_up.gd`           | Modal popup        | 3 cards + hover FX + selection   |
| Station Buff | `station_buff_popup.gd` | Modal popup        | 3 cards + hover FX + selection   |
| Game Over    | `game_over.gd`          | Full screen        | Stats display + buttons          |
| Ship Select  | `ship_select.gd`        | Full screen        | Grid selection + preview         |
| Main Menu    | `main_menu.gd`          | Full screen        | Button navigation                |
| Pause Menu   | `pause_menu.gd`         | Modal overlay      | Button list                      |
| Options      | `options_menu.gd`       | Modal overlay      | Settings controls                |

## UI Types

| Type                   | Base                   | Visibility                 | Game State                            |
| ---------------------- | ---------------------- | -------------------------- | ------------------------------------- |
| **Modal popup**        | CanvasLayer            | Shown/hidden on signal     | Pauses game (RunManager state change) |
| **Persistent overlay** | CanvasLayer            | Always visible during play | No state change                       |
| **Full screen**        | CanvasLayer            | Replaces current view      | Own game state                        |
| **HUD addition**       | Control (child of HUD) | Part of HUD layout         | No state change                       |

## Step-by-Step Procedure

### Step 1: Create UI Script

Place in `scripts/ui/{screen_name}.gd`.

**Template (Modal Popup with Cards):**

```gdscript
extends CanvasLayer

## {ScreenName} - {Description of the screen's purpose}.

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")
const CARD_HOVER_SHADER: Shader = preload("res://shaders/ui_upgrade_card_hover.gdshader")
const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")

var _cards: Array[PanelContainer] = []
var _current_options: Array = []
var _is_showing: bool = false
var _card_hover_tweens: Dictionary = {}


func _ready() -> void:
	visible = false

	# Get card references
	_cards = [
		$VBoxContainer/ChoicesContainer/Choice1,
		$VBoxContainer/ChoicesContainer/Choice2,
		$VBoxContainer/ChoicesContainer/Choice3,
	]

	# Setup card interactivity
	for i: int in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		card.gui_input.connect(_on_card_input.bind(i))
		card.mouse_entered.connect(_on_card_mouse_entered.bind(i))
		card.mouse_exited.connect(_on_card_mouse_exited.bind(i))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		CARD_HOVER_FX_SCRIPT.setup_card_focus(card, _card_hover_tweens, i)
		# Let clicks pass through children to the card
		for child: Control in card.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect to triggering signal
	# e.g., SomeAutoload.some_signal.connect(_on_trigger)


func show_screen(options: Array) -> void:
	_current_options = options
	_populate_cards()
	visible = true
	_is_showing = true
	# Pause game if modal
	get_tree().paused = true


func hide_screen() -> void:
	visible = false
	_is_showing = false
	get_tree().paused = false
	# Reset all card hover states
	for i: int in range(_cards.size()):
		CARD_HOVER_FX_SCRIPT.reset_hover(_cards[i], _card_hover_tweens, i)


func _populate_cards() -> void:
	for i: int in range(_cards.size()):
		if i < _current_options.size():
			_populate_card(_cards[i], _current_options[i])
			_cards[i].visible = true
		else:
			_cards[i].visible = false


func _populate_card(card: PanelContainer, option: Dictionary) -> void:
	# Set card content from option data
	# Find labels in card children and set text
	pass


func _on_card_input(event: InputEvent, index: int) -> void:
	if not _is_showing:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_option(index)


func _on_card_mouse_entered(index: int) -> void:
	if _is_showing:
		CARD_HOVER_FX_SCRIPT.tween_hover_state(_cards[index], _card_hover_tweens, index, true)


func _on_card_mouse_exited(index: int) -> void:
	if _is_showing:
		CARD_HOVER_FX_SCRIPT.tween_hover_state(_cards[index], _card_hover_tweens, index, false)


func _select_option(index: int) -> void:
	if index >= _current_options.size():
		return
	var selected: Dictionary = _current_options[index]
	# Apply the selected option
	hide_screen()
```

**Template (Simple Menu Screen):**

```gdscript
extends CanvasLayer

## {ScreenName} - {Description}.

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")

@onready var RunManager: Node = get_node("/root/RunManager")

var _button_hover_tweens: Dictionary = {}


func _ready() -> void:
	_setup_buttons()


func _setup_buttons() -> void:
	# Style buttons with synthwave theme
	var buttons: Array[Button] = [
		# $VBoxContainer/Button1, etc.
	]
	for button: Button in buttons:
		CardHoverFx.style_synthwave_button(
			button,
			UiColors.BUTTON_PRIMARY,
			_button_hover_tweens,
		)
```

### Step 2: Create Scene

Save as `scenes/ui/{screen_name}.tscn`.

**Modal popup with cards:**

```
CanvasLayer ({screen_name}.gd)
├── ColorRect                    # Dark overlay (UiColors.BG_OVERLAY)
└── VBoxContainer                # Centered content
    ├── Label (Title)            # Orbitron-Bold, UiColors.NEON_YELLOW
    ├── Label (Subtitle)         # Smaller, UiColors.TEXT_DESC
    ├── ChoicesContainer (VBoxContainer or HBoxContainer)
    │   ├── Choice1 (PanelContainer)
    │   │   └── VBoxContainer
    │   │       ├── Label (Name)
    │   │       └── Label (Description)
    │   ├── Choice2 (PanelContainer)
    │   └── Choice3 (PanelContainer)
    └── ActionsContainer (HBoxContainer)  # Optional: Refresh, Skip buttons
        ├── RefreshButton (Button)
        └── SkipButton (Button)
```

**Simple menu screen:**

```
CanvasLayer ({screen_name}.gd)
├── ColorRect                    # Background (UiColors.BG_DARK)
└── VBoxContainer                # Centered content
    ├── Label (Title)
    └── VBoxContainer (Buttons)
        ├── Button1
        └── Button2
```

### Step 3: Apply Synthwave Styling

**Colors** — Use constants from `UiColors` (never inline Color literals):

```gdscript
# Rarity colors
UiColors.RARITY_COMMON    # Gray
UiColors.RARITY_UNCOMMON  # Green
UiColors.RARITY_RARE      # Blue
UiColors.RARITY_EPIC      # Purple
UiColors.RARITY_LEGENDARY # Gold

# Panel colors
UiColors.PANEL_BG         # Dark translucent (0.08, 0.05, 0.15, 0.95)
UiColors.PANEL_BORDER     # Dim purple
UiColors.HOT_PINK         # Selected/accent

# Text colors
UiColors.TEXT_PRIMARY      # White
UiColors.TEXT_DESC         # Light lavender
UiColors.TEXT_STAT_LABEL   # Dim gray
UiColors.TEXT_STAT_VALUE   # Cyan
```

**Fonts** — Use Orbitron:

```gdscript
const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")
# For extra bold: preload("res://assets/fonts/Orbitron-ExtraBold.ttf")
```

**Card styling** — Use StyleBoxFlat with rounded corners:

```gdscript
var style: StyleBoxFlat = StyleBoxFlat.new()
style.bg_color = UiColors.PANEL_BG
style.border_color = rarity_color
style.border_width_bottom = 2
style.border_width_top = 2
style.border_width_left = 2
style.border_width_right = 2
style.corner_radius_top_left = 8
style.corner_radius_top_right = 8
style.corner_radius_bottom_left = 8
style.corner_radius_bottom_right = 8
style.content_margin_left = 16
style.content_margin_right = 16
style.content_margin_top = 12
style.content_margin_bottom = 12
card.add_theme_stylebox_override("panel", style)
```

### Step 4: Add Card Hover FX

For any selectable cards, use the shared hover system:

```gdscript
# 1. Preload the shader and script
const CARD_HOVER_SHADER: Shader = preload("res://shaders/ui_upgrade_card_hover.gdshader")
const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

# 2. Create hover overlay on each card (in _populate_card or setup)
CARD_HOVER_FX_SCRIPT.ensure_hover_overlay(card, CARD_HOVER_SHADER, edge_color, glow_color)

# 3. Setup focus-based hover (for gamepad support)
CARD_HOVER_FX_SCRIPT.setup_card_focus(card, _card_hover_tweens, index)

# 4. Connect mouse hover
card.mouse_entered.connect(func() -> void:
    CARD_HOVER_FX_SCRIPT.tween_hover_state(card, _card_hover_tweens, index, true)
)
card.mouse_exited.connect(func() -> void:
    CARD_HOVER_FX_SCRIPT.tween_hover_state(card, _card_hover_tweens, index, false)
)

# 5. Reset on hide (IMPORTANT — prevents stale hover on next show)
CARD_HOVER_FX_SCRIPT.reset_hover(card, _card_hover_tweens, index)
```

**Critical gotcha — hover-on-load bug:**
When cards are shown, the mouse cursor may already be over a card, causing an unwanted hover state. Always reset all card hover states when showing the screen, then let the natural mouse events re-trigger hover.

### Step 5: Button Styling

For buttons, use `CardHoverFx.style_synthwave_button()`:

```gdscript
CardHoverFx.style_synthwave_button(
    button,
    UiColors.BUTTON_PRIMARY,
    _button_hover_tweens,
)
```

This applies:

- Normal / hover / pressed / focus StyleBoxFlat overrides
- Mouse cursor change
- Scale tween on hover and focus (gamepad support)

### Step 6: Wire to RunManager

If the screen is modal (pauses gameplay):

```gdscript
func show_screen() -> void:
    visible = true
    get_tree().paused = true
    # Optional: Change RunManager state
    # RunManager.current_state = RunManager.GameState.LEVEL_UP

func hide_screen() -> void:
    visible = false
    get_tree().paused = false
    # RunManager.current_state = RunManager.GameState.PLAYING
```

Set `process_mode = Node.PROCESS_MODE_ALWAYS` on the CanvasLayer so UI input works while paused.

### Step 7: Mouse Filter Setup

For card-based UIs, set mouse filters correctly:

```gdscript
# Card itself captures clicks
card.mouse_filter = Control.MOUSE_FILTER_STOP

# All children pass clicks through to card
for child: Control in card.get_children():
    child.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for grandchild: Node in child.get_children():
        if grandchild is Control:
            (grandchild as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
```

This ensures clicks on labels/icons inside the card bubble up to the card's `gui_input` handler.

## Checklist

- [ ] UI script: `scripts/ui/{screen_name}.gd`
- [ ] Scene: `scenes/ui/{screen_name}.tscn`
- [ ] Colors from `UiColors` constants (no inline Color literals)
- [ ] Fonts: Orbitron-Bold for headers
- [ ] Card hover FX wired (if card-based)
- [ ] Hover reset on show/hide (prevent hover-on-load bug)
- [ ] Mouse filters correct (STOP on cards, IGNORE on children)
- [ ] `process_mode = PROCESS_MODE_ALWAYS` if modal
- [ ] RunManager state integration (pause/unpause)
- [ ] Button styling via `CardHoverFx.style_synthwave_button()`
- [ ] Gamepad focus support (setup_card_focus + focus StyleBox)
- [ ] Headless sanity check passes
