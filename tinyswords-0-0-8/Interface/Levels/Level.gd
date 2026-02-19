extends Node2D
class_name Level
# 关卡管理：负责随机生成资源物体、羊与弓箭手

# --- 配置变量 ---
# 1. 在检查器里，把 Tree.tscn 和 Rock.tscn 拖进这个数组
@export var object_scenes: Array[PackedScene] = []
# 这里放可生成的场景（例如树、矿石）

# 2. 你想生成多少个物体？
@export var total_objects: int = 40
@export var sheep_scene: PackedScene
@export var total_sheep: int = 6
@export var sheep_roam_cell_radius: int = 4
@export var archer_scene: PackedScene
@export var total_archers: int = 3
@export var archer_roam_cell_radius: int = 4
# total_* 控制生成数量，*_roam_cell_radius 控制漫游范围

@export var use_noise_terrain: bool = true
@export var map_width: int = 64
@export var map_height: int = 64
@export var noise_seed: int = 1337
@export var noise_frequency: float = 0.06
@export var noise_octaves: int = 3
@export var noise_lacunarity: float = 2.0
@export var noise_gain: float = 0.5
@export var water_threshold: float = 0.35
@export var water_border_screens: int = 1
@export var pond_count_min: int = 2
@export var pond_count_max: int = 3
@export var pond_radius_min: int = 1
@export var pond_radius_max: int = 2
@export var tree_noise_min: float = 0.4
@export var tree_noise_max: float = 0.6
@export var tree_density: float = 0.18
@export var rock_noise_threshold: float = 0.7
@export var rock_seed_density: float = 0.06
@export var rock_scatter_density: float = 0.02
@export var gold_scatter_density: float = 0.008
@export var rock_cluster_seed_ratio: float = 0.06
@export var rock_cluster_size_min: int = 4
@export var rock_cluster_size_max: int = 10
@export var rock_cluster_expand_chance: float = 0.65
@export var gold_ratio: float = 0.3
@export var max_tree_count: int = 220
@export var max_rock_count: int = 140
@export var max_gold_count: int = 80
@export var ground_source_id: int = 0
@export var ground_atlas: Vector2i = Vector2i(1, 1)
@export var ground_atlas_tl: Vector2i = Vector2i(0, 0)
@export var ground_atlas_t: Vector2i = Vector2i(1, 0)
@export var ground_atlas_tr: Vector2i = Vector2i(2, 0)
@export var ground_atlas_l: Vector2i = Vector2i(0, 1)
@export var ground_atlas_r: Vector2i = Vector2i(2, 1)
@export var ground_atlas_bl: Vector2i = Vector2i(0, 2)
@export var ground_atlas_b: Vector2i = Vector2i(1, 2)
@export var ground_atlas_br: Vector2i = Vector2i(2, 2)
@export var water_source_id: int = 4
@export var water_atlas: Vector2i = Vector2i(0, 0)
@export var water_foam_source_id: int = 3
@export var water_foam_atlas: Vector2i = Vector2i(0, 0)
@export var worker_scene: PackedScene = preload("res://Base_Object/Animals/Sheep/Sheep.tscn")
@export var total_workers: int = 10
@export var worker_spawn_radius: float = 120.0
@export var worker_move_speed: float = 60.0
@export var worker_empty_idle_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Idle.png")
@export var worker_empty_run_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Run.png")
@export var worker_idle_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Idle Wood.png")
@export var worker_run_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Run Wood.png")
@export var worker_gold_idle_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn_Idle Gold.png")
@export var worker_gold_run_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn_Run Gold.png")
@export var worker_meat_idle_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn_Idle Meat.png")
@export var worker_meat_run_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn_Run Meat.png")
@export var worker_axe_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Interact Axe.png")
@export var worker_pickaxe_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Interact Pickaxe.png")
@export var worker_knife_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Interact Knife.png")
@export var worker_idle_frame_count: int = 8
@export var worker_run_frame_count: int = 6
@export var worker_work_frame_count: int = 6
@export var worker_group_name: StringName = &"worker"
@export var worker_spawn_attempts_max: int = 12
@export var auto_workers_only: bool = false
@export var tree_respawn_enabled: bool = true
@export var tree_respawn_delay_min: float = 8.0
@export var tree_respawn_delay_max: float = 16.0
@export var tree_respawn_max_pending: int = 60
@export var tree_respawn_attempts: int = 14

@export var enable_expansion_loop: bool = true
@export var energy_consumes_wood: bool = false
@export var energy_per_wood: int = 2
@export var energy_decay_per_sec: float = 0.5
@export var wood_burn_interval: float = 2.0
@export var wood_burn_per_tick: int = 1
@export var gold_upgrade_cost: int = 6
@export var logistics_speed_per_level: float = 0.12
@export var meat_boost_duration: float = 8.0
@export var meat_boost_multiplier: float = 2.0
@export var threat_energy_step: float = 12.0
@export var archer_wave_interval: float = 10.0
@export var archer_wave_base: int = 1
@export var archer_wave_cap: int = 6
@export var collection_pile_enabled: bool = true
@export var collection_pile_wood_cost: int = 20
@export var collection_pile_gold_cost: int = 4
@export var collection_pile_energy_threshold: float = 8.0
@export var collection_pile_max: int = 3
@export var collection_pile_spawn_radius: float = 120.0
@export var collection_pile_texture: Texture2D = preload("res://Base_Object/Wood_Resource.png")
@export var storage_texture: Texture2D = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Barracks.png")
@export var storage_scale: Vector2 = Vector2(0.65, 0.65)
@export var storage_spawn_radius: float = 60.0
@export var logistics_energy_min: float = 2.0
@export var pile_build_interval: float = 2.0
@export var start_with_charger: bool = true
@export var start_charger_count: int = 1
@export var start_charger_radius: float = 80.0
@export var player_spawn_use_map_center: bool = true
@export var camera_zoom_min: float = 0.6
@export var camera_zoom_max: float = 1.6
@export var camera_zoom_step: float = 0.1
@export var camera_pan_drag_speed: float = 1.0
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 24.0
@export var edge_scroll_speed: float = 420.0
@export var worker_spawn_scatter: bool = true
@export var input_debug_enabled: bool = false
@export var input_debug_toggle_key: Key = KEY_F9

