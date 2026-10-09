extends Control

# Title screen shown before the town. Up/Down picks, X or Enter confirms.
# Continue is listed only when a save file exists. New Game asks once
# (default No) and then deletes the save before starting in town.

const GAME_SCENE := "res://scenes/test_map.tscn"
const SAVE_PATH := "user://save.cfg"  # same file as player.gd SAVE_PATH

var options: Array[String] = []
var selected := 0
var confirming := false

@onready var menu_label: Label = $Menu
@onready var hint_label: Label = $Hint


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		options.append("Continue")
	options.append("New Game")
	_refresh()


func _process(_delta: float) -> void:
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
