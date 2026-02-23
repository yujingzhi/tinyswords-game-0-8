extends CharacterBody2D

@export var max_health: int = 8
@export var move_speed: float = 40.0
@export var attack_range: float = 26.0
@export var attack_interval: float = 0.7
@export var damage: int = 2
@export var defense: int = 0
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
var health_bar: TextureProgressBar
var is_hovered: bool = false

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
	if current_health <= 0:
		queue_free()
