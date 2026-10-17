extends Control

# Title screen shown before the town. Up/Down picks, X or Enter confirms.
# Continue is listed only when a save file exists. New Game asks once
# (default No) and then deletes the save before starting in town. Controls
# shows the key list and the goal (also opened from the pause menu); X, Enter
# or Esc goes back.

const GAME_SCENE := "res://scenes/test_map.tscn"
const SAVE_PATH := "user://save.cfg"  # same file as player.gd SAVE_PATH
const CONTROLS_TEXT := """Controls

Move   Arrow keys
Attack   X  (hold for the 3-hit combo)
Roll   Space        Parry   Z  (just before a swing lands)
Skills   Q Dash Slash    W Whirl Slash    E Sinew Hook
Blacksmith   C        Inventory   I        Pause   Esc
In the inventory   X wear    C salvage    L lock    Space salvage worse

Goal
Walk into a Hidehold gate to start a stage.
Kill every enemy, then walk into the exit on the right.
Fewer hits taken = better grade and better chests.

X / Esc: back"""

var options: Array[String] = []
var selected := 0
var confirming := false
var controls: Label

@onready var menu_label: Label = $Menu
@onready var hint_label: Label = $Hint


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		options.append("Continue")
	options.append("New Game")
	options.append("Controls")
	controls = make_controls_label()
	add_child(controls)
	_refresh()


# Full-screen key list over a dark backdrop, hidden until shown; the pause menu
# builds its own copy with this too.
static func make_controls_label() -> Label:
	var label := Label.new()
	label.name = "Controls"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.text = CONTROLS_TEXT
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.04, 1)
	dim.show_behind_parent = true
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_child(dim)
	label.visible = false
	return label


func _process(_delta: float) -> void:
	if controls.visible:
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("pause"):
			controls.visible = false
		return
	if Input.is_action_just_pressed("move_up"):
		selected = wrapi(selected - 1, 0, _choices().size())
		_refresh()
	elif Input.is_action_just_pressed("move_down"):
		selected = wrapi(selected + 1, 0, _choices().size())
		_refresh()
	elif Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_accept"):
		_choose(_choices()[selected])


func _choices() -> Array[String]:
	if confirming:
		return ["No", "Yes"]
	return options


func _choose(choice: String) -> void:
	match choice:
		"Continue":
			_start()
		"Controls":
			controls.visible = true
		"New Game":
			if FileAccess.file_exists(SAVE_PATH):
				confirming = true
				selected = 0
				_refresh()
			else:
				_start()
		"Yes":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			print("Save erased")
			_start()
		"No":
			confirming = false
			selected = options.find("New Game")
			_refresh()


func _start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _refresh() -> void:
	var lines: Array[String] = []
	if confirming:
		lines.append("Erase your save and start over?")
		lines.append("")
	var choices := _choices()
	for i in choices.size():
		lines.append(("> %s <" if i == selected else "%s") % choices[i])
	menu_label.text = "\n".join(lines)
	hint_label.text = "Up/Down: choose    X / Enter: confirm"
