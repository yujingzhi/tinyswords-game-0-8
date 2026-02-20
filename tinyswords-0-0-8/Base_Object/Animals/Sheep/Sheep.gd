extends CharacterBody2D
class_name Sheep
# 绵羊的简单 AI：在原地附近闲逛、吃草、受击掉落

signal died(world_position: Vector2)

@export var roam_radius: float = 120.0
@export var roam_cell_radius: int = 4
@export var move_speed: float = 40.0
@export var idle_fps: float = 6.0
@export var move_fps: float = 8.0
@export var grass_fps: float = 8.0
@export var idle_frame_count: int = 6
@export var move_frame_count: int = 4
@export var grass_frame_count: int = 12
@export var idle_time_range: Vector2 = Vector2(0.6, 1.6)
@export var move_time_range: Vector2 = Vector2(0.8, 1.8)
@export var eat_chance: float = 0.35
@export var health: int = 3
@export var min_drop: int = 1
@export var max_drop: int = 2
@export var drop_item_type: String = "meat"
@export var drop_item_scene: PackedScene = preload("res://Base_Object/PhysicItem.tscn")
@export var lamb_drop_chance: float = 0.03
@export var lamb_item_type: String = "lamb"
@export var lamb_entity_scene: PackedScene = preload("res://Base_Object/Animals/Sheep/Sheep.tscn")
@export var idle_texture: Texture2D = preload("res://Base_Object/Animals/Sheep/Sheep_Idle.png")
@export var move_texture: Texture2D = preload("res://Base_Object/Animals/Sheep/Sheep_Move.png")
@export var grass_texture: Texture2D = preload("res://Base_Object/Animals/Sheep/Sheep_Grass.png")
@export var worker_mode: bool = false
@export var worker_scan_interval: float = 0.6
@export var worker_gather_radius: float = 260.0
@export var worker_harvest_range: float = 18.0
@export var worker_harvest_damage: int = 1
@export var worker_harvest_time: float = 0.6
@export var worker_pickup_range: float = 16.0
@export var worker_storage_range: float = 18.0
@export var worker_carry_capacity: int = 1
@export var worker_wander_radius: float = 320.0
@export var worker_wander_interval: float = 1.2
@export var worker_detour_distance: float = 64.0
@export var worker_stuck_time: float = 0.6
@export var worker_stuck_min_move: float = 1
@export var worker_empty_idle_texture: Texture2D
@export var worker_empty_move_texture: Texture2D
@export var worker_carry_idle_texture: Texture2D
@export var worker_carry_move_texture: Texture2D
@export var worker_carry_gold_idle_texture: Texture2D
@export var worker_carry_gold_move_texture: Texture2D
@export var worker_carry_meat_idle_texture: Texture2D
@export var worker_carry_meat_move_texture: Texture2D
@export var worker_axe_texture: Texture2D
@export var worker_pickaxe_texture: Texture2D
@export var worker_knife_texture: Texture2D
@export var worker_work_frame_count: int = 6
@export var worker_work_fps: float = 10.0
@export var logistics_enabled: bool = true
@export var logistics_scan_interval: float = 0.6
@export var logistics_pickup_radius: float = 220.0
@export var logistics_drop_radius: float = 18.0
@export var logistics_group: StringName = &"sheep"
# 上面都是可在编辑器中调整的参数，包括移动范围、动画速度和掉落

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var carry_sprite: Sprite2D = $CarrySprite
@onready var carry_label: Label = $CarryLabel
@onready var pickup_area: Area2D = get_node_or_null("PickupArea") as Area2D
# AnimatedSprite2D 用于播放帧动画

