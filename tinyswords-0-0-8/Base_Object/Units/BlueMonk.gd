extends CharacterBody2D

@export var max_health: int = 6
@export var move_speed: float = 38.0
@export var heal_range: float = 80.0
@export var heal_interval: float = 1.2
@export var heal_amount: int = 2
@export var damage: int = 0
@export var defense: int = 0
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
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var current_health: int = 0
var heal_timer: float = 0.0
var health_bar: TextureProgressBar
var patrol_center: Vector2
var patrol_dir: int = 1
@export var patrol_range: float = 64.0
@export var heal_effect_texture: Texture2D = preload("res://Assets/Units/Blue/Monk/Heal_Effect.png")
@export var heal_effect_frames: int = 6
@export var heal_effect_fps: float = 10.0
var is_dragged: bool = false
var separation_radius: float = 16.0
var separation_strength: float = 35.0
var is_hovered: bool = false
var hit_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Explosion_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Explosion_02.png"), "frames": 10}
]

func _ready() -> void:
	current_health = max_health
	add_to_group("ally")
	input_pickable = true
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	patrol_center = global_position
	_build_animations()
	if anim:
		anim.play("idle")
	_build_health_bar()
	_update_health_bar()

func _physics_process(delta: float) -> void:
	heal_timer -= delta
	if is_dragged:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var heal_target = _pick_heal_target()
	if heal_target != null and is_instance_valid(heal_target):
		var to_target = heal_target.global_position - global_position
		var distance = to_target.length()
		if distance <= heal_range:
			velocity = _compute_separation()
			move_and_slide()
			if heal_timer <= 0.0:
				_try_heal(heal_target)
			elif anim and (not anim.is_playing() or anim.animation != "heal"):
				anim.play("idle")
		else:
			velocity = to_target.normalized() * move_speed + _compute_separation()
			move_and_slide()
			if anim:
				anim.play("move")
				anim.flip_h = velocity.x < 0
		return
	var follow_target = _pick_follow_target()
	if follow_target != null and is_instance_valid(follow_target):
		var to_follow = follow_target.global_position - global_position
		var dist = to_follow.length()
		var follow_range = 40.0
		if dist > follow_range:
			velocity = to_follow.normalized() * move_speed + _compute_separation()
			move_and_slide()
			if anim:
				anim.play("move")
				anim.flip_h = velocity.x < 0
		else:
			velocity = _compute_separation()
			move_and_slide()
			if anim:
				anim.play("idle")
		return
	_patrol(delta)

func _patrol(_delta: float) -> void:
	var offset_x = global_position.x - patrol_center.x
	if abs(offset_x) >= patrol_range:
		patrol_dir = -patrol_dir
	var dir_vec = Vector2(patrol_dir, 0)
	velocity = dir_vec * move_speed * 0.4 + _compute_separation()
	move_and_slide()
	if anim:
		anim.play("move")
		anim.flip_h = velocity.x < 0

func _pick_heal_target() -> Node2D:
	var units = get_tree().get_nodes_in_group("ally")
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
	return best_target

func _pick_follow_target() -> Node2D:
	var units = get_tree().get_nodes_in_group("ally")
	if units.is_empty():
		return null
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

func _try_heal(target: Node2D) -> void:
	if heal_timer > 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	if not ("max_health" in target) or not ("current_health" in target):
		return
	var max_val = int(target.get("max_health"))
	var cur_val = int(target.get("current_health"))
	if cur_val >= max_val:
		return
	heal_timer = heal_interval
	if anim:
		anim.play("heal")
		anim.flip_h = (target.global_position.x < global_position.x)
	target.set("current_health", min(max_val, cur_val + heal_amount))
	if target.has_method("_update_health_bar"):
		target.call("_update_health_bar")
	_spawn_heal_effect_on_target(target)

