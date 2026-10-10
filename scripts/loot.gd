extends Area2D

# Placeholder drop. Walking over it (the Player's Hurtbox entering this area)
# offers the item to the Player and removes the drop. The dropping enemy sets
# is_armor, or tier and the Sword color, before adding it.
# Weapon tier, or the pet kind for a pet drop.
@export var tier: int = 1
# Armor drop instead of a weapon: shows the Armor shape instead of the sword.
@export var is_armor: bool = false
# Pet drop instead (rare): shows the Pet shape, tinted by the dropping enemy.
@export var is_pet: bool = false
# Ichor drop (heal) instead: restores some Player HP; left on the ground at full HP.
@export var is_heal: bool = false
# Ring drop instead: shows the Ring shape.
@export var is_ring: bool = false
# Painted Stage 1 drop art (32px, drawn at 1:1) in place of the placeholder
# shapes: the armor as a hardened husk shard and the Scab Pup (pet kind 2) as a
# stabilized regen core in every stage, since they belong to the item; the
# ichor drop as regen fiber only in Stage 1 (test_map.is_stage_one), since the
# heal is shared by every stage and keeps its green orb elsewhere.
const ARMOR_ICON := preload("res://art/stage1/drops/s1_drop_husk_shard.png")
const SCAB_PUP_ICON := preload("res://art/stage1/drops/s1_drop_regen_core.png")
const STAGE1_HEAL_ICON := preload("res://art/stage1/drops/s1_drop_regen_fiber.png")


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var is_weapon := not is_armor and not is_pet and not is_heal and not is_ring
	$Visual/Sword.visible = is_weapon
	$Visual/Hilt.visible = is_weapon
	$Visual/Armor.visible = is_armor
	$Visual/Pet.visible = is_pet
	$Visual/Orb.visible = is_heal
	$Visual/Ring.visible = is_ring
	$Visual/Glow.visible = not is_heal
	var icon: Texture2D = null
	var shape: Node2D = null
	if is_armor:
		icon = ARMOR_ICON
		shape = $Visual/Armor
	elif is_pet and tier == 2:
		icon = SCAB_PUP_ICON
		shape = $Visual/Pet
	elif is_heal and _in_stage_one():
		icon = STAGE1_HEAL_ICON
		shape = $Visual/Orb
	if icon != null:
		$Visual/Icon.texture = icon
		$Visual/Icon.visible = true
		shape.visible = false


func _in_stage_one() -> bool:
	var map := get_tree().current_scene
	return map != null and map.has_method("is_stage_one") and map.is_stage_one()


func _physics_process(_delta: float) -> void:
	# An ichor drop left at full HP: the Player standing on it gets no new
	# area_entered, so retry while overlapping (it heals once hurt).
	if is_heal:
		for area in get_overlapping_areas():
			_on_area_entered(area)


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if not target.has_method("equip_weapon"):
		return
	if is_heal:
		if not target.heal(target.heal_amount):
			return
	elif is_pet:
		target.equip_pet(tier)
	elif is_armor:
		target.equip_armor()
	elif is_ring:
		target.equip_ring()
	else:
		target.equip_weapon(tier)
	target.play_pickup_sound(1.25 if is_heal else 1.0)
	queue_free()
