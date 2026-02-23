extends CharacterBody2D

@export var max_health: int = 6
@export var move_speed: float = 40.0
@export var attack_range: float = 220.0
@export var attack_interval: float = 1.3
@export var arrow_speed: float = 260.0
@export var damage: int = 2
@export var defense: int = 0
@export var idle_texture: Texture2D
@export var move_texture: Texture2D
@export var shoot_texture: Texture2D
@export var idle_frames: int = 6
@export var move_frames: int = 4
@export var shoot_frames: int = 8
@export var idle_fps: float = 6.0
@export var move_fps: float = 8.0
@export var shoot_fps: float = 10.0
@export var arrow_scene: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var current_health: int = 0
var shoot_timer: float = 0.0
var health_bar: TextureProgressBar
var is_dragged: bool = false
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
	_build_animations()
	if anim:
		anim.play("idle")
	_build_health_bar()
	_update_health_bar()

func _physics_process(delta: float) -> void:
	shoot_timer -= delta
	if anim and anim.animation == "shoot" and not anim.is_playing():
		anim.play("idle")
	if is_dragged:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if has_meta("tower_guard") and bool(get_meta("tower_guard")):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	velocity = Vector2.ZERO
	move_and_slide()
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	var best_target: Node2D = null
	var best_distance := INF
	for e in enemies:
		var enemy := e as Node2D
		if enemy == null:
			continue
		if not is_instance_valid(enemy):
			continue
		var d = global_position.distance_to(enemy.global_position)
		if d < best_distance and d <= attack_range:
			best_distance = d
			best_target = enemy
	if best_target == null:
		return
	try_shoot_at(best_target.global_position)

func try_shoot_at(target_global_position: Vector2) -> void:
	if shoot_timer > 0.0:
		return
	var dist = global_position.distance_to(target_global_position)
	if dist > attack_range:
		return
	shoot_timer = attack_interval
	if anim:
		anim.play("shoot")
	var dir = (target_global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if anim:
		anim.flip_h = dir.x < 0
	if arrow_scene:
		var arrow = arrow_scene.instantiate()
		if arrow:
			arrow.global_position = global_position + Vector2(0, -8)
			if arrow.has_method("setup"):
				arrow.setup(dir, arrow_speed, damage, false)
			get_parent().add_child(arrow)

func _build_animations() -> void:
	if anim == null:
		return
	var frames = SpriteFrames.new()
	_add_strip(frames, "idle", idle_texture, idle_frames, idle_fps)
	_add_strip(frames, "move", move_texture, move_frames, move_fps)
	_add_strip(frames, "shoot", shoot_texture, shoot_frames, shoot_fps)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("move", true)
	frames.set_animation_loop("shoot", false)
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

func take_damage(amount: int) -> void:
	var final_damage = max(0, amount - defense)
	current_health = max(current_health - final_damage, 0)
	_update_health_bar()
	_spawn_hit_fx()
	if current_health <= 0:
		queue_free()

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
