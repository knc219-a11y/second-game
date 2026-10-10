extends Area2D

# Stage reward chest (test_map.gd _spawn_chests). The Player walking into it
# opens it: the lid pops off, its item name floats up and the item comes out as
# a normal drop (loot.tscn) right under the Player, so it is picked up at once
# (an ichor drop at full HP stays on the ground). Emits opened so the map can
# remove the other chest of a pick-one-of-two.
signal opened(chest: Area2D)

# Contents, set by the map before add_child: "weapon" (with tier), "armor",
# "ring" or "heal". The name above the chest shows what is inside.
@export var kind: String = "heal"
@export var tier: int = 1
# Gold chest for the S-grade special-effect item.
@export var special: bool = false
@export var special_color: Color = Color(1, 0.8, 0.2, 1)
@export var loot_scene: PackedScene = preload("res://scenes/loot.tscn")
@export var open_fade_time: float = 0.6

var is_open: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	$ItemLabel.text = item_name()
	if special:
		$Visual/Box.color = special_color
		$Visual/Lid.color = special_color.lightened(0.3)
		$ItemLabel.modulate = special_color


func item_name() -> String:
	var player := get_tree().get_first_node_in_group("player")
	match kind:
		"weapon":
			return player.weapon_names[tier - 1] if player else "Weapon"
		"armor":
			return player.armor_name if player else "Armor"
		"ring":
			return player.ring_name if player else "Ring"
	# The heal shows as Stage 1's regen fiber there (loot.gd draws it the same way).
	var map := get_tree().current_scene
	if map != null and map.has_method("is_stage_one") and map.is_stage_one():
		return "Regen Fiber"
	return "Ichor Drop"


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if is_open or not target.has_method("equip_weapon") or target.is_dead:
		return
	is_open = true
	print("Opened chest: %s" % item_name())
	var loot := loot_scene.instantiate()
	loot.position = target.global_position
	match kind:
		"weapon":
			loot.tier = tier
			loot.get_node("Visual/Sword").color = target.weapon_arc_color[tier - 1]
		"armor":
			loot.is_armor = true
		"ring":
			loot.is_ring = true
		_:
			loot.is_heal = true
	var parent := get_parent()
	parent.add_child.call_deferred(loot)
	parent.move_child.call_deferred(loot, target.get_index())
	opened.emit(self)
	$Visual/Lid.position.y -= 14
	$Visual/Lid.rotation = -0.5
	var tween := create_tween().set_parallel()
	tween.tween_property($ItemLabel, "position:y", $ItemLabel.position.y - 30, open_fade_time)
	tween.tween_property(self, "modulate:a", 0.0, open_fade_time).set_delay(open_fade_time * 0.5)
	tween.chain().tween_callback(queue_free)


# The chest not picked: fades out without giving anything.
func vanish() -> void:
	is_open = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
