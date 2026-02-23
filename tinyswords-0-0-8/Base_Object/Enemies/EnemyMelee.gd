extends CharacterBody2D

@export var max_health: int = 8
@export var move_speed: float = 40.0
@export var attack_range: float = 26.0
@export var attack_interval: float = 0.8
@export var damage: int = 2
@export var is_ally: bool = false
@export var idle_texture: Texture2D
@export var move_texture: Texture2D
@export var attack_texture: Texture2D
@export var idle_frames: int = 6
@export var move_frames: int = 6
@export var attack_frames: int = 6
@export var idle_fps: float = 6.0
@export var move_fps: float = 8.0
@export var attack_fps: float = 10.0
@export var use_lancer_directional_attacks: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var current_health: int = 0
var attack_timer: float = 0.0
var health_bar: TextureProgressBar
var attack_anim_by_dir: Dictionary = {}
var is_attacking: bool = false
var attack_elapsed: float = 0.0
var has_applied_attack_damage: bool = false
var attack_hit_time: float = 0.0
var attack_hit_time_by_anim: Dictionary = {}
var current_attack_target: Node2D = null

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
	attack_timer -= delta
	if is_attacking:
		attack_elapsed += delta
		if not has_applied_attack_damage and attack_elapsed >= attack_hit_time:
			if current_attack_target != null and is_instance_valid(current_attack_target) and current_attack_target.has_method("take_damage"):
				if global_position.distance_to(current_attack_target.global_position) <= attack_range:
					current_attack_target.take_damage(damage)
			has_applied_attack_damage = true
		if anim:
			if not anim.is_playing() or not str(anim.animation).begins_with("attack"):
				is_attacking = false
				current_attack_target = null
				attack_elapsed = 0.0
				has_applied_attack_damage = false
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var target = _pick_target()
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		if anim:
			anim.play("idle")
		return
	var to_target = target.global_position - global_position
	var distance = to_target.length()
	if distance <= attack_range:
		velocity = Vector2.ZERO
		move_and_slide()
		if attack_timer <= 0.0:
			_try_attack(target)
		elif anim and (not anim.is_playing() or not str(anim.animation).begins_with("attack")):
			anim.play("idle")
	else:
		velocity = to_target.normalized() * move_speed
		move_and_slide()
		if anim:
			anim.play("move")
			anim.flip_h = velocity.x < 0

func _pick_target() -> Node2D:
	if is_ally:
		var enemies = get_tree().get_nodes_in_group("enemy")
		if enemies.is_empty():
			return null
		var best: Node2D = null
		var best_dist := INF
		for e in enemies:
			var enemy := e as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			var d = global_position.distance_to(enemy.global_position)
			if d < best_dist:
				best_dist = d
				best = enemy
		return best
	var candidates: Array[Node2D] = []
	var player = get_tree().get_first_node_in_group("peao") as Node2D
	if player != null:
		candidates.append(player)
	var allies = get_tree().get_nodes_in_group("ally")
	for a in allies:
		var ally := a as Node2D
		if ally != null and is_instance_valid(ally):
			candidates.append(ally)
	var towers = get_tree().get_nodes_in_group("tower")
	for t in towers:
		var tower := t as Node2D
		if tower != null and is_instance_valid(tower):
			candidates.append(tower)
	if candidates.is_empty():
		return null
	var best: Node2D = null
	var best_dist := INF
	for c in candidates:
		var d = global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			best = c
	return best

func _try_attack(target: Node2D) -> void:
	if attack_timer > 0.0:
		return
	if is_attacking:
		return
	attack_timer = attack_interval
	current_attack_target = target
	is_attacking = true
	attack_elapsed = 0.0
	has_applied_attack_damage = false
	if anim:
		var dir_vec = Vector2.RIGHT
		if target != null:
			dir_vec = (target.global_position - global_position).normalized()
			if dir_vec == Vector2.ZERO:
				dir_vec = Vector2.RIGHT
		var anim_name = "attack"
		if use_lancer_directional_attacks and not attack_anim_by_dir.is_empty():
			var key = _get_attack_direction_key(dir_vec)
			if key == "left":
				key = "right"
			elif key == "upleft":
				key = "upright"
			elif key == "downleft":
				key = "downright"
			var mapped = attack_anim_by_dir.get(key, "")
			if mapped == "":
				mapped = attack_anim_by_dir.get("down", "attack")
			anim_name = mapped
			if dir_vec.x < 0.0:
				anim.flip_h = true
			else:
				anim.flip_h = false
		else:
			anim.flip_h = dir_vec.x < 0.0
		anim.play(anim_name)
		attack_hit_time = attack_hit_time_by_anim.get(anim_name, 0.0)
		if attack_hit_time <= 0.0:
			var frames_count = attack_frames
			if frames_count <= 0:
				frames_count = 1
			if attack_fps > 0.0:
				attack_hit_time = float(frames_count) / attack_fps * 0.5
			else:
				attack_hit_time = 0.3

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	_update_health_bar()
	if current_health <= 0:
		if not is_ally:
			get_tree().call_group("level", "register_enemy_kill", "melee")
		queue_free()

