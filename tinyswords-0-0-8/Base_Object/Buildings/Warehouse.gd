extends StaticBody2D

@export var max_level: int = 10
@export var level: int = 1
@export var base_health: int = 180
@export var health_per_level: int = 40
@export var current_health: int = 180

var max_health: int = 0
var health_bar: TextureProgressBar
var is_hovered: bool = false
var hit_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Explosion_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Explosion_02.png"), "frames": 10}
]

func _ready() -> void:
	_update_health_from_level()
	input_pickable = true
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_build_health_bar()
	_update_health_bar()

func set_level(new_level: int) -> void:
	level = clamp(new_level, 1, max_level)
	_update_health_from_level()
	_update_health_bar()

func _update_health_from_level() -> void:
	max_health = base_health + (level - 1) * health_per_level
	current_health = max_health

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	_update_health_bar()
	_spawn_hit_fx()
	if current_health <= 0:
		queue_free()

func _build_health_bar() -> void:
	var bar = TextureProgressBar.new()
	bar.name = "HealthBar"
	bar.position = Vector2(-80, -60)
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
	return "生命 " + str(current_health) + "/" + str(max_health) + "\n攻击 0\n防御 0"

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
	sprite_fx.scale = Vector2(0.7, 0.7)
	sprite_fx.z_index = 15
	var root = get_tree().current_scene
	if root:
		root.add_child(sprite_fx)
	sprite_fx.play()
	if not sprite_fx.animation_finished.is_connected(sprite_fx.queue_free):
		sprite_fx.animation_finished.connect(sprite_fx.queue_free)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_fx, "scale", sprite_fx.scale * 1.25, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite_fx, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
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
