extends Area2D

# Placeholder weapon drop. Walking over it (the Player's Hurtbox entering this
# area) equips the one hardcoded weapon and removes the drop.


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target.has_method("equip_weapon"):
		target.equip_weapon()
		queue_free()
