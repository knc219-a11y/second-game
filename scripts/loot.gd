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
# Weapon, armor or ring rarity and rolled value (player.gd roll_gear). Left at
# -1, the drop rolls them itself; a chest sets the ones its label already showed.
@export var rarity: int = -1
@export var bonus: int = -1
# Painted Stage 1 drop art (32px, drawn at 1:1) in place of the placeholder
# shapes: the armor as a hardened husk shard and the Scab Pup (pet kind 2) as a
# stabilized regen core in every stage, since they belong to the item; the
# ichor drop as regen fiber only in Stage 1 (test_map.is_stage_one), since the
# heal is shared by every stage and keeps its green orb elsewhere. Callus Blade
# (weapon tier 1) and Nerve Ring belong to the item too, so they show in every
# stage; Bone Blade (tier 2) keeps the sword shape.
const CALLUS_BLADE_ICON := preload("res://art/stage1/drops/s1_drop_callus_blade.png")
const NERVE_RING_ICON := preload("res://art/stage1/drops/s1_drop_nerve_ring.png")
const ARMOR_ICON := preload("res://art/stage1/drops/s1_drop_husk_shard.png")
const SCAB_PUP_ICON := preload("res://art/stage1/drops/s1_drop_regen_core.png")
const STAGE1_HEAL_ICON := preload("res://art/stage1/drops/s1_drop_regen_fiber.png")

# Set once the drop is taken: queue_free waits for the frame's end, and
# area_entered plus the ichor retry below can both fire in that frame.
var picked: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var is_weapon := not is_armor and not is_pet and not is_heal and not is_ring
	$NameLabel.visible = false
	var player := get_tree().get_first_node_in_group("player")
	var gear := "weapon" if is_weapon else ("armor" if is_armor else ("ring" if is_ring else ""))
	if gear != "" and player != null:
		if rarity < 0:
			var roll: Array = player.roll_gear(gear, tier)
			rarity = roll[0]
			bonus = roll[1]
		# Rarity reads at a glance: the glow and the name above take its color.
		var color: Color = player.rarity_colors[rarity]
		$Visual/Glow.color = Color(color, 0.5)
		$NameLabel.text = player.gear_text(gear, tier, rarity, bonus)
		$NameLabel.modulate = color
		$NameLabel.visible = true
	$Visual/Sword.visible = is_weapon
	$Visual/Hilt.visible = is_weapon
	$Visual/Armor.visible = is_armor
	$Visual/Pet.visible = is_pet
	$Visual/Orb.visible = is_heal
	$Visual/Ring.visible = is_ring
	$Visual/Glow.visible = not is_heal
	var icon: Texture2D = null
	var shape: Node2D = null
	if is_weapon and tier == 1:
		icon = CALLUS_BLADE_ICON
		shape = $Visual/Sword
		$Visual/Hilt.visible = false
	elif is_ring:
		icon = NERVE_RING_ICON
		shape = $Visual/Ring
	elif is_armor:
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
	if picked or not target.has_method("equip_weapon"):
		return
	if is_heal:
		if not target.heal(target.heal_amount):
			return
	elif is_pet:
		target.equip_pet(tier)
	elif is_armor:
		target.equip_armor(maxi(rarity, 0), bonus)
	elif is_ring:
		target.equip_ring(maxi(rarity, 0), bonus)
	else:
		target.equip_weapon(tier, maxi(rarity, 0), bonus)
	picked = true
	target.play_pickup_sound(1.25 if is_heal else 1.0)
	queue_free()
