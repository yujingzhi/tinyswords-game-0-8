extends CharacterBody2D
class_name Sheep

@export var roam_radius: float = 120.0
@export var roam_cell_radius: int = 4
@export var move_speed: float = 40.0
@export var idle_fps: float = 6.0
@export var move_fps: float = 8.0
@export var grass_fps: float = 8.0
@export var idle_time_range: Vector2 = Vector2(0.6, 1.6)
@export var move_time_range: Vector2 = Vector2(0.8, 1.8)
@export var eat_chance: float = 0.35
@export var health: int = 3
@export var min_drop: int = 1
@export var max_drop: int = 2
@export var drop_item_type: String = "meat"
@export var drop_item_scene: PackedScene = preload("res://Base_Object/PhysicItem.tscn")
@export var idle_texture: Texture2D = preload("res://Base_Object/Animals/Sheep/Sheep_Idle.png")
@export var move_texture: Texture2D = preload("res://Base_Object/Animals/Sheep/Sheep_Move.png")
@export var grass_texture: Texture2D = preload("res://Base_Object/Animals/Sheep/Sheep_Grass.png")

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var home_position: Vector2
var target_position: Vector2
var state: String = "idle"
var state_timer: float = 0.0
var roam_layer: TileMapLayer
var roam_cells: Array[Vector2i] = []
var home_cell: Vector2i
var hit_tween: Tween
var hit_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Dust_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Dust_02.png"), "frames": 10}
]

func _ready() -> void:
	home_position = global_position
	_build_animations()
	_enter_idle()

func _physics_process(delta: float) -> void:
	if state == "move":
		var to_target = target_position - global_position
		if to_target.length() <= 2.0:
			_enter_idle()
		else:
			velocity = to_target.normalized() * move_speed
			move_and_slide()
			anim.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
	
	state_timer -= delta
	if state_timer <= 0.0:
		if state == "move":
			_enter_idle()
		else:
			_enter_move()

func take_damage(amount: int) -> void:
	health -= amount
	if anim:
		if hit_tween and hit_tween.is_running():
			hit_tween.kill()
		var base_scale = anim.scale
		hit_tween = create_tween()
		hit_tween.tween_property(anim, "scale", base_scale * 1.12, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hit_tween.tween_property(anim, "scale", base_scale, 0.14).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		hit_tween.tween_callback(func(): anim.scale = base_scale)
		_spawn_hit_fx()
	print("Sheep受击 | 伤害=", amount, " | HP=", health)
	if health <= 0:
		_die()

func _spawn_hit_fx() -> void:
	if hit_fx_defs.is_empty():
		return
	var fx = hit_fx_defs.pick_random()
	var texture = fx["texture"]
	var frame_count = int(fx["frames"])
	_spawn_world_fx(texture, frame_count, global_position + Vector2(0, -8), Vector2(0.6, 0.6))

func _spawn_world_fx(texture: Texture2D, frame_count: int, fx_position: Vector2, fx_scale: Vector2) -> void:
	if texture == null or frame_count <= 0:
		return
	var sprite_fx = AnimatedSprite2D.new()
	sprite_fx.sprite_frames = _build_fx_frames(texture, frame_count, 12.0)
	sprite_fx.animation = "fx"
	sprite_fx.global_position = fx_position
	sprite_fx.scale = fx_scale
	sprite_fx.z_index = 12
	var root = get_tree().current_scene
	if root:
		root.add_child(sprite_fx)
	sprite_fx.play()
	if not sprite_fx.animation_finished.is_connected(sprite_fx.queue_free):
		sprite_fx.animation_finished.connect(sprite_fx.queue_free)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_fx, "scale", fx_scale * 1.2, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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

func _enter_idle() -> void:
	state_timer = randf_range(idle_time_range.x, idle_time_range.y)
	if randf() < eat_chance:
		state = "grass"
		anim.play("grass")
	else:
		state = "idle"
		anim.play("idle")

func _enter_move() -> void:
	state = "move"
	state_timer = randf_range(move_time_range.x, move_time_range.y)
	if roam_cells.is_empty():
		target_position = home_position + Vector2(randf_range(-roam_radius, roam_radius), randf_range(-roam_radius, roam_radius))
	else:
		var target_cell = roam_cells.pick_random()
		target_position = roam_layer.map_to_local(target_cell)
	anim.play("move")

func _build_animations() -> void:
	var frames = SpriteFrames.new()
	_add_strip(frames, "idle", idle_texture, 6, idle_fps)
	_add_strip(frames, "move", move_texture, 4, move_fps)
	_add_strip(frames, "grass", grass_texture, 12, grass_fps)
	anim.sprite_frames = frames

func _add_strip(frames: SpriteFrames, anim_name: String, texture: Texture2D, frame_count: int, fps: float) -> void:
	if texture == null:
		return
	frames.add_animation(anim_name)
	var frame_width = texture.get_width() / float(frame_count)
	var frame_height = texture.get_height()
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame(anim_name, atlas)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)

func _die() -> void:
	if drop_item_scene:
		var drop_count = randi_range(min_drop, max_drop)
		for i in range(drop_count):
			var drop_instance = drop_item_scene.instantiate()
			if drop_instance:
				get_parent().call_deferred("add_child", drop_instance)
				if "item_type" in drop_instance:
					drop_instance.item_type = drop_item_type
				if drop_instance.has_method("_refresh_texture"):
					drop_instance.call_deferred("_refresh_texture")
				var offset = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
				drop_instance.set_deferred("global_position", global_position + offset)
	queue_free()

func setup_roam(layer: TileMapLayer, cell: Vector2i, radius_cells: int) -> void:
	roam_layer = layer
	home_cell = cell
	home_position = roam_layer.map_to_local(home_cell)
	roam_cells = _collect_cells_in_radius(roam_layer.get_used_cells(), home_cell, radius_cells)

func _collect_cells_in_radius(cells: Array[Vector2i], center: Vector2i, radius_cells: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center_vec = Vector2(center)
	for c in cells:
		if (Vector2(c) - center_vec).length() <= radius_cells:
			result.append(c)
	return result