var item_type: String = ""
var home_position: Vector2
var target_position: Vector2
var state: String = "idle"
var state_timer: float = 0.0
var roam_layer: TileMapLayer
var roam_cells: Array[Vector2i] = []
var home_cell: Vector2i
var hit_tween: Tween
var base_move_speed: float = 0.0
var logistics_multiplier: float = 1.0
var boost_multiplier: float = 1.0
var boost_timer: float = 0.0
var logistics_scan_timer: float = 0.0
var logistics_target_item: Node2D
var logistics_target_pile: Node2D
var logistics_carrying: bool = false
var worker_target_resource: Node2D
var worker_target_item: Node2D
var worker_harvest_timer: float = 0.0
var worker_scan_timer: float = 0.0
var worker_carry_item_type: String = ""
var worker_carry_count: int = 0
var worker_storage_target: Node2D
var worker_wander_timer: float = 0.0
var worker_wander_target: Vector2 = Vector2.ZERO
var worker_wander_active: bool = false
var worker_nav_last_pos: Vector2 = Vector2.ZERO
var worker_nav_stuck_timer: float = 0.0
var worker_nav_detour_target: Vector2 = Vector2.ZERO
var worker_nav_detour_active: bool = false
var is_baby: bool = false
var is_mutant: bool = false
var mutate_timer: float = 0.0
var pickup_item_enabled: bool = false
var hit_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Dust_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Dust_02.png"), "frames": 10}
]
const WORKER_CARRY_TEXTURES: Dictionary = {
	"wood": preload("res://Base_Object/Wood_Resource.png"),
	"gold": preload("res://Base_Object/Gold_Resource.png"),
	"meat": preload("res://Base_Object/Resources/Meat/Meat_Resource.png"),
	"redwood": preload("res://Base_Object/Wood_Resource.png"),
	"red_meat": preload("res://Base_Object/Resources/Meat/Meat_Resource.png"),
	"rainbow_gold": preload("res://Base_Object/Gold_Resource.png")
}
# hit_fx_defs 用于受击时随机播放沙尘特效

func _ready() -> void:
	# 初始化出生位置与动画
	add_to_group(logistics_group)
	base_move_speed = move_speed
	home_position = global_position
	_build_animations()
	_enter_idle()
	_apply_variant_visuals()
	_update_carry_visual()
	_enable_pickup_mode_if_needed()

func _physics_process(delta: float) -> void:
	if mutate_timer > 0.0:
		mutate_timer -= delta
		if mutate_timer <= 0.0:
			mutate_timer = 0.0
			set_mutant(true)
	# 简单状态机：move 与 idle/grass 之间切换
	if boost_timer > 0.0:
		boost_timer -= delta
		if boost_timer <= 0.0:
			boost_timer = 0.0
			boost_multiplier = 1.0
	if worker_mode:
		_update_worker(delta)
		return
	if _handle_logistics(delta):
		return
	if state == "move":
		var to_target = target_position - global_position
		if to_target.length() <= 2.0:
			_enter_idle()
		else:
			var final_speed = base_move_speed * logistics_multiplier * boost_multiplier
			velocity = to_target.normalized() * final_speed
			move_and_slide()
			anim.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
	# 计时器到期后切换状态
	state_timer -= delta
	if state_timer <= 0.0:
		if state == "move":
			_enter_idle()
		else:
			_enter_move()

func take_damage(amount: int) -> void:
	# 受击时扣血并播放缩放特效
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

func receive_pickup(pickup_type: String) -> bool:
	if not worker_mode:
		return false
	if worker_carry_count > 0:
		return false
	worker_carry_item_type = pickup_type
	worker_carry_count = min(worker_carry_capacity, 1)
	worker_target_item = null
	_update_carry_visual()
	return true

func _spawn_hit_fx() -> void:
	# 随机选取尘土特效
	if hit_fx_defs.is_empty():
		return
	var fx = hit_fx_defs.pick_random()
	var texture = fx["texture"]
	var frame_count = int(fx["frames"])
	_spawn_world_fx(texture, frame_count, global_position + Vector2(0, -8), Vector2(0.6, 0.6))

