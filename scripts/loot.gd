extends Area2D

# Placeholder weapon drop. Walking over it (the Player's Hurtbox entering this
# area) offers the weapon of this tier to the Player and removes the drop.
# The dropping enemy sets tier and the Sword color before adding it.
@export var tier: int = 1


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target.has_method("equip_weapon"):
		target.equip_weapon(tier)
		queue_free()