# --- 节点引用 ---
# 注意：路径必须和你场景里的实际名字一致！
# 这是你在 Terrain 里画了蓝色方块的那一层 (通常设为透明)
@onready var spawn_layer: TileMapLayer = $Terrain/SpawnLayer
@onready var sheep_spawn_layer: TileMapLayer = $Terrain/SheepSpawnLayer
# spawn_layer 用于资源物体，sheep_spawn_layer 用于生物

@onready var water_layer: TileMapLayer = $Terrain/water
@onready var water_foam_layer: TileMapLayer = $Terrain/water_foam
@onready var ground_layer: TileMapLayer = $Terrain/Layer_Ground
@onready var ground_layer_2: TileMapLayer = $Terrain/Layer_Ground2
@onready var shadow_layer: TileMapLayer = $Terrain/Shadow
@onready var shadow_layer_2: TileMapLayer = $Terrain/Shadow2
@onready var game_camera: Camera2D = $Objects/peao/GameCamera
@onready var debug_label: Label = $Interface/DebugLabel

# 这是用来存放生成物体的容器 (开启了 Y-Sort 的那个 Node2D)
@onready var objects_container: Node2D = $Objects
# 生成的对象会挂在此容器下，方便统一管理

var land_cells: Array[Vector2i] = []
var tree_cells: Array[Vector2i] = []
var rock_cells: Array[Vector2i] = []
var gold_cells: Array[Vector2i] = []
var deep_mountain_cells: Array[Vector2i] = []
var world_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var energy_points: float = 0.0
var cpu_level: int = 1
var logistics_multiplier: float = 1.0
var wood_burn_timer: float = 0.0
var archer_wave_timer: float = 0.0
var collection_piles: Array[Node2D] = []
var pile_build_timer: float = 0.0
var worker_spawn_attempts: int = 0
var camera_dragging: bool = false
var input_debug_visible: bool = false
var input_debug_timer: float = 0.0
var last_mouse_position: Vector2 = Vector2.ZERO
var last_zoom_delta: float = 0.0
var storage_node: Node2D
var tree_respawn_queue: Array[Dictionary] = []

func _ready() -> void:
	# 初始化关卡内所有生成物
	set_process(true)
	set_process_input(true)
	world_rng.seed = noise_seed
	if objects_container:
		for child in objects_container.get_children():
			if child.is_in_group("peao") or child.is_in_group("player"):
				continue
			if child.name == "peao":
				continue
			child.queue_free()
	collection_piles.clear()
	pile_build_timer = 0.0
	worker_spawn_attempts = 0
	input_debug_visible = input_debug_enabled
	_update_debug_visibility()
	if use_noise_terrain:
		_generate_noise_terrain()
	_position_player_at_spawn()
	_reset_camera()
	spawn_objects()
	_spawn_storage()
	spawn_workers()
	if not auto_workers_only:
		spawn_sheep()
	spawn_archers()
	if start_with_charger:
		_spawn_initial_chargers()
	
	# 🔥🔥🔥 启动延迟体检 🔥🔥🔥
	print("\n================ 🕵️‍♂️ 游戏体检开始 ================")
	await get_tree().create_timer(1.0).timeout # 等1秒让物体生成完
	
	# --- 1. 检查主角 (Peao) ---
	var player = get_tree().get_first_node_in_group("peao")
	if player:
		print("✅ 主角检查: 找到主角 '", player.name, "'")
		print("   - 分组: ", player.get_groups())
	else:
		printerr("❌ 主角检查失败: 没找到组名为 'peao' 的节点！")
		printerr("   -> 解决办法: 选中主角根节点 -> 节点(Node)面板 -> 分组 -> 添加 'peao'")
	
	# --- 2. 检查掉落配置 ---
	if object_scenes.is_empty():
		printerr("❌ 错误: Level 的 Object Scenes 是空的！")
	else:
		for i in range(object_scenes.size()):
			var scn = object_scenes[i]
			if scn:
				var instance = scn.instantiate()
				print("🔍 检查列表第 ", i, " 项: ", instance.name)
				
				# 检查是不是把掉落物填进来了
				if instance is RigidBody2D:
					printerr("   ❌ 严重错误: 你把【掉落物】(RigidBody2D) 填进了 Object Scenes！")
					printerr("   -> 它是: ", instance.name)
					printerr("   -> 解决办法: 必须换成 Gold.tscn 或 Tree.tscn (StaticBody2D)")
				
				# 检查金矿的配置
				elif "drop_item_scene" in instance:
					var drop = instance.drop_item_scene.instantiate()
					# 检查掉落物有没有脚本
					if drop.get_script() == null:
						printerr("   ❌ 严重错误: ", instance.name, " 掉落的物品没挂脚本！")
					else:
						print("   ✅ 掉落配置正常，掉落物脚本: ", drop.get_script().resource_path)
					drop.queue_free()
				
				instance.queue_free()
	print("================ 👨‍⚕️ 体检结束 ================\n")