func _spawn_world_fx(texture: Texture2D, frame_count: int, fx_position: Vector2, fx_scale: Vector2) -> void:
	# 在世界中播放一次性动画并自动销毁
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
	# 从一张精灵表切出多帧
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
	# 进入休息或吃草状态，随机决定是否吃草
	state_timer = randf_range(idle_time_range.x, idle_time_range.y)
	if randf() < eat_chance:
		state = "grass"
		anim.play("grass")
	else:
		state = "idle"
		anim.play("idle")

func _enter_move() -> void:
	# 进入移动状态，选择一个随机目标点
	state = "move"
	state_timer = randf_range(move_time_range.x, move_time_range.y)
	if roam_cells.is_empty():
		target_position = home_position + Vector2(randf_range(-roam_radius, roam_radius), randf_range(-roam_radius, roam_radius))
	else:
		var target_cell = roam_cells.pick_random()
		target_position = roam_layer.map_to_local(target_cell)
	anim.play("move")

func _build_animations() -> void:
	# 将多张贴图切成动画并组合成 SpriteFrames
	var frames = SpriteFrames.new()
	_add_strip(frames, "idle", idle_texture, idle_frame_count, idle_fps)
	_add_strip(frames, "move", move_texture, move_frame_count, move_fps)
	_add_strip(frames, "grass", grass_texture, grass_frame_count, grass_fps)
	_add_strip(frames, "idle_empty", worker_empty_idle_texture, idle_frame_count, idle_fps)
	_add_strip(frames, "move_empty", worker_empty_move_texture, move_frame_count, move_fps)
	_add_strip(frames, "idle_carry", worker_carry_idle_texture, idle_frame_count, idle_fps)
	_add_strip(frames, "move_carry", worker_carry_move_texture, move_frame_count, move_fps)
	_add_strip(frames, "idle_carry_gold", worker_carry_gold_idle_texture, idle_frame_count, idle_fps)
	_add_strip(frames, "move_carry_gold", worker_carry_gold_move_texture, move_frame_count, move_fps)
	_add_strip(frames, "idle_carry_meat", worker_carry_meat_idle_texture, idle_frame_count, idle_fps)
	_add_strip(frames, "move_carry_meat", worker_carry_meat_move_texture, move_frame_count, move_fps)
	_add_strip(frames, "work_axe", worker_axe_texture, worker_work_frame_count, worker_work_fps)
	_add_strip(frames, "work_pickaxe", worker_pickaxe_texture, worker_work_frame_count, worker_work_fps)
	_add_strip(frames, "work_knife", worker_knife_texture, worker_work_frame_count, worker_work_fps)
	anim.sprite_frames = frames

func _add_strip(frames: SpriteFrames, anim_name: String, texture: Texture2D, frame_count: int, fps: float) -> void:
	if texture == null:
		return
	var final_frame_count = frame_count
	var width = texture.get_width()
	var height = texture.get_height()
	if final_frame_count <= 0:
		final_frame_count = max(1, int(round(width / max(1.0, float(height)))))
	var guessed = max(1, int(round(width / max(1.0, float(height)))))
	if anim_name.begins_with("work_") and guessed != final_frame_count and width % guessed == 0 and guessed <= 12:
		final_frame_count = guessed
	elif width % final_frame_count != 0:
		if guessed != final_frame_count and width % guessed == 0:
			final_frame_count = guessed
	frames.add_animation(anim_name)
	var frame_width = width / float(final_frame_count)
	for i in range(final_frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_width, 0, frame_width, height)
		frames.add_frame(anim_name, atlas)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)

