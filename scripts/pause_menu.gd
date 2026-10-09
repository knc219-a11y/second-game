extends CanvasLayer

# Esc pauses the game and shows this menu (it keeps running while the tree is
# paused). Up/Down picks, X or Enter confirms, Esc again resumes.
# Return to Town is only listed in a stage or the dungeon.

const TITLE_SCENE := "res://scenes/title.tscn"

var options: Array[String] = []
var selected := 0
# Resume waits for X to be let go, so the confirm press doesn't swing the sword.
var resume_pending := false

@onready var map: Node = get_parent()
@onready var menu_label: Label = $Menu


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	if resume_pending:
		if not Input.is_action_pressed("attack"):
			_resume()
		return
	if not visible:
		if Input.is_action_just_pressed("pause") and _can_pause():
			_open()
		return
	if Input.is_action_just_pressed("pause"):
		_resume()
	elif Input.is_action_just_pressed("move_up"):
		selected = wrapi(selected - 1, 0, options.size())
		_refresh()
	elif Input.is_action_just_pressed("move_down"):
		selected = wrapi(selected + 1, 0, options.size())
		_refresh()
	elif Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_accept"):
		_choose(options[selected])


# Not while dead (R restarts there) or mid-fade between areas.
func _can_pause() -> bool:
	return not map.player.is_dead and not map.moving_on


func _open() -> void:
	options = ["Resume"]
	if not map.in_hub:
		options.append("Return to Hidehold")
	options.append("Title")
	selected = 0
	_refresh()
	visible = true
	get_tree().paused = true
	print("Paused")


func _choose(choice: String) -> void:
	match choice:
		"Resume":
			resume_pending = true
		"Return to Hidehold":
			_resume()
			map.return_to_town()
		"Title":
			_resume()
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file(TITLE_SCENE)


func _resume() -> void:
	resume_pending = false
	visible = false
	get_tree().paused = false
	print("Resumed")


func _refresh() -> void:
	var lines: Array[String] = []
	for i in options.size():
		lines.append(("> %s <" if i == selected else "%s") % options[i])
	menu_label.text = "\n".join(lines)
