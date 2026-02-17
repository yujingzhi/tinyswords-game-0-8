extends CharacterBody2D

@export var max_health: int = 3
@export var roam_radius: float = 120.0
@export var roam_cell_radius: int = 4
@export var move_speed: float = 40.0
@export var attack_range: float = 220.0
@export var shoot_interval: float = 1.4
@export var shoot_anim_time: float = 0.4
@export var arrow_speed: float = 260.0
@export var damage: int = 1
@export var idle_texture: Texture2D
@export var move_texture: Texture2D
@export var shoot_texture: Texture2D
@export var idle_frames: int = 6
@export var move_frames: int = 4
@export var shoot_frames: int = 8
@export var idle_fps: float = 6.0
@export var move_fps: float = 8.0
@export var shoot_fps: float = 10.0
@export var idle_time_range: Vector2 = Vector2(0.6, 1.6)
@export var move_time_range: Vector2 = Vector2(0.8, 1.8)
@export var arrow_scene: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: TextureProgressBar = $HealthBar

var current_health: int
var shoot_timer: float = 0.0
var anim_timer: float = 0.0
var home_position: Vector2
var target_position: Vector2
var state: String = "idle"
var state_timer: float = 0.0
var roam_layer: TileMapLayer
var roam_cells: Array[Vector2i] = []
var home_cell: Vector2i

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health
	_update_health_bar()
	home_position = global_position
	_build_animations()
	_enter_idle()

func _physics_process(delta: float) -> void:
	shoot_timer -= delta
	if anim_timer > 0.0:
		anim_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if anim_timer <= 0.0:
			_enter_idle()
		return

	var player = get_tree().get_first_node_in_group("peao")
	if player != null:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= attack_range and shoot_timer <= 0.0:
			_shoot(player.global_position)
			return

	if state == "move":
		var to_target = target_position - global_position
		if to_target.length() <= 2.0:
			_enter_idle()
		else:
			velocity = to_target.normalized() * move_speed
			move_and_slide()
			if anim:
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
	current_health = max(current_health - amount, 0)
	_update_health_bar()
	if current_health <= 0:
		queue_free()

func _shoot(target_global_position: Vector2) -> void:
	shoot_timer = shoot_interval
	if anim:
		anim.play("shoot")
		anim_timer = shoot_anim_time
	var direction = (target_global_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if anim:
		anim.flip_h = direction.x < 0
	if arrow_scene:
		var arrow = arrow_scene.instantiate()
		if arrow:
			arrow.global_position = global_position + Vector2(0, -8)
			if arrow.has_method("setup"):
				arrow.setup(direction, arrow_speed, damage)
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
	frames.add_animation(anim_name)
	var frame_width = texture.get_width() / float(frame_count)
	var frame_height = texture.get_height()
	for i in range(frame_count):
		var region = Rect2(i * frame_width, 0, frame_width, frame_height)
		var frame_tex = AtlasTexture.new()
		frame_tex.atlas = texture
		frame_tex.region = region
		frames.add_frame(anim_name, frame_tex)
	frames.set_animation_speed(anim_name, fps)

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func _enter_idle() -> void:
	state = "idle"
	state_timer = randf_range(idle_time_range.x, idle_time_range.y)
	if anim:
		anim.play("idle")

func _enter_move() -> void:
	state = "move"
	state_timer = randf_range(move_time_range.x, move_time_range.y)
	if roam_cells.is_empty():
		target_position = home_position + Vector2(randf_range(-roam_radius, roam_radius), randf_range(-roam_radius, roam_radius))
	else:
		var target_cell = roam_cells.pick_random()
		target_position = roam_layer.map_to_local(target_cell)
	if anim:
		anim.play("move")

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