func _die() -> void:
	# 死亡后生成掉落物并销毁自己
	died.emit(global_position)
	if pickup_item_enabled:
		queue_free()
		return
	var spawn_lamb = (not worker_mode) and (not is_mutant) and (is_baby or (lamb_drop_chance > 0.0 and randf() < lamb_drop_chance))
	if spawn_lamb and lamb_entity_scene != null:
		var lamb_instance = lamb_entity_scene.instantiate()
		if lamb_instance != null:
			if lamb_instance.has_method("setup_as_pickup_lamb"):
				lamb_instance.call("setup_as_pickup_lamb")
			if lamb_instance is Node2D:
				(lamb_instance as Node2D).global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			get_parent().call_deferred("add_child", lamb_instance)
		queue_free()
		return
	if drop_item_scene:
		var drop_count = randi_range(min_drop, max_drop)
		for i in range(drop_count):
			var drop_instance = drop_item_scene.instantiate()
			if drop_instance:
				get_parent().call_deferred("add_child", drop_instance)
				if "item_type" in drop_instance:
					var final_drop_type = drop_item_type
					drop_instance.item_type = final_drop_type
				if drop_instance.has_method("_refresh_texture"):
					drop_instance.call_deferred("_refresh_texture")
				var offset = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
				drop_instance.set_deferred("global_position", global_position + offset)
	queue_free()

func setup_as_pickup_lamb() -> void:
	pickup_item_enabled = true
	item_type = "lamb"
	logistics_group = &"pickup_item"
	logistics_enabled = false
	worker_mode = false
	is_baby = true
	is_mutant = false
	mutate_timer = 0.0
	health = 1
	drop_item_scene = null
	drop_item_type = ""

func configure_released_lamb(time_to_mutate_sec: float) -> void:
	is_baby = true
	is_mutant = false
	mutate_timer = max(0.0, time_to_mutate_sec)
	_apply_variant_visuals()

func set_mutant(enabled: bool) -> void:
	is_mutant = enabled
	if is_mutant:
		is_baby = false
		mutate_timer = 0.0
		drop_item_type = "red_meat"
		health = max(health, 5)
	_apply_variant_visuals()

func _apply_variant_visuals() -> void:
	if anim:
		if pickup_item_enabled:
			anim.modulate = Color(1.0, 0.35, 0.35, 1.0)
		elif is_mutant:
			anim.modulate = Color(1.0, 0.35, 0.35, 1.0)
		else:
			anim.modulate = Color(1, 1, 1, 1)
	if is_baby and not is_mutant:
		scale = Vector2(0.62, 0.62)
	elif is_mutant:
		scale = Vector2(1.0, 1.0)
	else:
		scale = Vector2(1.0, 1.0)

func _enable_pickup_mode_if_needed() -> void:
	if not pickup_item_enabled:
		if pickup_area != null:
			pickup_area.monitoring = false
			pickup_area.monitorable = false
		return
	add_to_group(&"pickup_item")
	if pickup_area != null:
		pickup_area.monitoring = true
		pickup_area.monitorable = true
		pickup_area.collision_layer = 0
		pickup_area.collision_mask = 1
		if not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
			pickup_area.body_entered.connect(_on_pickup_area_body_entered)

func _on_pickup_area_body_entered(body: Node2D) -> void:
	if not pickup_item_enabled:
		return
	if body == null or not is_instance_valid(body):
		return
	if body.is_in_group(&"player") or body.is_in_group(&"peao"):
		get_tree().call_group(&"interface", &"add_item", item_type, 1)
		queue_free()

func setup_roam(layer: TileMapLayer, cell: Vector2i, radius_cells: int) -> void:
	# 设置基于瓦片坐标的漫游范围
	roam_layer = layer
	home_cell = cell
	home_position = roam_layer.map_to_local(home_cell)
	roam_cells = _collect_cells_in_radius(roam_layer.get_used_cells(), home_cell, radius_cells)

func _collect_cells_in_radius(cells: Array[Vector2i], center: Vector2i, radius_cells: int) -> Array[Vector2i]:
	# 筛选出以中心为圆心的半径内瓦片
	var result: Array[Vector2i] = []
	var center_vec = Vector2(center)
	for c in cells:
		if (Vector2(c) - center_vec).length() <= radius_cells:
			result.append(c)
	return result

func apply_speed_boost(multiplier: float, duration: float) -> void:
	boost_multiplier = max(1.0, multiplier)
	boost_timer = max(0.0, duration)

func set_logistics_multiplier(multiplier: float) -> void:
	logistics_multiplier = max(0.1, multiplier)