func _spawn_heal_effect_on_target(target: Node2D) -> void:
	if heal_effect_texture == null or target == null or not is_instance_valid(target):
		return
	var fx = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	var derived_frames = int(round(heal_effect_texture.get_width() / float(heal_effect_texture.get_height())))
	if derived_frames <= 0:
		derived_frames = heal_effect_frames
	if derived_frames <= 0:
		return
	frames.add_animation("fx")
	var frame_width = heal_effect_texture.get_width() / float(derived_frames)
	var frame_height = heal_effect_texture.get_height()
	for i in range(derived_frames):
		var region = Rect2(i * frame_width, 0, frame_width, frame_height)
		var frame_tex = AtlasTexture.new()
		frame_tex.atlas = heal_effect_texture
		frame_tex.region = region
		frames.add_frame("fx", frame_tex)
	frames.set_animation_speed("fx", heal_effect_fps)
	frames.set_animation_loop("fx", false)
	fx.sprite_frames = frames
	var offset = Vector2(12, -4)
	if target.global_position.x < global_position.x:
		offset.x = -offset.x
	fx.global_position = target.global_position + offset
	if target.get_parent():
		target.get_parent().add_child(fx)
	else:
		get_tree().current_scene.add_child(fx)
	fx.play("fx")
	fx.connect("animation_finished", func(): fx.queue_free())

func take_damage(amount: int) -> void:
	var final_damage = max(0, amount - defense)
	current_health = max(current_health - final_damage, 0)
	_update_health_bar()
	_spawn_hit_fx()
	if current_health <= 0:
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
	bar.position = Vector2(-80, -44)
	bar.custom_minimum_size = Vector2(320, 64)
	bar.scale = Vector2(0.4, 0.4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	health_bar = fill

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.tooltip_text = ""
	_refresh_hover_tooltip()

func _get_hover_tooltip_text() -> String:
	return "生命 " + str(current_health) + "/" + str(max_health) + "\n攻击 " + str(damage) + "\n防御 " + str(defense)

func _refresh_hover_tooltip() -> void:
	if not is_hovered:
		return
	var ui = get_tree().get_first_node_in_group("interface")
	if ui != null and ui.has_method("show_unit_tooltip"):
		ui.call("show_unit_tooltip", self, _get_hover_tooltip_text())

func _on_mouse_entered() -> void:
	is_hovered = true
	_refresh_hover_tooltip()

func _on_mouse_exited() -> void:
	is_hovered = false
	var ui = get_tree().get_first_node_in_group("interface")
	if ui != null and ui.has_method("hide_unit_tooltip"):
		ui.call("hide_unit_tooltip", self)

func _compute_separation() -> Vector2:
	var result = Vector2.ZERO
	for n in get_tree().get_nodes_in_group("ally"):
		var node := n as Node2D
		if node == null or not is_instance_valid(node) or node == self:
			continue
		var offset = global_position - node.global_position
		var dist = offset.length()
		if dist <= 0.001:
			continue
		if dist < separation_radius:
			result += offset.normalized() * (separation_radius - dist)
	if result == Vector2.ZERO:
		return result
	return result.normalized() * separation_strength

func _spawn_hit_fx() -> void:
	if hit_fx_defs.is_empty():
		return
	var fx = hit_fx_defs.pick_random()
	var texture = fx["texture"]
	var frame_count = int(fx["frames"])
	if texture == null or frame_count <= 0:
		return
	var sprite_fx = AnimatedSprite2D.new()
	sprite_fx.sprite_frames = _build_fx_frames(texture, frame_count, 12.0)
	sprite_fx.animation = "fx"
	sprite_fx.global_position = global_position + Vector2(0, -8)
	sprite_fx.scale = Vector2(0.6, 0.6)
	sprite_fx.z_index = 15
	var root = get_tree().current_scene
	if root:
		root.add_child(sprite_fx)
	sprite_fx.play()
	if not sprite_fx.animation_finished.is_connected(sprite_fx.queue_free):
		sprite_fx.animation_finished.connect(sprite_fx.queue_free)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_fx, "scale", sprite_fx.scale * 1.2, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite_fx, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(sprite_fx.queue_free)

func _build_fx_frames(texture: Texture2D, frame_count: int, fps: float) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.add_animation("fx")
	var frame_width = texture.get_width() / float(frame_count)
	var frame_height = texture.get_height()
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("fx", atlas)
	frames.set_animation_speed("fx", fps)
	frames.set_animation_loop("fx", false)
	return frames

func set_dragged_position(pos: Vector2) -> void:
	global_position = pos