func _input(event: InputEvent) -> void:
	if game_camera == null:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == input_debug_toggle_key:
			input_debug_visible = not input_debug_visible
			_update_debug_visibility()
			_emit_input_debug("input_debug=" + str(input_debug_visible))
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			camera_dragging = mouse_event.pressed
			_emit_input_debug("middle_drag=" + str(camera_dragging))
			return
		if mouse_event.ctrl_pressed and mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_camera_zoom(-camera_zoom_step)
				get_viewport().set_input_as_handled()
				return
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_camera_zoom(camera_zoom_step)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion and camera_dragging:
		var motion_event := event as InputEventMouseMotion
		var zoom_factor = max(0.1, game_camera.zoom.x)
		game_camera.position -= motion_event.relative * camera_pan_drag_speed * zoom_factor
		get_viewport().set_input_as_handled()
		return

func _reset_camera() -> void:
	if game_camera == null:
		return
	game_camera.make_current()
	game_camera.position = Vector2.ZERO

func _apply_camera_zoom(delta: float) -> void:
	if game_camera == null:
		return
	var next_zoom = clamp(game_camera.zoom.x + delta, camera_zoom_min, camera_zoom_max)
	game_camera.zoom = Vector2(next_zoom, next_zoom)
	last_zoom_delta = delta
	_emit_input_debug("zoom=" + str(next_zoom))

func spawn_objects() -> void:
	# 生成资源物体（树/石头等）
	if use_noise_terrain:
		_spawn_resources_from_noise()
		return
	# 1. 获取所有允许生成的格子坐标 (你在编辑器里画过的)
	var available_cells: Array[Vector2i] = spawn_layer.get_used_cells()
	
	# 如果没有画生成层，就报错并返回，防止游戏崩溃
	if available_cells.is_empty():
		print("错误：SpawnLayer 没有画任何格子！无法生成物体。")
		return
		
	# 2. 记录已经占用的格子，防止重叠
	var occupied_cells: Array[Vector2i] = []
	var spawned_count: int = 0
	
	# 3. 循环生成，直到数量达标
	while spawned_count < total_objects:
		# 从可用列表中随机挑一个坐标
		var random_cell = available_cells.pick_random()
		
		# 检查：如果这个格子已经生成过东西了，就跳过本次循环
		if random_cell in occupied_cells:
			continue
		
		# 检查：如果没有设置物体场景，就跳出
		if object_scenes.is_empty():
			print("错误：没有在 Inspector 里给 Object Scenes 赋值！")
			break
			
		# 4. 随机挑选一个物体 (树 或 石头)
		var random_object_scene = object_scenes.pick_random()
		var obj_instance = random_object_scene.instantiate()
		
		# 5. 设置位置
		# 关键步骤：把网格坐标 (例如 10, 5) 转成像素坐标 (例如 640, 320)
		obj_instance.position = spawn_layer.map_to_local(random_cell)
		
		# 6. 添加到场景
		objects_container.add_child(obj_instance)
		_register_spawned_object(obj_instance)
		
		# 7. 关键一步：把地盘圈起来！(九宫格防御)
		# 如果不写这段，电脑就会觉得这块地还是空的，下次还往这儿放
		occupied_cells.append(random_cell)                   # 正中心
		occupied_cells.append(random_cell + Vector2i(0, 1))  # 下
		occupied_cells.append(random_cell + Vector2i(0, -1)) # 上
		occupied_cells.append(random_cell + Vector2i(1, 0))  # 右
		occupied_cells.append(random_cell + Vector2i(-1, 0)) # 左
		
		# 如果还是重叠，把四个角也加上（防斜着穿模）
		occupied_cells.append(random_cell + Vector2i(1, 1))
		occupied_cells.append(random_cell + Vector2i(1, -1))
		occupied_cells.append(random_cell + Vector2i(-1, 1))
		occupied_cells.append(random_cell + Vector2i(-1, -1))
		
		spawned_count += 1
		
	print("生成完毕！共生成了 ", spawned_count, " 个物体。")

func spawn_sheep() -> void:
	# 生成羊并设置漫游范围
	var available_cells: Array[Vector2i] = sheep_spawn_layer.get_used_cells()
	if use_noise_terrain and not land_cells.is_empty():
		available_cells = land_cells
	if available_cells.is_empty():
		print("错误：SheepSpawnLayer 没有画任何格子！无法生成羊。")
		return
		
	if sheep_scene == null:
		print("错误：没有在 Inspector 里给 Sheep Scene 赋值！")
		return
		
	var occupied_cells: Array[Vector2i] = []
	var spawned_count: int = 0
	var target_total = min(total_sheep, available_cells.size())
	
	while spawned_count < target_total:
		var random_cell = available_cells.pick_random()
		if random_cell in occupied_cells:
			continue
			
		var sheep_instance = sheep_scene.instantiate()
		if use_noise_terrain:
			sheep_instance.position = _cell_to_world(random_cell)
		else:
			sheep_instance.position = sheep_spawn_layer.map_to_local(random_cell)
		objects_container.add_child(sheep_instance)
		if sheep_instance.has_method("setup_roam"):
			var roam_layer = sheep_spawn_layer
			if use_noise_terrain and ground_layer:
				roam_layer = ground_layer
			sheep_instance.setup_roam(roam_layer, random_cell, sheep_roam_cell_radius)
		
		occupied_cells.append(random_cell)
		spawned_count += 1

