extends CharacterBody2D

@export var max_health: int = 6
@export var move_speed: float = 38.0
@export var heal_range: float = 90.0
@export var heal_interval: float = 1.2
@export var heal_amount: int = 2
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

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health
	_build_animations()
	if anim:
		anim.play("idle")

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
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return null
	var best_target: Node2D = null
	var best_missing = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not ("max_health" in enemy) or not ("current_health" in enemy):
			continue
		var max_val = int(enemy.get("max_health"))
		var cur_val = int(enemy.get("current_health"))
		var missing = max_val - cur_val
		if missing <= 0:
			continue
		if missing > best_missing:
			best_missing = missing
			best_target = enemy as Node2D
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

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	if current_health <= 0:
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