func set_logistics_enabled(enabled: bool) -> void:
	logistics_enabled = enabled
	if not logistics_enabled:
		logistics_target_item = null
		logistics_target_pile = null
		logistics_carrying = false

func _handle_logistics(delta: float) -> bool:
	if not logistics_enabled:
		return false
	if logistics_target_pile == null or not is_instance_valid(logistics_target_pile):
		logistics_target_pile = _pick_nearest_pile()
	if logistics_target_pile == null:
		return false
	logistics_scan_timer -= delta
	if logistics_scan_timer <= 0.0:
		logistics_scan_timer = logistics_scan_interval
		if not logistics_carrying:
			if logistics_target_item == null or not is_instance_valid(logistics_target_item):
				logistics_target_item = _find_nearest_item()
	if logistics_carrying:
		if _move_to_position(logistics_target_pile.global_position, logistics_drop_radius):
			logistics_carrying = false
		return true
	if logistics_target_item == null or not is_instance_valid(logistics_target_item):
		return false
	if _move_to_position(logistics_target_item.global_position, 10.0):
		if logistics_target_item.has_method("auto_collect"):
			logistics_target_item.call("auto_collect")
		logistics_target_item = null
		logistics_carrying = true
	return true

func _move_to_position(target_pos: Vector2, reach_distance: float) -> bool:
	var to_target = target_pos - global_position
	if to_target.length() <= reach_distance:
		velocity = Vector2.ZERO
		return true
	state = "move"
	anim.play("move")
	var final_speed = base_move_speed * logistics_multiplier * boost_multiplier
	velocity = to_target.normalized() * final_speed
	move_and_slide()
	anim.flip_h = velocity.x < 0
	return false

func _find_nearest_item() -> Node2D:
	var items = get_tree().get_nodes_in_group("pickup_item")
	var nearest: Node2D = null
	var best_dist = logistics_pickup_radius
	for item in items:
		if not (item is Node2D):
			continue
		if not is_instance_valid(item):
			continue
		var d = global_position.distance_to(item.global_position)
		if d <= best_dist:
			best_dist = d
			nearest = item
	return nearest

func _pick_nearest_pile() -> Node2D:
	var piles = get_tree().get_nodes_in_group("collection_pile")
	var nearest: Node2D = null
	var best_dist = INF
	for pile in piles:
		if not (pile is Node2D):
			continue
		if not is_instance_valid(pile):
			continue
		var d = global_position.distance_to(pile.global_position)
		if d < best_dist:
			best_dist = d
			nearest = pile
	return nearest