func spawn_workers() -> void:
	if worker_scene == null:
		return
	var player = _get_player()
	if player == null:
		if worker_spawn_attempts < worker_spawn_attempts_max:
			worker_spawn_attempts += 1
			call_deferred("spawn_workers")
		return
	var base_position = Vector2.ZERO
	base_position = player.global_position
	var spawned = 0
	var tries = 0
	while spawned < total_workers and tries < total_workers * 6:
		tries += 1
		var offset = Vector2(world_rng.randf_range(-worker_spawn_radius, worker_spawn_radius), world_rng.randf_range(-worker_spawn_radius, worker_spawn_radius))
		var worker_instance = worker_scene.instantiate()
		if worker_spawn_scatter:
			worker_instance.global_position = _pick_worker_spawn_position()
		else:
			worker_instance.global_position = base_position + offset
		if "idle_texture" in worker_instance:
			worker_instance.idle_texture = worker_empty_idle_texture
		if "move_texture" in worker_instance:
			worker_instance.move_texture = worker_empty_run_texture
		if "grass_texture" in worker_instance:
			worker_instance.grass_texture = worker_empty_idle_texture
		if "worker_empty_idle_texture" in worker_instance:
			worker_instance.worker_empty_idle_texture = worker_empty_idle_texture
		if "worker_empty_move_texture" in worker_instance:
			worker_instance.worker_empty_move_texture = worker_empty_run_texture
		if "worker_carry_idle_texture" in worker_instance:
			worker_instance.worker_carry_idle_texture = worker_idle_texture
		if "worker_carry_move_texture" in worker_instance:
			worker_instance.worker_carry_move_texture = worker_run_texture
		if "worker_carry_gold_idle_texture" in worker_instance:
			worker_instance.worker_carry_gold_idle_texture = worker_gold_idle_texture
		if "worker_carry_gold_move_texture" in worker_instance:
			worker_instance.worker_carry_gold_move_texture = worker_gold_run_texture
		if "worker_carry_meat_idle_texture" in worker_instance:
			worker_instance.worker_carry_meat_idle_texture = worker_meat_idle_texture
		if "worker_carry_meat_move_texture" in worker_instance:
			worker_instance.worker_carry_meat_move_texture = worker_meat_run_texture
		if "worker_mode" in worker_instance:
			worker_instance.worker_mode = true
		if "worker_axe_texture" in worker_instance:
			worker_instance.worker_axe_texture = worker_axe_texture
		if "worker_pickaxe_texture" in worker_instance:
			worker_instance.worker_pickaxe_texture = worker_pickaxe_texture
		if "worker_knife_texture" in worker_instance:
			worker_instance.worker_knife_texture = worker_knife_texture
		if "idle_frame_count" in worker_instance:
			worker_instance.idle_frame_count = worker_idle_frame_count
		if "move_frame_count" in worker_instance:
			worker_instance.move_frame_count = worker_run_frame_count
		if "worker_work_frame_count" in worker_instance:
			worker_instance.worker_work_frame_count = worker_work_frame_count
		if "grass_frame_count" in worker_instance:
			worker_instance.grass_frame_count = worker_idle_frame_count
		if "move_speed" in worker_instance:
			worker_instance.move_speed = worker_move_speed
		if "eat_chance" in worker_instance:
			worker_instance.eat_chance = 0.0
		if "drop_item_scene" in worker_instance:
			worker_instance.drop_item_scene = null
		if "health" in worker_instance:
			worker_instance.health = 9999
		if "logistics_group" in worker_instance:
			worker_instance.logistics_group = worker_group_name
		objects_container.add_child(worker_instance)
		spawned += 1

func _spawn_storage() -> void:
	if storage_node != null and is_instance_valid(storage_node):
		return
	if storage_texture == null:
		return
	var node = Node2D.new()
	node.name = "GlobalStorage"
	node.add_to_group("storage")
	var sprite = Sprite2D.new()
	sprite.texture = storage_texture
	sprite.scale = storage_scale
	node.add_child(sprite)
	var base_position = Vector2.ZERO
	var player = _get_player()
	if player:
		base_position = player.global_position
	elif use_noise_terrain:
		var bounds = _get_map_bounds()
		var center = bounds.position + Vector2i(int(round(bounds.size.x / 2.0)), int(round(bounds.size.y / 2.0)))
		base_position = _cell_to_world(center)
	elif spawn_layer:
		var used_cells = spawn_layer.get_used_cells()
		if not used_cells.is_empty():
			base_position = spawn_layer.map_to_local(used_cells[0])
	node.global_position = base_position + Vector2(world_rng.randf_range(-storage_spawn_radius, storage_spawn_radius), world_rng.randf_range(-storage_spawn_radius, storage_spawn_radius))
	if objects_container:
		objects_container.add_child(node)
	storage_node = node

func _position_player_at_spawn() -> void:
	var player = _get_player()
	if player == null:
		return
	var target_position = player.global_position
	if use_noise_terrain and not land_cells.is_empty():
		var center_index = int(round(float(land_cells.size() - 1) / 2.0))
		target_position = _cell_to_world(land_cells[center_index])
	elif player_spawn_use_map_center and use_noise_terrain:
		var bounds = _get_map_bounds()
		var center = bounds.position + Vector2i(int(round(bounds.size.x / 2.0)), int(round(bounds.size.y / 2.0)))
		target_position = _cell_to_world(center)
	elif spawn_layer:
		var used_cells = spawn_layer.get_used_cells()
		if not used_cells.is_empty():
			var center_index = int(round(float(used_cells.size() - 1) / 2.0))
			target_position = spawn_layer.map_to_local(used_cells[center_index])
	player.global_position = target_position

