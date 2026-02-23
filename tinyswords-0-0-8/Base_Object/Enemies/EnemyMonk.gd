extends CharacterBody2D

@export var max_health: int = 6
@export var move_speed: float = 38.0
@export var heal_range: float = 90.0
@export var heal_interval: float = 1.2
@export var heal_amount: int = 2
@export var is_ally: bool = false
@export var idle_texture: Texture2D
@export var move_texture: Texture2D
@export var heal_texture: Texture2D
@export var idle_frames: int = 6
@export var move_frames: int = 6
@export var heal_frames: int = 6
@export var idle_fps: float = 6.0
@export var move_fps: float = 8.0
@export var heal_fps: float = 10.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var current_health: int = 0
var heal_timer: float = 0.0
var health_bar: TextureProgressBar

func _ready() -> void:
	if is_ally:
		add_to_group("ally")
	else:
		add_to_group("enemy")
	current_health = max_health
	_build_animations()
	if anim:
		anim.play("idle")
	_build_health_bar()
	_update_health_bar()

func _physics_process(delta: float) -> void:
	heal_timer -= delta
	var target = _pick_heal_target()
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		if anim:
			anim.play("idle")
		return
	var to_target = target.global_position - global_position
	var distance = to_target.length()
	if distance <= heal_range:
		velocity = Vector2.ZERO
		move_and_slide()
		if heal_timer <= 0.0:
			_try_heal(target)
		elif anim and (not anim.is_playing() or anim.animation != "heal"):
			anim.play("idle")
	else:
		velocity = to_target.normalized() * move_speed
		move_and_slide()
		if anim:
			anim.play("move")
			anim.flip_h = velocity.x < 0

func _pick_heal_target() -> Node2D:
	var group_name = "ally" if is_ally else "enemy"
	var units = get_tree().get_nodes_in_group(group_name)
	if units.is_empty():
		return null
	var best_target: Node2D = null
	var best_missing = 0
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			continue
		if not ("max_health" in unit) or not ("current_health" in unit):
			continue
		var max_val = int(unit.get("max_health"))
		var cur_val = int(unit.get("current_health"))
		var missing = max_val - cur_val
		if missing <= 0:
			continue
		if missing > best_missing:
			best_missing = missing
			best_target = unit as Node2D
	if best_target != null:
		return best_target
	var fallback: Node2D = null
	var best_dist := INF
	for unit in units:
		var node := unit as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var d = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			fallback = node
	return fallback
	return best_target

func _try_heal(target: Node2D) -> void:
	if heal_timer > 0.0:
		return
	heal_timer = heal_interval
	if anim:
		anim.play("heal")
	if target and ("max_health" in target) and ("current_health" in target):
		var max_val = int(target.get("max_health"))
		var cur_val = int(target.get("current_health"))
		target.set("current_health", min(max_val, cur_val + heal_amount))
		if target.has_method("_update_health_bar"):
			target.call("_update_health_bar")

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	_update_health_bar()
	if current_health <= 0:
		if not is_ally:
			get_tree().call_group("level", "register_enemy_kill", "monk")
		queue_free()

func _build_animations() -> void:
	if anim == null:
		return
	var frames = SpriteFrames.new()
	_add_strip(frames, "idle", idle_texture, idle_frames, idle_fps)
	_add_strip(frames, "move", move_texture, move_frames, move_fps)
	_add_strip(frames, "heal", heal_texture, heal_frames, heal_fps)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("move", true)
	frames.set_animation_loop("heal", false)
	anim.sprite_frames = frames

func _add_strip(frames: SpriteFrames, anim_name: String, texture: Texture2D, frame_count: int, fps: float) -> void:
	if texture == null:
		return
	var derived_frames = int(round(texture.get_width() / float(texture.get_height())))
	if derived_frames <= 0:
		derived_frames = frame_count
	if derived_frames <= 0:
		return
	frames.add_animation(anim_name)
	var frame_width = texture.get_width() / float(derived_frames)
	var frame_height = texture.get_height()
	for i in range(derived_frames):
		var region = Rect2(i * frame_width, 0, frame_width, frame_height)
		var frame_tex = AtlasTexture.new()
		frame_tex.atlas = texture
		frame_tex.region = region
		frames.add_frame(anim_name, frame_tex)
	frames.set_animation_speed(anim_name, fps)

func _build_health_bar() -> void:
	var bar = TextureProgressBar.new()
	bar.name = "HealthBar"
	bar.position = Vector2(-80, -40)
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
