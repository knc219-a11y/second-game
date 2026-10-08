extends Area2D

# Placeholder drop. Walking over it (the Player's Hurtbox entering this area)
# offers the item to the Player and removes the drop. The dropping enemy sets
# is_armor, or tier and the Sword color, before adding it.
@export var tier: int = 1
# Armor drop instead of a weapon: shows the Armor shape instead of the sword.
@export var is_armor: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	$Visual/Sword.visible = not is_armor
	$Visual/Hilt.visible = not is_armor
	$Visual/Armor.visible = is_armor


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if not target.has_method("equip_weapon"):
		return
	if is_armor:
		target.equip_armor()
	else:
		target.equip_weapon(tier)
	queue_free()