func _pick_worker_spawn_position() -> Vector2:
	if use_noise_terrain and not land_cells.is_empty():
		var cell = land_cells[world_rng.randi_range(0, land_cells.size() - 1)]
		return _cell_to_world(cell)
	if spawn_layer:
		var used_cells = spawn_layer.get_used_cells()
		if not used_cells.is_empty():
			var cell = used_cells[world_rng.randi_range(0, used_cells.size() - 1)]
			return spawn_layer.map_to_local(cell)
	return Vector2.ZERO

func spawn_archers() -> void:
	# 生成弓箭手并设置漫游范围
	var available_cells: Array[Vector2i] = sheep_spawn_layer.get_used_cells()
	if use_noise_terrain and not deep_mountain_cells.is_empty():
		available_cells = deep_mountain_cells
	elif use_noise_terrain and not land_cells.is_empty():
		available_cells = land_cells
	if available_cells.is_empty():
		print("错误：SheepSpawnLayer 没有画任何格子！无法生成弓箭手。")
		return
		
	if archer_scene == null:
		print("错误：没有在 Inspector 里给 Archer Scene 赋值！")
		return
		
	var occupied_cells: Array[Vector2i] = []
	var spawned_count: int = 0
	var target_total = min(total_archers, available_cells.size())
	
	while spawned_count < target_total:
		var random_cell = available_cells.pick_random()
		if random_cell in occupied_cells:
			continue
			
		var archer_instance = archer_scene.instantiate()
		if use_noise_terrain:
			archer_instance.position = _cell_to_world(random_cell)
		else:
			archer_instance.position = sheep_spawn_layer.map_to_local(random_cell)
		objects_container.add_child(archer_instance)
		if archer_instance.has_method("setup_roam"):
			var roam_layer = sheep_spawn_layer
			if use_noise_terrain and ground_layer:
				roam_layer = ground_layer
			archer_instance.setup_roam(roam_layer, random_cell, archer_roam_cell_radius)
		
		occupied_cells.append(random_cell)
		spawned_count += 1

func _process(delta: float) -> void:
	_apply_edge_scroll(delta)
	_update_input_debug(delta)
	_update_tree_respawn(delta)
	if not enable_expansion_loop:
		return
	energy_points = max(0.0, energy_points - energy_decay_per_sec * delta)
	wood_burn_timer -= delta
	if wood_burn_timer <= 0.0:
		wood_burn_timer = wood_burn_interval
		_burn_wood_for_energy()
		_try_upgrade_cpu()
	pile_build_timer -= delta
	if pile_build_timer <= 0.0:
		pile_build_timer = pile_build_interval
		_try_build_collection_pile()
	_update_logistics_power()
	archer_wave_timer -= delta
	if archer_wave_timer <= 0.0:
		archer_wave_timer = archer_wave_interval
		_spawn_threat_wave()

func _apply_edge_scroll(delta: float) -> void:
	if not edge_scroll_enabled or game_camera == null:
		return
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var size = viewport.get_visible_rect().size
	var direction = Vector2.ZERO
	if mouse_pos.x <= edge_scroll_margin:
		direction.x -= 1.0
	elif mouse_pos.x >= size.x - edge_scroll_margin:
		direction.x += 1.0
	if mouse_pos.y <= edge_scroll_margin:
		direction.y -= 1.0
	elif mouse_pos.y >= size.y - edge_scroll_margin:
		direction.y += 1.0
	if direction != Vector2.ZERO:
		game_camera.position += direction.normalized() * edge_scroll_speed * delta
		_emit_input_debug("edge_scroll=" + str(direction))

func _update_input_debug(delta: float) -> void:
	if not input_debug_visible:
		return
	input_debug_timer -= delta
	if input_debug_timer > 0.0:
		return
	input_debug_timer = 0.12
	if game_camera == null:
		return
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	last_mouse_position = mouse_pos
	var size = viewport.get_visible_rect().size
	var data = [
		"camera=" + str(game_camera.global_position),
		"zoom=" + str(game_camera.zoom.x),
		"mouse=" + str(mouse_pos),
		"viewport=" + str(size),
		"drag=" + str(camera_dragging),
		"edge=" + str(edge_scroll_enabled),
		"zoom_delta=" + str(last_zoom_delta)
	]
	if debug_label:
		debug_label.text = "\n".join(data)

func _update_debug_visibility() -> void:
	if debug_label:
		debug_label.visible = input_debug_visible

func _emit_input_debug(message: String) -> void:
	if not input_debug_visible:
		return
	print("CameraInput | ", message)

func _burn_wood_for_energy() -> void:
	if not energy_consumes_wood:
		return
	var ui = _get_interface()
	if ui == null:
		return
	if not ui.inventory_data.has("wood"):
		return
	var wood_count = int(ui.inventory_data.get("wood", 0))
	if wood_count <= 0:
		return
	var burn_count = min(wood_burn_per_tick, wood_count)
	ui.inventory_data["wood"] = wood_count - burn_count
	energy_points += float(burn_count * energy_per_wood)
	ui.refresh_inventory_ui()

func _try_upgrade_cpu() -> void:
	var ui = _get_interface()
	if ui == null:
		return
	var gold_count = int(ui.inventory_data.get("gold", 0))
	if gold_count < gold_upgrade_cost:
		return
	var upgrades = int(gold_count / gold_upgrade_cost)
	if upgrades <= 0:
		return
	ui.inventory_data["gold"] = gold_count - upgrades * gold_upgrade_cost
	cpu_level += upgrades
	logistics_multiplier = 1.0 + float(cpu_level - 1) * logistics_speed_per_level
	get_tree().call_group(worker_group_name, "set_logistics_multiplier", logistics_multiplier)
	ui.refresh_inventory_ui()