func _update_worker(delta: float) -> void:
	_update_carry_visual()
	worker_scan_timer -= delta
	worker_wander_timer -= delta
	if worker_carry_count > 0:
		if worker_storage_target == null or not is_instance_valid(worker_storage_target):
			worker_storage_target = _pick_nearest_storage()
		if worker_storage_target != null:
			if _worker_move_to_position(worker_storage_target.global_position, worker_storage_range):
				get_tree().call_group(&"interface", &"add_item", worker_carry_item_type, worker_carry_count)
				worker_carry_item_type = ""
				worker_carry_count = 0
				worker_target_item = null
				worker_target_resource = null
				_update_carry_visual()
				_play_worker_idle()
		else:
			velocity = Vector2.ZERO
			_play_worker_idle()
		return
	if worker_scan_timer <= 0.0:
		worker_scan_timer = worker_scan_interval
		var item_candidate = _find_nearest_pickup()
		if item_candidate != null and is_instance_valid(item_candidate):
			if worker_target_item == null or not is_instance_valid(worker_target_item):
				worker_target_item = item_candidate
			else:
				var current_dist = global_position.distance_to(worker_target_item.global_position)
				var candidate_dist = global_position.distance_to(item_candidate.global_position)
				if candidate_dist < current_dist:
					worker_target_item = item_candidate
		var resource_candidate = _find_nearest_resource_with_radius(INF)
		if resource_candidate != null and is_instance_valid(resource_candidate):
			if worker_target_resource == null or not is_instance_valid(worker_target_resource):
				worker_target_resource = resource_candidate
			else:
				var current_res_dist = global_position.distance_to(worker_target_resource.global_position)
				var candidate_res_dist = global_position.distance_to(resource_candidate.global_position)
				if candidate_res_dist < current_res_dist:
					worker_target_resource = resource_candidate
	if worker_target_item != null:
		worker_wander_active = false
		if _worker_move_to_position(worker_target_item.global_position, worker_pickup_range):
			if "item_type" in worker_target_item:
				worker_carry_item_type = worker_target_item.item_type
				worker_carry_count = min(worker_carry_capacity, 1)
				_update_carry_visual()
			worker_target_item.queue_free()
			worker_target_item = null
		return
	if worker_target_resource == null or not is_instance_valid(worker_target_resource):
		worker_target_resource = null
	if worker_target_resource == null:
		_update_worker_wander()
		return
	worker_wander_active = false
	if _worker_move_to_position(worker_target_resource.global_position, worker_harvest_range):
		worker_harvest_timer -= delta
		if worker_harvest_timer <= 0.0:
			worker_harvest_timer = worker_harvest_time
			_play_worker_harvest_anim(worker_target_resource)
			_apply_worker_harvest(worker_target_resource)
	else:
		worker_harvest_timer = worker_harvest_time

func _find_nearest_resource() -> Node2D:
	return _find_nearest_resource_with_radius(worker_gather_radius)

func _find_nearest_resource_with_radius(radius: float) -> Node2D:
	var nearest: Node2D = null
	var best_dist = radius
	var obstacles = get_tree().get_nodes_in_group("obstacle")
	for obj in obstacles:
		if not (obj is Node2D):
			continue
		if not is_instance_valid(obj):
			continue
		if "drop_item_type" in obj:
			var drop_type = obj.drop_item_type
			if drop_type != "wood" and drop_type != "redwood" and drop_type != "gold" and drop_type != "rainbow_gold":
				continue
		var d = global_position.distance_to(obj.global_position)
		if d <= best_dist:
			best_dist = d
			nearest = obj
	var sheep_list = get_tree().get_nodes_in_group(&"sheep")
	for sheep in sheep_list:
		if not (sheep is Node2D):
			continue
		if not is_instance_valid(sheep):
			continue
		if "worker_mode" in sheep and sheep.worker_mode:
			continue
		var dist = global_position.distance_to(sheep.global_position)
		if dist <= best_dist:
			best_dist = dist
			nearest = sheep
	return nearest

func _find_nearest_pickup() -> Node2D:
	var items = get_tree().get_nodes_in_group(&"pickup_item")
	var nearest: Node2D = null
	var best_dist = worker_gather_radius
	for item in items:
		if not (item is Node2D):
			continue
		if not is_instance_valid(item):
			continue
		var d = global_position.distance_to(item.global_position)
		if d <= best_dist:
			best_dist = d
			nearest = item
	return nearest

func _pick_nearest_storage() -> Node2D:
	var stores = get_tree().get_nodes_in_group(&"storage")
	var nearest: Node2D = null
	var best_dist = INF
	for store in stores:
		if not (store is Node2D):
			continue
		if not is_instance_valid(store):
			continue
		var d = global_position.distance_to(store.global_position)
		if d < best_dist:
			best_dist = d
			nearest = store
	return nearest

func _play_worker_harvest_anim(target: Node2D) -> void:
	if anim == null:
		return
	anim.flip_h = target.global_position.x < global_position.x
	if target is ObjectBase:
		if "drop_item_type" in target and (target.drop_item_type == "gold" or target.drop_item_type == "rainbow_gold"):
			anim.play("work_pickaxe")
		else:
			anim.play("work_axe")
	elif target is Sheep:
		anim.play("work_knife")

