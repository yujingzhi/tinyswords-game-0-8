extends StaticBody2D

@export var max_level: int = 10
@export var level: int = 1
@export var base_health: int = 150
@export var health_per_level: int = 60
@export var current_health: int = 150
@export var archer_scene: PackedScene

@onready var slot_position: Node2D = $ArcherSlot
@onready var level_label: Label = $LevelLabel
@onready var upgrade_button: Button = $UpgradeButton
var archer_unit: Node2D
var max_health: int = 0
var health_bar: TextureProgressBar

func _ready() -> void:
	_update_health_from_level()
	_spawn_archer_if_needed()
	_update_level_label()
	_build_health_bar()
	_update_health_bar()
	if upgrade_button != null and not upgrade_button.pressed.is_connected(_on_upgrade_pressed):
		upgrade_button.pressed.connect(_on_upgrade_pressed)

func set_level(new_level: int) -> void:
	level = clamp(new_level, 1, max_level)
	_update_health_from_level()

func _update_health_from_level() -> void:
	max_health = base_health + (level - 1) * health_per_level
	current_health = max_health

func get_archer_slot_global_position() -> Vector2:
	if slot_position:
		return slot_position.global_position
	return global_position

func _spawn_archer_if_needed() -> void:
	if archer_unit != null and is_instance_valid(archer_unit):
		return
	if archer_scene == null:
		return
	var instance = archer_scene.instantiate()
	if instance == null:
		return
	archer_unit = instance as Node2D
	if archer_unit == null:
		instance.queue_free()
		return
	archer_unit.global_position = get_archer_slot_global_position()
	var parent_node = get_parent()
	if parent_node != null:
		parent_node.add_child(archer_unit)
	else:
		get_tree().get_root().add_child(archer_unit)
	if archer_unit is CanvasItem:
		var c := archer_unit as CanvasItem
		c.z_index = z_index + 1

func _physics_process(delta: float) -> void:
	if archer_unit == null or not is_instance_valid(archer_unit):
		return
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	var best_target: Node2D = null
	var best_distance := INF
	var archer_pos = archer_unit.global_position
	var attack_range: float = 220.0
	if "attack_range" in archer_unit:
		attack_range = float(archer_unit.get("attack_range"))
	for e in enemies:
		var enemy := e as Node2D
		if enemy == null:
			continue
		if not is_instance_valid(enemy):
			continue
		var d = archer_pos.distance_to(enemy.global_position)
		if d < best_distance and d <= attack_range:
			best_distance = d
			best_target = enemy
	if best_target == null:
		return
	if archer_unit.has_method("try_shoot_at"):
		archer_unit.call("try_shoot_at", best_target.global_position)

func _update_level_label() -> void:
	if level_label == null:
		return
	level_label.text = "Lv" + str(level)

func _on_upgrade_pressed() -> void:
	var level_node = get_tree().get_first_node_in_group("level")
	if level_node == null:
		return
	if level >= max_level:
		return
	var cost_sp = 1
	if not level_node.has_method("spend_skill_points"):
		return
	var ok = bool(level_node.call("spend_skill_points", cost_sp))
	if not ok:
		return
	set_level(level + 1)
	_update_level_label()

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	_update_health_bar()
	if current_health <= 0:
		if archer_unit != null and is_instance_valid(archer_unit):
			archer_unit.queue_free()
		queue_free()

func _build_health_bar() -> void:
	var bar = TextureProgressBar.new()
	bar.name = "HealthBar"
	bar.position = Vector2(-80, -60)
	bar.custom_minimum_size = Vector2(320, 64)
	bar.scale = Vector2(0.4, 0.4)
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 64
	bar.stretch_margin_top = 0
	bar.stretch_margin_right = 64
	bar.stretch_margin_bottom = 0
	bar.texture_under = load("res://Assets/UI/Bars/SmallBar_Base.png")
	add_child(bar)
	var fill = TextureProgressBar.new()
	fill.name = "Fill"
	fill.anchors_preset = Control.PRESET_FULL_RECT
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 1.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 56.0
	fill.offset_right = -56.0
	fill.offset_bottom = 0.0
	fill.nine_patch_stretch = true
	fill.stretch_margin_left = 64
	fill.stretch_margin_right = 64
	fill.texture_progress = load("res://Assets/UI/Bars/SmallBar_Fill.png")
	bar.add_child(fill)
	health_bar = fill

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = max_health
	health_bar.value = current_health