func _spawn_threat_wave() -> void:
	if archer_scene == null:
		return
	if energy_points < threat_energy_step:
		return
	var wave_count = archer_wave_base + int(energy_points / threat_energy_step)
	wave_count = min(wave_count, archer_wave_cap)
	for i in range(wave_count):
		_spawn_archer_at_cell()

func _spawn_archer_at_cell() -> void:
	var available_cells: Array[Vector2i] = deep_mountain_cells
	if available_cells.is_empty():
		available_cells = land_cells
	if available_cells.is_empty():
		return
	var random_cell = available_cells[world_rng.randi_range(0, available_cells.size() - 1)]
	var archer_instance = archer_scene.instantiate()
	archer_instance.position = _cell_to_world(random_cell)
	objects_container.add_child(archer_instance)
	if archer_instance.has_method("setup_roam"):
		var roam_layer = sheep_spawn_layer
		if use_noise_terrain and ground_layer:
			roam_layer = ground_layer
		archer_instance.setup_roam(roam_layer, random_cell, archer_roam_cell_radius)

func _try_build_collection_pile() -> void:
	if not collection_pile_enabled:
		return
	if collection_piles.size() >= collection_pile_max:
		return
	if energy_points < collection_pile_energy_threshold:
		return
	var ui = _get_interface()
	if ui == null:
		return
	var wood_count = int(ui.inventory_data.get("wood", 0))
	var gold_count = int(ui.inventory_data.get("gold", 0))
	if wood_count < collection_pile_wood_cost or gold_count < collection_pile_gold_cost:
		return
	var player = _get_player()
	if player == null:
		return
	ui.inventory_data["wood"] = wood_count - collection_pile_wood_cost
	ui.inventory_data["gold"] = gold_count - collection_pile_gold_cost
	ui.refresh_inventory_ui()
	var offset = Vector2(world_rng.randf_range(-collection_pile_spawn_radius, collection_pile_spawn_radius), world_rng.randf_range(-collection_pile_spawn_radius, collection_pile_spawn_radius))
	_spawn_collection_pile_at_position(player.global_position + offset)

func _update_logistics_power() -> void:
	var enabled = energy_points >= logistics_energy_min and not collection_piles.is_empty()
	get_tree().call_group(worker_group_name, "set_logistics_enabled", enabled)

func _spawn_collection_pile_at_position(pile_position: Vector2) -> void:
	if collection_piles.size() >= collection_pile_max:
		return
	var pile = Node2D.new()
	pile.name = "CollectionPile"
	pile.add_to_group("collection_pile")
	pile.global_position = pile_position
	if collection_pile_texture:
		var sprite = Sprite2D.new()
		sprite.texture = collection_pile_texture
		pile.add_child(sprite)
	if objects_container:
		objects_container.add_child(pile)
	else:
		add_child(pile)
	collection_piles.append(pile)

func _spawn_initial_chargers() -> void:
	var player = _get_player()
	if player == null:
		return
	for i in range(start_charger_count):
		var offset = Vector2(world_rng.randf_range(-start_charger_radius, start_charger_radius), world_rng.randf_range(-start_charger_radius, start_charger_radius))
		_spawn_collection_pile_at_position(player.global_position + offset)

func _get_player() -> Node2D:
	var player = get_tree().get_first_node_in_group("peao")
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	return player

func _get_interface() -> Node:
	return get_tree().get_first_node_in_group("interface")

func _generate_noise_terrain() -> void:
	land_cells.clear()
	tree_cells.clear()
	rock_cells.clear()
	gold_cells.clear()
	deep_mountain_cells.clear()
	var bounds = _get_map_bounds()
	_clear_terrain_layers()
	var land_set: Dictionary = {}
	var screen_tiles = _get_screen_tile_size()
	var border_x = screen_tiles.x * max(0, water_border_screens)
	var border_y = screen_tiles.y * max(0, water_border_screens)
	var max_border_x = int(floor(bounds.size.x * 0.1))
	var max_border_y = int(floor(bounds.size.y * 0.1))
	border_x = clamp(border_x, 0, min(int(floor((bounds.size.x - 1) / 2.0)), max_border_x))
	border_y = clamp(border_y, 0, min(int(floor((bounds.size.y - 1) / 2.0)), max_border_y))
	var land_start = bounds.position + Vector2i(border_x, border_y)
	var land_end = bounds.position + bounds.size - Vector2i(border_x, border_y) - Vector2i(1, 1)
	if land_start.x > land_end.x or land_start.y > land_end.y:
		border_x = 0
		border_y = 0
		land_start = bounds.position
		land_end = bounds.position + bounds.size - Vector2i(1, 1)
	for x in range(bounds.size.x):
		for y in range(bounds.size.y):
			var cell = Vector2i(bounds.position.x + x, bounds.position.y + y)
			_set_water_cell(cell)
	for x in range(land_start.x, land_end.x + 1):
		for y in range(land_start.y, land_end.y + 1):
			var cell = Vector2i(x, y)
			land_cells.append(cell)
			land_set[cell] = true
	var pond_count = pond_count_min
	if pond_count_max > pond_count_min:
		pond_count = world_rng.randi_range(pond_count_min, pond_count_max)
	for i in range(pond_count):
		if land_cells.is_empty():
			break
		var center = land_cells[world_rng.randi_range(0, land_cells.size() - 1)]
		var radius = pond_radius_min
		if pond_radius_max > pond_radius_min:
			radius = world_rng.randi_range(pond_radius_min, pond_radius_max)
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if Vector2(dx, dy).length() > float(radius) + 0.25:
					continue
				var pond_cell = center + Vector2i(dx, dy)
				if land_set.has(pond_cell):
					land_set.erase(pond_cell)
	land_cells.clear()
	for cell in land_set.keys():
		land_cells.append(cell)
	for cell in land_cells:
		if world_rng.randf() < tree_density:
			tree_cells.append(cell)
		if world_rng.randf() < rock_seed_density:
			deep_mountain_cells.append(cell)
		if world_rng.randf() < rock_scatter_density:
			rock_cells.append(cell)
		if world_rng.randf() < gold_scatter_density:
			gold_cells.append(cell)
	_apply_ground_autotile(land_set)
	_build_rock_clusters(deep_mountain_cells)
	tree_cells = _cap_cells(tree_cells, max_tree_count)
	rock_cells = _cap_cells(rock_cells, max_rock_count)
	gold_cells = _cap_cells(gold_cells, max_gold_count)

