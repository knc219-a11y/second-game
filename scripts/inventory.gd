extends CanvasLayer

# I opens a read-only inventory over a paused game: the three worn gear slots
# (rarity colored, with value and forge level), the pet, the set and the Skin
# Crystal count. I or Esc closes it. Drops still auto-equip or auto-salvage on
# pickup (player.gd), so this only shows what you carry. Built in code; it keeps
# running while the tree is paused (process_mode always in test_map.tscn).

const CALLUS_BLADE_ICON := preload("res://art/stage1/drops/s1_drop_callus_blade.png")
const NERVE_RING_ICON := preload("res://art/stage1/drops/s1_drop_nerve_ring.png")
const ARMOR_ICON := preload("res://art/stage1/drops/s1_drop_husk_shard.png")
const SCAB_PUP_ICON := preload("res://art/stage1/drops/s1_drop_regen_core.png")
const CRYSTAL_ICON := preload("res://art/stage1/drops/s1_drop_skin_crystal.png")

@export var empty_color: Color = Color(0.55, 0.55, 0.55, 1)
@export var icon_size: float = 40.0

# Slot name -> [icon TextureRect, placeholder ColorRect, Label].
var rows: Dictionary = {}

@onready var map: Node = get_parent()


func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.08, 0.07, 0.92)
	panel.position = Vector2(210, 145)
	panel.size = Vector2(860, 430)
	add_child(panel)
	var heading := _make_label(30)
	heading.text = "Inventory"
	heading.position = Vector2(0, 14)
	heading.size = Vector2(860, 40)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(heading)
	var y := 72.0
	for slot in ["weapon", "armor", "ring", "pet", "set", "material"]:
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(28, y)
		icon.size = Vector2(icon_size, icon_size)
		panel.add_child(icon)
		var swatch := ColorRect.new()
		swatch.position = Vector2(36, y + 8)
		swatch.size = Vector2(icon_size - 16, icon_size - 16)
		panel.add_child(swatch)
		var label := _make_label(20)
		label.position = Vector2(84, y)
		label.size = Vector2(760, icon_size + 16)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if slot != "pet" else VERTICAL_ALIGNMENT_TOP
		panel.add_child(label)
		rows[slot] = [icon, swatch, label]
		y += 52.0 if slot != "pet" else 64.0
	var hint := _make_label(16)
	hint.text = "Worse drops break into Skin Crystal on pickup.   I / Esc: close"
	hint.modulate = empty_color
	hint.position = Vector2(0, 396)
	hint.size = Vector2(860, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)


func _process(_delta: float) -> void:
	if visible:
		if Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("pause"):
			close()
	elif Input.is_action_just_pressed("inventory") and _can_open():
		open()


# Not while dead, mid-fade or already paused (the pause menu is up).
func _can_open() -> bool:
	return not map.player.is_dead and not map.moving_on and not get_tree().paused


func open() -> void:
	refresh()
	visible = true
	get_tree().paused = true
	print("Inventory opened")


func close() -> void:
	visible = false
	get_tree().paused = false
	print("Inventory closed")


func refresh() -> void:
	var p: Node = map.player
	if p.weapon_tier > 0:
		var text: String = "Weapon   " + p.weapon_text(p.weapon_tier, p.weapon_rarity, p.weapon_bonus)
		if p.weapon_forge > 0:
			text += "  Forge +%d" % p.weapon_forge
		text += "  (+%d damage)" % (p.weapon_bonus + p.weapon_forge)
		var cost: int = p.forge_cost()
		text += "   next forge: %s" % ("max" if cost < 0 else "%d crystal" % cost)
		_set_row("weapon", text, p.rarity_colors[p.weapon_rarity],
			CALLUS_BLADE_ICON if p.weapon_tier == 1 else null, p.weapon_arc_color[p.weapon_tier - 1])
	else:
		_set_row("weapon", "Weapon   none", empty_color, null, empty_color)
	if p.has_armor:
		_set_row("armor", "Armor    %s  (-%d damage taken)" % [p.armor_text(p.armor_rarity, p.armor_value), p.armor_value],
			p.rarity_colors[p.armor_rarity], ARMOR_ICON, empty_color)
	else:
		_set_row("armor", "Armor    none", empty_color, null, empty_color)
	if p.has_ring:
		_set_row("ring", "Ring     %s  (%d roll graze damage)" % [p.ring_text(p.ring_rarity, p.ring_value), p.ring_value],
			p.rarity_colors[p.ring_rarity], NERVE_RING_ICON, empty_color)
	else:
		_set_row("ring", "Ring     none", empty_color, null, empty_color)
	if p.pet_kind > 0:
		var i: int = p.pet_kind - 1
		_set_row("pet", "Pet      %s\n         %s, %s %d every %.1fs" % [p.pet_names[i], p.pet_passive_text[i],
			"spits" if p.pet_kind == 3 else "bites", p.pet_bite_damage[i], p.pet_bite_cooldown[i]],
			p.pet_colors[i], SCAB_PUP_ICON if p.pet_kind == 2 else null, p.pet_colors[i])
	else:
		_set_row("pet", "Pet      none", empty_color, null, empty_color)
	# The HUD's set line (player.gd _update_set_label). Read from there: the
	# player's set_name export collides with Node.set_name() on outside access.
	var set_text: String = p.set_label.text.trim_prefix("Set: ")
	_set_row("set", "Set      " + set_text, Color(1, 0.95, 0.6, 1) if p.has_set() else empty_color, null, Color(0, 0, 0, 0))
	_set_row("material", "%s   %d" % [p.material_name, p.materials], Color(1, 1, 1, 1), CRYSTAL_ICON, empty_color)


# icon null shows a colored square in its place (gear without painted art yet).
func _set_row(slot: String, text: String, color: Color, icon: Texture2D, swatch_color: Color) -> void:
	var row: Array = rows[slot]
	row[0].texture = icon
	row[0].visible = icon != null
	row[1].color = swatch_color
	row[1].visible = icon == null
	row[2].text = text
	row[2].add_theme_color_override("font_color", color)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	return label
