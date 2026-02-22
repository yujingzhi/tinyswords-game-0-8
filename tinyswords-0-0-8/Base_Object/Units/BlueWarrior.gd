extends CharacterBody2D

@export var max_health: int = 8
@export var move_speed: float = 40.0
@export var attack_range: float = 26.0
@export var attack_interval: float = 0.7
@export var damage: int = 2
@export var idle_texture: Texture2D
@export var move_texture: Texture2D
@export var attack_texture: Texture2D
@export var idle_frames: int = 6
@export var move_frames: int = 6
@export var attack_frames: int = 6
@export var idle_fps: float = 6.0
@export var move_fps: float = 8.0
@export var attack_fps: float = 10.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var current_health: int = 0

func _ready() -> void:
	current_health = max_health
	add_to_group("ally")
	_build_animations()
	if anim:
		anim.play("idle")

func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

func _build_animations() -> void:
	if anim == null:
		return
	var frames = SpriteFrames.new()
	_add_strip(frames, "idle", idle_texture, idle_frames, idle_fps)
	_add_strip(frames, "move", move_texture, move_frames, move_fps)
	_add_strip(frames, "attack", attack_texture, attack_frames, attack_fps)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("move", true)
	frames.set_animation_loop("attack", false)
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