func _get_screen_tile_size() -> Vector2i:
	var view_size = get_viewport().get_visible_rect().size
	var tile_size = Vector2i(64, 64)
	if ground_layer and ground_layer.tile_set:
		tile_size = ground_layer.tile_set.tile_size
	var sx = int(ceil(view_size.x / max(1.0, float(tile_size.x))))
	var sy = int(ceil(view_size.y / max(1.0, float(tile_size.y))))
	if sx <= 0 or sy <= 0:
		sx = max(1, int(round(map_width / 4.0)))
		sy = max(1, int(round(map_height / 4.0)))
	return Vector2i(sx, sy)

func _get_map_bounds() -> Rect2i:
	var used_cells = spawn_layer.get_used_cells()
	if map_width > 0 and map_height > 0:
		var start = Vector2i(-int(round(map_width / 2.0)), -int(round(map_height / 2.0)))
		return Rect2i(start, Vector2i(map_width, map_height))
	if used_cells.is_empty():
		return Rect2i(Vector2i(-32, -32), Vector2i(64, 64))
	var min_x = used_cells[0].x
	var min_y = used_cells[0].y
	var max_x = used_cells[0].x
	var max_y = used_cells[0].y
	for cell in used_cells:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))

func _clear_terrain_layers() -> void:
	if water_layer: water_layer.clear()
	if water_foam_layer: water_foam_layer.clear()
	if ground_layer: ground_layer.clear()
	if ground_layer_2: ground_layer_2.clear()
	if shadow_layer: shadow_layer.clear()
	if shadow_layer_2: shadow_layer_2.clear()
	if spawn_layer: spawn_layer.clear()
	if sheep_spawn_layer: sheep_spawn_layer.clear()

func _set_ground_cell(cell: Vector2i, atlas: Vector2i = ground_atlas) -> void:
	if ground_layer:
		ground_layer.set_cell(cell, ground_source_id, atlas)

func _set_water_cell(cell: Vector2i) -> void:
	if water_layer:
		water_layer.set_cell(cell, water_source_id, water_atlas)

func _apply_ground_autotile(land_set: Dictionary) -> void:
	for cell in land_cells:
		var up = land_set.has(cell + Vector2i(0, -1))
		var down = land_set.has(cell + Vector2i(0, 1))
		var left = land_set.has(cell + Vector2i(-1, 0))
		var right = land_set.has(cell + Vector2i(1, 0))
		var atlas = ground_atlas
		if not up and not left:
			atlas = ground_atlas_tl
		elif not up and not right:
			atlas = ground_atlas_tr
		elif not down and not left:
			atlas = ground_atlas_bl
		elif not down and not right:
			atlas = ground_atlas_br
		elif not up:
			atlas = ground_atlas_t
		elif not down:
			atlas = ground_atlas_b
		elif not left:
			atlas = ground_atlas_l
		elif not right:
			atlas = ground_atlas_r
		_set_ground_cell(cell, atlas)
		if water_foam_layer:
			if atlas == ground_atlas:
				water_foam_layer.erase_cell(cell)
			else:
				water_foam_layer.set_cell(cell, water_foam_source_id, water_foam_atlas)

func _build_rock_clusters(candidates: Array[Vector2i]) -> void:
	if candidates.is_empty():
		return
	var candidate_set: Dictionary = {}
	for c in candidates:
		candidate_set[c] = true
	var seed_count = int(max(1, float(candidates.size()) * rock_cluster_seed_ratio))
	for i in range(seed_count):
		var seed_cell = candidates[world_rng.randi_range(0, candidates.size() - 1)]
		var cluster_size = world_rng.randi_range(rock_cluster_size_min, rock_cluster_size_max)
		var cluster = _grow_cluster(seed_cell, cluster_size, candidate_set)
		for c in cluster:
			if world_rng.randf() < gold_ratio:
				gold_cells.append(c)
			else:
				rock_cells.append(c)

func _grow_cluster(seed_cell: Vector2i, target_size: int, candidate_set: Dictionary) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [seed_cell]
	var visited: Dictionary = {}
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while cluster.size() < target_size and not frontier.is_empty():
		var current = frontier.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		if not candidate_set.has(current):
			continue
		cluster.append(current)
		for d in dirs:
			if world_rng.randf() <= rock_cluster_expand_chance:
				frontier.append(current + d)
	return cluster

func _cap_cells(cells: Array[Vector2i], max_count: int) -> Array[Vector2i]:
	if max_count <= 0:
		return []
	if cells.size() <= max_count:
		return cells
	_shuffle_cells(cells)
	return cells.slice(0, max_count)

