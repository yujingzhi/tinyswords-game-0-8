extends CharacterBody2D

@export var max_health: int = 6
@export var move_speed: float = 40.0
@export var attack_range: float = 220.0
@export var attack_interval: float = 1.3
@export var arrow_speed: float = 260.0
@export var damage: int = 2
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

func _ready() -> void:
	current_health = max_health
	add_to_group("ally")
	_build_animations()
	if anim:
		anim.play("idle")

func _physics_process(delta: float) -> void:
	shoot_timer -= delta
	if anim and anim.animation == "shoot" and not anim.is_playing():
		anim.play("idle")
	velocity = Vector2.ZERO
	move_and_slide()

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
				arrow.setup(dir, arrow_speed, damage)
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