func _build_animations() -> void:
	if anim == null:
		return
	var frames = SpriteFrames.new()
	attack_hit_time_by_anim.clear()
	_add_strip(frames, "idle", idle_texture, idle_frames, idle_fps)
	_add_strip(frames, "move", move_texture, move_frames, move_fps)
	if use_lancer_directional_attacks:
		_build_lancer_attack_animations(frames)
	else:
		_add_strip(frames, "attack", attack_texture, attack_frames, attack_fps)
		if frames.has_animation("attack"):
			frames.set_animation_loop("attack", false)
			_register_attack_hit_time(frames, "attack", attack_fps)
	if frames.has_animation("idle"):
		frames.set_animation_loop("idle", true)
	if frames.has_animation("move"):
		frames.set_animation_loop("move", true)
	anim.sprite_frames = frames

func _build_lancer_attack_animations(frames: SpriteFrames) -> void:
	attack_anim_by_dir.clear()
	if attack_texture == null:
		return
	var base_path := attack_texture.resource_path
	if base_path == "":
		return
	var tex_down: Texture2D = attack_texture
	var tex_up: Texture2D = load(base_path.replace("Down_Attack", "Up_Attack"))
	var tex_right: Texture2D = load(base_path.replace("Down_Attack", "Right_Attack"))
	var tex_downright: Texture2D = load(base_path.replace("Down_Attack", "DownRight_Attack"))
	var tex_upright: Texture2D = load(base_path.replace("Down_Attack", "UpRight_Attack"))
	if tex_down:
		_add_strip(frames, "attack_down", tex_down, attack_frames, attack_fps)
		frames.set_animation_loop("attack_down", false)
		attack_anim_by_dir["down"] = "attack_down"
		_register_attack_hit_time(frames, "attack_down", attack_fps)
	if tex_up:
		_add_strip(frames, "attack_up", tex_up, attack_frames, attack_fps)
		frames.set_animation_loop("attack_up", false)
		attack_anim_by_dir["up"] = "attack_up"
		_register_attack_hit_time(frames, "attack_up", attack_fps)
	if tex_right:
		_add_strip(frames, "attack_right", tex_right, attack_frames, attack_fps)
		frames.set_animation_loop("attack_right", false)
		attack_anim_by_dir["right"] = "attack_right"
		_register_attack_hit_time(frames, "attack_right", attack_fps)
	if tex_downright:
		_add_strip(frames, "attack_downright", tex_downright, attack_frames, attack_fps)
		frames.set_animation_loop("attack_downright", false)
		attack_anim_by_dir["downright"] = "attack_downright"
		_register_attack_hit_time(frames, "attack_downright", attack_fps)
	if tex_upright:
		_add_strip(frames, "attack_upright", tex_upright, attack_frames, attack_fps)
		frames.set_animation_loop("attack_upright", false)
		attack_anim_by_dir["upright"] = "attack_upright"
		_register_attack_hit_time(frames, "attack_upright", attack_fps)
	if attack_anim_by_dir.is_empty():
		_add_strip(frames, "attack", attack_texture, attack_frames, attack_fps)
		if frames.has_animation("attack"):
			frames.set_animation_loop("attack", false)
			_register_attack_hit_time(frames, "attack", attack_fps)

func _get_attack_direction_key(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return "down"
	var angle = atan2(dir.y, dir.x)
	var deg = rad_to_deg(angle)
	if deg >= -22.5 and deg < 22.5:
		return "right"
	elif deg >= 22.5 and deg < 67.5:
		return "downright"
	elif deg >= 67.5 and deg < 112.5:
		return "down"
	elif deg >= 112.5 and deg < 157.5:
		return "downleft"
	elif deg >= -67.5 and deg < -22.5:
		return "upright"
	elif deg >= -112.5 and deg < -67.5:
		return "up"
	elif deg >= -157.5 and deg < -112.5:
		return "upleft"
	else:
		return "left"

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

func _register_attack_hit_time(frames: SpriteFrames, anim_name: String, fps: float) -> void:
	if fps <= 0.0:
		attack_hit_time_by_anim[anim_name] = 0.3
		return
	if not frames.has_animation(anim_name):
		return
	var frame_count = frames.get_frame_count(anim_name)
	if frame_count <= 0:
		frame_count = 1
	var duration = float(frame_count) / fps
	attack_hit_time_by_anim[anim_name] = duration * 0.5

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