func _shuffle_cells(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j = world_rng.randi_range(0, i)
		var tmp = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp

func _spawn_resources_from_noise() -> void:
	var sets = _pick_object_scenes_by_type()
	var tree_scenes = _to_packed_scene_array(sets.get("tree", []))
	var rock_scenes = _to_packed_scene_array(sets.get("rock", []))
	var gold_scenes = _to_packed_scene_array(sets.get("gold", []))
	var occupied: Dictionary = {}
	for cell in tree_cells:
		if tree_scenes.is_empty():
			break
		_spawn_object_at_cell(tree_scenes, cell, occupied)
	for cell in rock_cells:
		if rock_scenes.is_empty():
			break
		_spawn_object_at_cell(rock_scenes, cell, occupied)
	for cell in gold_cells:
		if gold_scenes.is_empty():
			break
		_spawn_object_at_cell(gold_scenes, cell, occupied)

func _pick_object_scenes_by_type() -> Dictionary:
	var result: Dictionary = {"tree": [], "rock": [], "gold": []}
	for scn in object_scenes:
		if scn == null:
			continue
		var instance = scn.instantiate()
		var type_value = ""
		if "type" in instance:
			type_value = str(instance.type).to_lower()
		else:
			type_value = instance.name.to_lower()
		if type_value.find("gold") != -1:
			result["gold"].append(scn)
		elif type_value.find("rock") != -1:
			result["rock"].append(scn)
		elif type_value.find("tree") != -1:
			result["tree"].append(scn)
		instance.queue_free()
	return result

func _to_packed_scene_array(value) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	if value is Array:
		for item in value:
			if item is PackedScene:
				result.append(item)
	return result

func _spawn_object_at_cell(scenes: Array[PackedScene], cell: Vector2i, occupied: Dictionary) -> void:
	if occupied.has(cell):
		return
	var scene = scenes[world_rng.randi_range(0, scenes.size() - 1)]
	var obj_instance = scene.instantiate()
	obj_instance.position = _cell_to_world(cell)
	objects_container.add_child(obj_instance)
	_register_spawned_object(obj_instance)
	_mark_occupied(cell, occupied)

func _register_spawned_object(obj_instance: Node) -> void:
	if obj_instance == null:
		return
	if obj_instance.has_signal("destroyed"):
		if not obj_instance.destroyed.is_connected(_on_object_destroyed):
			obj_instance.destroyed.connect(_on_object_destroyed)

func _on_object_destroyed(object_type: String, drop_type: String, world_position: Vector2) -> void:
	if not tree_respawn_enabled:
		return
	if drop_type != "wood" and object_type.to_lower().find("tree") == -1:
		return
	if tree_respawn_queue.size() >= tree_respawn_max_pending:
		return
	var delay = randf_range(tree_respawn_delay_min, tree_respawn_delay_max)
	tree_respawn_queue.append({"time": delay})

func _update_tree_respawn(delta: float) -> void:
	if not tree_respawn_enabled:
		return
	if tree_respawn_queue.is_empty():
		return
	for i in range(tree_respawn_queue.size() - 1, -1, -1):
		var item = tree_respawn_queue[i]
		item["time"] = float(item["time"]) - delta
		tree_respawn_queue[i] = item
		if float(item["time"]) <= 0.0:
			if _spawn_tree_respawn():
				tree_respawn_queue.remove_at(i)
			else:
				item["time"] = 1.5
				tree_respawn_queue[i] = item

func _spawn_tree_respawn() -> bool:
	var sets = _pick_object_scenes_by_type()
	var tree_scenes = _to_packed_scene_array(sets.get("tree", []))
	if tree_scenes.is_empty():
		return false
	var attempts = max(1, tree_respawn_attempts)
	var candidate_cells: Array[Vector2i] = []
	if use_noise_terrain and not land_cells.is_empty():
		candidate_cells = land_cells
	else:
		candidate_cells = spawn_layer.get_used_cells()
	if candidate_cells.is_empty():
		return false
	for i in range(attempts):
		var cell = candidate_cells[world_rng.randi_range(0, candidate_cells.size() - 1)]
		var position = _cell_to_world(cell)
		if _is_respawn_position_clear(position):
			var scene = tree_scenes[world_rng.randi_range(0, tree_scenes.size() - 1)]
			var obj_instance = scene.instantiate()
			obj_instance.position = position
			objects_container.add_child(obj_instance)
			_register_spawned_object(obj_instance)
			return true
	return false

func _is_respawn_position_clear(position: Vector2) -> bool:
	var obstacles = get_tree().get_nodes_in_group("obstacle")
	for obj in obstacles:
		if not (obj is Node2D):
			continue
		if not is_instance_valid(obj):
			continue
		if obj.global_position.distance_to(position) < 24.0:
			return false
	return true

func _mark_occupied(cell: Vector2i, occupied: Dictionary) -> void:
	occupied[cell] = true
	occupied[cell + Vector2i(0, 1)] = true
	occupied[cell + Vector2i(0, -1)] = true
	occupied[cell + Vector2i(1, 0)] = true
	occupied[cell + Vector2i(-1, 0)] = true
	occupied[cell + Vector2i(1, 1)] = true
	occupied[cell + Vector2i(1, -1)] = true
	occupied[cell + Vector2i(-1, 1)] = true
	occupied[cell + Vector2i(-1, -1)] = true

func _cell_to_world(cell: Vector2i) -> Vector2:
	if ground_layer:
		return ground_layer.map_to_local(cell)
	return spawn_layer.map_to_local(cell)
