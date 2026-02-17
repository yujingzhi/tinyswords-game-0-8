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
	if health <= 0:
		_die()

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