func _apply_worker_harvest(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		worker_target_resource = null
		return
	if target is ObjectBase:
		target.update_health(worker_harvest_damage)
		if not is_instance_valid(target):
			worker_target_resource = null
	elif target is Sheep:
		if "worker_mode" in target and target.worker_mode:
			return
		target.take_damage(worker_harvest_damage)
		if not is_instance_valid(target):
			worker_target_resource = null

func _update_carry_visual() -> void:
	if carry_sprite == null:
		return
	if worker_carry_count <= 0 or worker_carry_item_type.is_empty():
		carry_sprite.visible = false
		carry_sprite.modulate = Color(1, 1, 1, 1)
		if carry_label:
			carry_label.visible = false
		return
	carry_sprite.visible = true
	carry_sprite.texture = WORKER_CARRY_TEXTURES.get(worker_carry_item_type, WORKER_CARRY_TEXTURES["wood"])
	if worker_carry_item_type == "redwood" or worker_carry_item_type == "red_meat":
		carry_sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
	elif worker_carry_item_type == "rainbow_gold":
		var h = fmod(abs(float(get_instance_id())) * 0.000001, 1.0)
		carry_sprite.modulate = Color.from_hsv(h, 0.75, 1.0, 1.0)
	else:
		carry_sprite.modulate = Color(1, 1, 1, 1)
	if carry_label:
		carry_label.visible = true
		carry_label.text = str(worker_carry_count)

func _is_path_blocked(from_pos: Vector2, to_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	params.exclude = [self]
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var result = space_state.intersect_ray(params)
	if result.is_empty():
		return false
	var collider = result.get("collider")
	if collider == null:
		return false
	if collider is Node and collider.is_in_group("obstacle"):
		return true
	return false

func _find_blocking_obstacle(from_pos: Vector2, to_pos: Vector2) -> Node2D:
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	params.exclude = [self]
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var result = space_state.intersect_ray(params)
	if result.is_empty():
		return null
	var collider = result.get("collider")
	if collider == null:
		return null
	if collider is Node2D and collider.is_in_group("obstacle"):
		return collider
	return null

func _get_obstacle_radius(obstacle: Node2D) -> float:
	var max_radius := 0.0
	var shapes = obstacle.find_children("*", "CollisionShape2D", true, false)
	for shape_node in shapes:
		if not (shape_node is CollisionShape2D):
			continue
		var shape = shape_node.shape
		if shape == null:
			continue
		var radius := 0.0
		if shape is CircleShape2D:
			radius = shape.radius
		elif shape is RectangleShape2D:
			radius = shape.size.length() * 0.5
		elif shape is CapsuleShape2D:
			radius = max(shape.radius, shape.height * 0.5)
		elif shape is ConvexPolygonShape2D:
			for p in shape.points:
				radius = max(radius, p.length())
		elif shape is ConcavePolygonShape2D:
			var data = shape.segments
			for i in range(0, data.size(), 2):
				radius = max(radius, data[i].length())
				radius = max(radius, data[i + 1].length())
		else:
			radius = worker_detour_distance
		var shape_scale = shape_node.global_scale
		var scaled_radius = radius * max(abs(shape_scale.x), abs(shape_scale.y))
		max_radius = max(max_radius, scaled_radius)
	if max_radius <= 0.0:
		max_radius = worker_detour_distance
	return max_radius

func _get_detour_target(goal_position: Vector2) -> Vector2:
	var obstacle = _find_blocking_obstacle(global_position, goal_position)
	if obstacle == null:
		return Vector2.ZERO
	var dir = (goal_position - global_position).normalized()
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	var clearance = _get_obstacle_radius(obstacle) + worker_detour_distance
	var side = Vector2(-dir.y, dir.x)
	var left = obstacle.global_position + side * clearance
	var right = obstacle.global_position - side * clearance
	var left_ok = not _is_path_blocked(global_position, left) and not _is_path_blocked(left, goal_position)
	var right_ok = not _is_path_blocked(global_position, right) and not _is_path_blocked(right, goal_position)
	if left_ok and right_ok:
		if left.distance_to(goal_position) <= right.distance_to(goal_position):
			return left
		return right
	if left_ok:
		return left
	if right_ok:
		return right
	return Vector2.ZERO

func _worker_move_to_position(target_pos: Vector2, reach_distance: float) -> bool:
	var goal_position = target_pos
	if worker_nav_detour_active:
		var detour_to = worker_nav_detour_target - global_position
		var detour_reach = min(reach_distance, 6.0)
		if detour_to.length() <= detour_reach:
			worker_nav_detour_active = false
			worker_nav_stuck_timer = 0.0
			worker_nav_last_pos = global_position
	var current_target = goal_position
	if worker_nav_detour_active:
		current_target = worker_nav_detour_target
	var to_target = current_target - global_position
	if not worker_nav_detour_active and to_target.length() <= reach_distance:
		velocity = Vector2.ZERO
		worker_nav_stuck_timer = 0.0
		worker_nav_last_pos = global_position
		return true
	state = "move"
	_play_worker_move()
	var final_speed = base_move_speed * logistics_multiplier * boost_multiplier
	velocity = to_target.normalized() * final_speed
	move_and_slide()
	anim.flip_h = velocity.x < 0
	var moved = global_position.distance_to(worker_nav_last_pos)
	if moved < worker_stuck_min_move:
		worker_nav_stuck_timer += get_physics_process_delta_time()
	else:
		worker_nav_stuck_timer = 0.0
	worker_nav_last_pos = global_position
	if worker_nav_stuck_timer >= worker_stuck_time:
		worker_nav_stuck_timer = 0.0
		var detour_target = _get_detour_target(goal_position)
		if detour_target == Vector2.ZERO:
			var dir = to_target.normalized()
			var side = Vector2(-dir.y, dir.x)
			if randf() < 0.5:
				side = -side
			detour_target = global_position + side * worker_detour_distance
		worker_nav_detour_target = detour_target
		worker_nav_detour_active = true
	return false

func _worker_is_carrying() -> bool:
	return worker_carry_count > 0 and not worker_carry_item_type.is_empty()

func _play_worker_idle() -> void:
	if anim == null:
		return
	if _worker_is_carrying():
		var carry_anim = _get_worker_carry_idle_anim()
		if anim.sprite_frames.has_animation(carry_anim):
			anim.play(carry_anim)
			return
	elif anim.sprite_frames.has_animation("idle_empty"):
		anim.play("idle_empty")
	else:
		anim.play("idle")

func _play_worker_move() -> void:
	if anim == null:
		return
	if _worker_is_carrying():
		var carry_anim = _get_worker_carry_move_anim()
		if anim.sprite_frames.has_animation(carry_anim):
			anim.play(carry_anim)
			return
	elif anim.sprite_frames.has_animation("move_empty"):
		anim.play("move_empty")
	else:
		anim.play("move")

func _get_worker_carry_idle_anim() -> String:
	if worker_carry_item_type == "gold":
		return "idle_carry_gold"
	if worker_carry_item_type == "meat":
		return "idle_carry_meat"
	return "idle_carry"

func _get_worker_carry_move_anim() -> String:
	if worker_carry_item_type == "gold":
		return "move_carry_gold"
	if worker_carry_item_type == "meat":
		return "move_carry_meat"
	return "move_carry"

func _update_worker_wander() -> void:
	if worker_wander_active:
		if _worker_move_to_position(worker_wander_target, 6.0):
			worker_wander_active = false
			worker_wander_timer = worker_wander_interval
			_play_worker_idle()
		return
	if worker_wander_timer > 0.0:
		state = "idle"
		velocity = Vector2.ZERO
		_play_worker_idle()
		return
	var offset = Vector2(randf_range(-worker_wander_radius, worker_wander_radius), randf_range(-worker_wander_radius, worker_wander_radius))
	worker_wander_target = home_position + offset
	worker_wander_active = true
