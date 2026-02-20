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
@export var total_sheep: int = 14
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
@export var water_border_screens: int = 4
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
@export var gold_scatter_density: float = 0.02
@export var rock_cluster_seed_ratio: float = 0.06
@export var rock_cluster_size_min: int = 4
@export var rock_cluster_size_max: int = 10
@export var rock_cluster_expand_chance: float = 0.65
@export var gold_ratio: float = 0.45
@export var rainbow_gold_spawn_chance: float = 0.03
@export var max_tree_count: int = 220
@export var max_rock_count: int = 140
@export var max_gold_count: int = 140
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
@export var total_workers: int = 3
@export var worker_spawn_radius: float = 120.0
@export var worker_move_speed: float = 60.0
@export var worker_exit_distance: float = 36.0
@export var worker_empty_idle_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Idle.png")
@export var worker_empty_run_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Run.png")
@export var worker_idle_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Idle Wood.png")
@export var worker_run_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Run Wood.png")
@export var worker_gold_idle_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Idle Gold.png")
@export var worker_gold_run_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Run Gold.png")
@export var worker_meat_idle_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Idle Meat.png")
@export var worker_meat_run_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Run Meat.png")
@export var worker_axe_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Interact Axe.png")
@export var worker_pickaxe_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Interact Pickaxe.png")
@export var worker_knife_texture: Texture2D = preload("res://Assets/Units/Pawn/Pawn_Interact Knife.png")
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

@export var rock_respawn_enabled: bool = true
@export var rock_respawn_delay_min: float = 10.0
@export var rock_respawn_delay_max: float = 20.0
@export var rock_respawn_max_pending: int = 40
@export var rock_respawn_attempts: int = 14

@export var gold_respawn_enabled: bool = true
@export var gold_respawn_delay_min: float = 10.0
@export var gold_respawn_delay_max: float = 20.0
@export var gold_respawn_max_pending: int = 40
@export var gold_respawn_attempts: int = 14

@export var sheep_respawn_enabled: bool = true
@export var sheep_respawn_delay_min: float = 12.0
@export var sheep_respawn_delay_max: float = 24.0
@export var sheep_respawn_max_pending: int = 10
@export var sheep_respawn_attempts: int = 12
@export var sheep_respawn_scatter_radius: float = 64.0

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
@export var archer_wave_interval: float = 60.0
@export var archer_wave_base: int = 1
@export var archer_wave_cap: int = 6
@export var collection_pile_enabled: bool = true
@export var collection_pile_wood_cost: int = 20
@export var collection_pile_gold_cost: int = 4
@export var collection_pile_energy_threshold: float = 8.0
@export var collection_pile_max: int = 3
@export var collection_pile_spawn_radius: float = 120.0
@export var collection_pile_texture: Texture2D = preload("res://Assets/Buildings/Barracks.png")
@export var storage_texture: Texture2D = preload("res://Assets/Buildings/Barracks.png")
@export var storage_scale: Vector2 = Vector2(0.65, 0.65)
@export var storage_spawn_radius: float = 60.0
@export var logistics_energy_min: float = 2.0
@export var pile_build_interval: float = 2.0
@export var start_with_charger: bool = false
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
@export var victory_cpu_level: int = 8
@export var victory_require_full_piles: bool = true
@export var endless_mode: bool = true
@export var entropy_enabled: bool = true
@export var entropy_per_sec: float = 0.03
@export var entropy_wave_step: float = 10.0
@export var entropy_wave_bonus_cap: int = 10
@export var entropy_tree_respawn_delay_per_point: float = 0.02
var save_enabled: bool = false
@export var save_auto_interval_sec: float = 20.0
@export var save_slot: String = "默认存档"
@export var redwood_enabled: bool = true
@export var redwood_growth_time_sec: float = 18.0
@export var redwood_seed_place_clear_radius: float = 22.0
@export var redwood_tree_scene: PackedScene = preload("res://Base_Object/Trees/Tree.tscn")
@export var lamb_release_mutate_time_sec: float = 18.0
@export var lamb_release_spawn_radius: float = 36.0
@export var workers_per_warehouse: int = 3
@export var warehouse_base_wood_cost: int = 30
@export var warehouse_base_gold_cost: int = 10
@export var warehouse_base_meat_cost: int = 5
@export var warehouse_place_clear_radius: float = 38.0
@export var exp_per_enemy_kill: int = 10
@export var exp_per_tree_harvest: int = 2
@export var exp_per_rock_harvest: int = 2
@export var exp_per_gold_harvest: int = 3
@export var exp_per_sheep_kill: int = 3
@export var exp_base_to_next: int = 60
@export var exp_growth: float = 1.35
@export var exp_speed_per_level: float = 0.05

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
var pending_worker_spawn_origin: Vector2 = Vector2.ZERO
var has_pending_worker_spawn_origin: bool = false
var camera_dragging: bool = false
var input_debug_visible: bool = false
var input_debug_timer: float = 0.0
var last_mouse_position: Vector2 = Vector2.ZERO
var last_zoom_delta: float = 0.0
var storage_node: Node2D
var tree_respawn_queue: Array[Dictionary] = []
var rock_respawn_queue: Array[Dictionary] = []
var gold_respawn_queue: Array[Dictionary] = []
var sheep_respawn_queue: Array[Dictionary] = []
var game_time_sec: float = 0.0
var game_ended: bool = false
var game_won: bool = false
var waves_survived: int = 0
var enemy_kills: int = 0
var enemy_kill_exp: int = 0
var last_wave_spawned_count: int = 0
var meta_hud_timer: float = 0.0
var warehouse_count: int = 0
var placing_warehouse: bool = false
var pending_warehouse_cost_wood: int = 0
var pending_warehouse_cost_gold: int = 0
var pending_warehouse_cost_meat: int = 0
var free_warehouse_tokens: int = 1
var warehouse_preview: Node2D
var pending_loaded_payload: Dictionary = {}
var warehouse_preview_sprite: Sprite2D
var hovered_warehouse: Node2D
var moving_warehouse: Node2D
var moving_warehouse_original_pos: Vector2 = Vector2.ZERO
var moving_warehouse_original_z: int = 0
var player_level: int = 1
var player_exp: int = 0
var exp_to_next: int = 0
var entropy: float = 0.0
var save_timer: float = 0.0
var placing_redwood_seed: bool = false
var redwood_seed_preview: Node2D
var redwood_seed_preview_label: Label
var redwood_growth_queue: Array[Dictionary] = []
var redwood_planted_cells: Dictionary = {}

func _ready() -> void:
	# 初始化关卡内所有生成物
	set_process(true)
	set_process_input(true)
	add_to_group("level")
	if save_enabled:
		save_slot = _normalize_save_slot(save_slot)
		if pending_boot_save_slot != "":
			save_slot = pending_boot_save_slot
			pending_boot_save_slot = ""
			pending_loaded_payload = _read_save_payload(save_slot)
			if not pending_loaded_payload.is_empty() and pending_loaded_payload.has("noise_seed"):
				noise_seed = int(pending_loaded_payload["noise_seed"])
		else:
			pending_loaded_payload = {}
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
	free_warehouse_tokens = 1
	if not auto_workers_only:
		spawn_sheep()
	spawn_archers()
	if start_with_charger:
		_spawn_initial_chargers()
	archer_wave_timer = archer_wave_interval
	player_level = max(player_level, 1)
	player_exp = max(player_exp, 0)
	_recompute_exp_to_next()
	_apply_worker_speed_multiplier()
	save_timer = max(1.0, save_auto_interval_sec)
	if not pending_loaded_payload.is_empty():
		_apply_loaded_payload(pending_loaded_payload)
		pending_loaded_payload.clear()
	
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
	if placing_redwood_seed:
		if event is InputEventMouseButton:
			var seed_mouse := event as InputEventMouseButton
			if seed_mouse.button_index == MOUSE_BUTTON_RIGHT and seed_mouse.pressed:
				_cancel_redwood_seed_placement()
				get_viewport().set_input_as_handled()
				return
			if seed_mouse.button_index == MOUSE_BUTTON_LEFT and seed_mouse.pressed:
				var cell = _world_to_cell(get_global_mouse_position())
				if _can_place_redwood_seed_at_cell(cell):
					_place_redwood_seed_at_cell(cell)
					_cancel_redwood_seed_placement()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey:
			var seed_key := event as InputEventKey
			if seed_key.pressed and not seed_key.echo and seed_key.keycode == KEY_ESCAPE:
				_cancel_redwood_seed_placement()
				get_viewport().set_input_as_handled()
				return
	if placing_warehouse:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
				_cancel_warehouse_placement()
				get_viewport().set_input_as_handled()
				return
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
				var cell = _world_to_cell(get_global_mouse_position())
				if _can_place_warehouse_at_cell(cell, moving_warehouse):
					if moving_warehouse != null and is_instance_valid(moving_warehouse):
						var sprite = moving_warehouse.get_node_or_null("Sprite2D") as Sprite2D
						if sprite != null:
							sprite.modulate = Color(1, 1, 1, 1)
						moving_warehouse.z_index = moving_warehouse_original_z
						moving_warehouse = null
						placing_warehouse = false
						_clear_warehouse_preview()
					else:
						_place_warehouse_at_cell(cell)
						placing_warehouse = false
						_clear_warehouse_preview()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey:
			var key_event_cancel := event as InputEventKey
			if key_event_cancel.pressed and not key_event_cancel.echo and key_event_cancel.keycode == KEY_ESCAPE:
				_cancel_warehouse_placement()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var click_event := event as InputEventMouseButton
		if click_event.button_index == MOUSE_BUTTON_LEFT and click_event.pressed and not click_event.ctrl_pressed:
			if hovered_warehouse != null and is_instance_valid(hovered_warehouse):
				moving_warehouse = hovered_warehouse
				moving_warehouse_original_pos = moving_warehouse.global_position
				moving_warehouse_original_z = moving_warehouse.z_index
				moving_warehouse.z_index = 90
				placing_warehouse = true
				pending_warehouse_cost_wood = 0
				pending_warehouse_cost_gold = 0
				pending_warehouse_cost_meat = 0
				_clear_warehouse_preview()
				get_viewport().set_input_as_handled()
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
		_clamp_view_to_map()
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
	_clamp_view_to_map()

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
		_maybe_make_rainbow_gold(obj_instance)
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
		if sheep_instance.has_signal("died"):
			if not sheep_instance.died.is_connected(_on_sheep_died.bind(sheep_instance)):
				sheep_instance.died.connect(_on_sheep_died.bind(sheep_instance))
		if sheep_instance.has_method("setup_roam"):
			var roam_layer = sheep_spawn_layer
			if use_noise_terrain and ground_layer:
				roam_layer = ground_layer
			sheep_instance.setup_roam(roam_layer, random_cell, sheep_roam_cell_radius)
		
		occupied_cells.append(random_cell)
		spawned_count += 1

func _configure_worker_instance(worker_instance: Node) -> void:
	if worker_instance == null:
		return
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
	if "logistics_enabled" in worker_instance:
		worker_instance.logistics_enabled = true
	if "logistics_group" in worker_instance:
		worker_instance.logistics_group = worker_group_name
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
	if "grass_frame_count" in worker_instance:
		worker_instance.grass_frame_count = worker_idle_frame_count
	if "worker_work_frame_count" in worker_instance:
		worker_instance.worker_work_frame_count = worker_work_frame_count
	if "move_speed" in worker_instance:
		worker_instance.move_speed = worker_move_speed
	if "eat_chance" in worker_instance:
		worker_instance.eat_chance = 0.0
	if "drop_item_scene" in worker_instance:
		worker_instance.drop_item_scene = null
	if "health" in worker_instance:
		worker_instance.health = 9999

func _count_active_workers() -> int:
	var count = 0
	for node in get_tree().get_nodes_in_group(worker_group_name):
		if node == null or not is_instance_valid(node):
			continue
		if node.is_queued_for_deletion():
			continue
		if "worker_mode" in node and node.worker_mode:
			count += 1
	return count

func _snap_position_to_land(desired_world_pos: Vector2, origin_world_pos: Vector2, search_radius: float) -> Vector2:
	var desired_cell = _world_to_cell(desired_world_pos)
	if _is_grass_cell(desired_cell) and not _is_water_cell(desired_cell):
		return _cell_to_world(desired_cell)
	return _pick_land_position_near(origin_world_pos, search_radius, 48)

func _pick_land_position_near(origin_world_pos: Vector2, radius: float, max_attempts: int) -> Vector2:
	var origin_cell = _world_to_cell(origin_world_pos)
	if _is_grass_cell(origin_cell) and not _is_water_cell(origin_cell):
		var cell_origin_world = _cell_to_world(origin_cell)
		for i in range(max_attempts):
			var angle = world_rng.randf_range(0.0, TAU)
			var dist = world_rng.randf_range(0.0, radius)
			var candidate_world = cell_origin_world + Vector2(cos(angle), sin(angle)) * dist
			var candidate_cell = _world_to_cell(candidate_world)
			if _is_grass_cell(candidate_cell) and not _is_water_cell(candidate_cell):
				return _cell_to_world(candidate_cell)
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			var candidate_cell2 = origin_cell + Vector2i(dx, dy)
			if _is_grass_cell(candidate_cell2) and not _is_water_cell(candidate_cell2):
				return _cell_to_world(candidate_cell2)
	return origin_world_pos

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
	if game_ended:
		return
	if entropy_enabled:
		entropy = max(0.0, entropy + max(0.0, entropy_per_sec) * delta)
	if save_enabled:
		save_timer -= delta
		if save_timer <= 0.0:
			save_timer = max(1.0, save_auto_interval_sec)
			_save_game()
	_update_redwood_system(delta)
	_update_warehouse_hover_and_preview()
	_apply_edge_scroll(delta)
	_clamp_view_to_map()
	_update_input_debug(delta)
	_update_tree_respawn(delta)
	_update_rock_respawn(delta)
	_update_gold_respawn(delta)
	_update_sheep_respawn(delta)
	_check_end_conditions()
	_update_meta_hud(delta)
	game_time_sec += delta
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
		if _spawn_threat_wave():
			archer_wave_timer = archer_wave_interval
		else:
			archer_wave_timer = 1.0

func _update_meta_hud(delta: float) -> void:
	meta_hud_timer -= delta
	if meta_hud_timer > 0.0:
		return
	meta_hud_timer = 0.2
	var ui = _get_interface()
	if ui == null:
		return
	var enemies_alive = get_tree().get_nodes_in_group("enemy").size()
	var logistics_enabled = energy_points >= logistics_energy_min and not collection_piles.is_empty()
	var next_wave_in = max(0.0, archer_wave_timer)
	var resources: Dictionary = {}
	if "inventory_data" in ui:
		resources = ui.inventory_data
	var wood_count = int(resources.get("wood", 0))
	var gold_count = int(resources.get("gold", 0))
	var meat_count = int(resources.get("meat", 0))
	var wave_size = _compute_next_wave_size()
	var objective_text = _compute_objective_text()
	var hint_text = _compute_hint_text(wood_count, gold_count)
	if hovered_warehouse != null and is_instance_valid(hovered_warehouse) and not placing_warehouse:
		hint_text = "提示: 点击仓库可移动位置"
	var workers_current = _count_active_workers()
	var workers_cap = _get_worker_cap()
	var next_cost = _get_next_warehouse_cost()
	var cost_wood = int(next_cost.get("wood", 0))
	var cost_gold = int(next_cost.get("gold", 0))
	var cost_meat = int(next_cost.get("meat", 0))
	var missing_wood = max(0, cost_wood - wood_count)
	var missing_gold = max(0, cost_gold - gold_count)
	var missing_meat = max(0, cost_meat - meat_count)
	var can_build = missing_wood == 0 and missing_gold == 0 and missing_meat == 0
	if ui.has_method("update_warehouse_build_button_state"):
		ui.call("update_warehouse_build_button_state", can_build, cost_wood, cost_gold, cost_meat, missing_wood, missing_gold, missing_meat, placing_warehouse)
	if ui.has_method("update_player_experience"):
		ui.call("update_player_experience", player_exp, exp_to_next, player_level)
	ui.call("update_meta_hud", waves_survived, next_wave_in, enemies_alive, wave_size, energy_points, energy_decay_per_sec, energy_consumes_wood, cpu_level, enemy_kill_exp, max(1, gold_upgrade_cost), _get_total_worker_speed_multiplier(), logistics_enabled, int(noise_seed), objective_text, hint_text, player_level, player_exp, exp_to_next, warehouse_count, workers_current, workers_cap, cost_wood, cost_gold, cost_meat, placing_warehouse)

func _compute_next_wave_size() -> int:
	if archer_wave_base <= 0:
		return 0
	var bonus = 0
	if threat_energy_step > 0.0:
		bonus = int(energy_points / threat_energy_step)
	var entropy_bonus = 0
	if entropy_enabled and entropy_wave_step > 0.0:
		entropy_bonus = int(entropy / entropy_wave_step)
		entropy_bonus = clamp(entropy_bonus, 0, max(0, entropy_wave_bonus_cap))
	var wave_count = archer_wave_base + bonus
	wave_count += entropy_bonus
	return min(wave_count, archer_wave_cap)

func _compute_objective_text() -> String:
	if endless_mode:
		return "目标: 生存并扩张"
	var parts: Array[String] = []
	if victory_cpu_level > 0:
		parts.append("CPU " + str(cpu_level) + "/" + str(victory_cpu_level))
	if collection_pile_enabled and victory_require_full_piles and collection_pile_max > 0:
		parts.append("收集桩 " + str(collection_piles.size()) + "/" + str(collection_pile_max))
	if parts.is_empty():
		return "目标: 生存"
	return "目标: " + " 或 ".join(parts)

func _compute_hint_text(wood_count: int, gold_count: int) -> String:
	if not endless_mode and victory_cpu_level > 0 and cpu_level < victory_cpu_level:
		var need_levels = victory_cpu_level - cpu_level
		var per = max(1, gold_upgrade_cost)
		var total_need = need_levels * per
		var remaining = max(0, total_need - enemy_kill_exp)
		var per_kill = max(1, exp_per_enemy_kill)
		var kills_need = int(ceil(float(remaining) / float(per_kill))) if remaining > 0 else 0
		if remaining <= 0:
			return "建议: 等待自动升级CPU（杀敌经验已足够）"
		return "建议: 杀敌凑 " + str(remaining) + " 杀敌经验升级CPU（约需击杀 " + str(kills_need) + " 个敌人）"
	if collection_pile_enabled and victory_require_full_piles and collection_pile_max > 0 and collection_piles.size() < collection_pile_max:
		var need_energy = energy_points < collection_pile_energy_threshold
		var need_wood = max(0, collection_pile_wood_cost - wood_count)
		var need_gold = max(0, collection_pile_gold_cost - gold_count)
		if need_energy:
			return "建议: 采集资源让能量≥" + str(int(collection_pile_energy_threshold)) + "，再凑木" + str(need_wood) + " 矿" + str(need_gold) + " 自动建桩"
		return "建议: 凑木" + str(need_wood) + " 矿" + str(need_gold) + " 等待自动建桩"
	return "建议: 清理敌人，采集资源，维持血量"

func _check_end_conditions() -> void:
	var player = _get_player()
	if player != null:
		var hp_val = player.get("current_health")
		if hp_val != null and int(hp_val) <= 0:
			_end_game(false, "player_dead")
			return
	if endless_mode:
		return
	var win_by_cpu = victory_cpu_level > 0 and cpu_level >= victory_cpu_level
	var win_by_piles = collection_pile_enabled and victory_require_full_piles and collection_piles.size() >= collection_pile_max and collection_pile_max > 0
	if win_by_cpu or win_by_piles:
		_end_game(true, "victory")

func _end_game(won: bool, reason: String) -> void:
	if game_ended:
		return
	game_ended = true
	game_won = won
	var ui = _get_interface()
	if ui != null:
		var resources: Dictionary = {}
		if "inventory_data" in ui:
			resources = ui.inventory_data
		var stats: Dictionary = {
			"won": won,
			"reason": reason,
			"time_sec": game_time_sec,
			"waves_survived": waves_survived,
			"enemy_kills": enemy_kills,
			"cpu_level": cpu_level,
			"logistics_multiplier": logistics_multiplier,
			"energy_points": energy_points,
			"seed": int(noise_seed),
			"resources": resources
		}
		ui.call("show_end_screen", won, stats)
	get_tree().paused = true

func register_enemy_kill(_enemy_type: String = "") -> void:
	if game_ended:
		return
	enemy_kills += 1
	enemy_kill_exp += max(0, exp_per_enemy_kill)
	_add_experience(exp_per_enemy_kill)

func _on_sheep_died(world_pos: Vector2, sheep: Node) -> void:
	if game_ended:
		return
	if sheep != null and is_instance_valid(sheep):
		if "worker_mode" in sheep and sheep.worker_mode:
			return
		if "pickup_item_enabled" in sheep and sheep.pickup_item_enabled:
			return
	_add_experience(exp_per_sheep_kill)
	if not auto_workers_only and sheep_respawn_enabled:
		if sheep_respawn_queue.size() < sheep_respawn_max_pending:
			var delay = randf_range(sheep_respawn_delay_min, sheep_respawn_delay_max)
			sheep_respawn_queue.append({"time": delay, "pos": world_pos})

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

func _get_map_world_rect() -> Rect2:
	var layer = _get_primary_map_layer()
	if layer == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var bounds = _get_map_bounds()
	var tile_size = Vector2(64.0, 64.0)
	if layer.tile_set:
		tile_size = Vector2(layer.tile_set.tile_size)
	var tl_cell = bounds.position
	var br_cell = bounds.position + bounds.size - Vector2i(1, 1)
	var tl = layer.to_global(layer.map_to_local(tl_cell))
	var br = layer.to_global(layer.map_to_local(br_cell))
	var min_x = min(tl.x, br.x) - tile_size.x * 0.5
	var max_x = max(tl.x, br.x) + tile_size.x * 0.5
	var min_y = min(tl.y, br.y) - tile_size.y * 0.5
	var max_y = max(tl.y, br.y) + tile_size.y * 0.5
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _clamp_player_to_map(map_rect: Rect2) -> void:
	var player = _get_player()
	if player == null or not (player is Node2D):
		return
	var layer = _get_primary_map_layer()
	if layer == null:
		return
	var tile_size = Vector2(64.0, 64.0)
	if layer.tile_set:
		tile_size = Vector2(layer.tile_set.tile_size)
	var half_tile = tile_size * 0.5
	var min_pos = map_rect.position + half_tile
	var max_pos = map_rect.position + map_rect.size - half_tile
	var desired = (player as Node2D).global_position
	var x = desired.x
	var y = desired.y
	if min_pos.x > max_pos.x:
		x = map_rect.position.x + map_rect.size.x * 0.5
	else:
		x = clamp(desired.x, min_pos.x, max_pos.x)
	if min_pos.y > max_pos.y:
		y = map_rect.position.y + map_rect.size.y * 0.5
	else:
		y = clamp(desired.y, min_pos.y, max_pos.y)
	(player as Node2D).global_position = Vector2(x, y)

func _clamp_camera_to_map(map_rect: Rect2) -> void:
	if game_camera == null:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom = max(0.01, game_camera.zoom.x)
	var half_view = viewport_size * 0.5 / zoom
	var min_center = map_rect.position + half_view
	var max_center = map_rect.position + map_rect.size - half_view
	var desired = game_camera.global_position
	var x = desired.x
	var y = desired.y
	if min_center.x > max_center.x:
		x = map_rect.position.x + map_rect.size.x * 0.5
	else:
		x = clamp(desired.x, min_center.x, max_center.x)
	if min_center.y > max_center.y:
		y = map_rect.position.y + map_rect.size.y * 0.5
	else:
		y = clamp(desired.y, min_center.y, max_center.y)
	game_camera.global_position = Vector2(x, y)

func _clamp_view_to_map() -> void:
	var map_rect = _get_map_world_rect()
	if map_rect.size.x <= 1.0 or map_rect.size.y <= 1.0:
		return
	_clamp_player_to_map(map_rect)
	_clamp_camera_to_map(map_rect)

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
	if placing_warehouse:
		var cell = _world_to_cell(get_global_mouse_position())
		var fail_reason = _get_warehouse_place_fail_reason(cell, moving_warehouse)
		data.append("warehouse_mode=true")
		data.append("warehouse_cell=" + str(cell))
		data.append("warehouse_ok=" + str(fail_reason == ""))
		if fail_reason != "":
			data.append("warehouse_err=" + fail_reason)
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
	var cost = max(1, gold_upgrade_cost)
	if enemy_kill_exp < cost:
		return
	var upgrades = int(enemy_kill_exp / cost)
	if upgrades <= 0:
		return
	enemy_kill_exp -= upgrades * cost
	cpu_level += upgrades
	logistics_multiplier = 1.0 + float(cpu_level - 1) * logistics_speed_per_level
	_apply_worker_speed_multiplier()
	var ui = _get_interface()
	if ui != null and ui.has_method("refresh_inventory_ui"):
		ui.refresh_inventory_ui()

func request_build_warehouse() -> void:
	if game_ended:
		return
	var ui = _get_interface()
	if ui == null:
		return
	var cost = _get_next_warehouse_cost()
	var cost_wood = int(cost.get("wood", 0))
	var cost_gold = int(cost.get("gold", 0))
	var cost_meat = int(cost.get("meat", 0))
	var wood_count = int(ui.inventory_data.get("wood", 0))
	var gold_count = int(ui.inventory_data.get("gold", 0))
	var meat_count = int(ui.inventory_data.get("meat", 0))
	if wood_count < cost_wood or gold_count < cost_gold or meat_count < cost_meat:
		placing_warehouse = false
		return
	placing_warehouse = true
	moving_warehouse = null
	pending_warehouse_cost_wood = cost_wood
	pending_warehouse_cost_gold = cost_gold
	pending_warehouse_cost_meat = cost_meat
	_ensure_warehouse_preview()

func _get_worker_cap() -> int:
	return max(0, warehouse_count) * max(0, workers_per_warehouse)

func _get_next_warehouse_cost() -> Dictionary:
	if free_warehouse_tokens > 0 and warehouse_count <= 0:
		return {"wood": 0, "gold": 0, "meat": 0}
	var factor = 1 << max(0, warehouse_count - 1)
	return {
		"wood": warehouse_base_wood_cost * factor,
		"gold": warehouse_base_gold_cost * factor,
		"meat": warehouse_base_meat_cost * factor
	}

func _get_primary_map_layer() -> TileMapLayer:
	if ground_layer != null:
		return ground_layer
	if ground_layer_2 != null:
		return ground_layer_2
	if spawn_layer != null:
		return spawn_layer
	return null

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var layer = _get_primary_map_layer()
	if layer != null:
		return layer.local_to_map(layer.to_local(world_pos))
	return Vector2i.ZERO

func _is_grass_cell(cell: Vector2i) -> bool:
	if use_noise_terrain and not land_cells.is_empty():
		return cell in land_cells
	if ground_layer != null and ground_layer.get_cell_source_id(cell) != -1:
		return true
	if ground_layer_2 != null and ground_layer_2.get_cell_source_id(cell) != -1:
		return true
	if ground_layer == null and ground_layer_2 == null:
		return true
	return false

func _is_water_cell(cell: Vector2i) -> bool:
	if use_noise_terrain and not land_cells.is_empty():
		return not (cell in land_cells)
	if water_layer == null:
		return false
	return water_layer.get_cell_source_id(cell) != -1

func _get_warehouse_place_fail_reason(cell: Vector2i, ignore_storage: Node2D = null) -> String:
	if not _is_grass_cell(cell):
		return "不是可放置地形"
	if _is_water_cell(cell):
		return "水面不可放置"
	var world_pos = _cell_to_world(cell)
	var obstacles = get_tree().get_nodes_in_group("obstacle")
	for obj in obstacles:
		if not (obj is Node2D):
			continue
		if not is_instance_valid(obj):
			continue
		if obj.global_position.distance_to(world_pos) <= warehouse_place_clear_radius:
			return "附近有障碍物"
	var storages = get_tree().get_nodes_in_group("storage")
	for s in storages:
		if not (s is Node2D):
			continue
		if not is_instance_valid(s):
			continue
		if ignore_storage != null and s == ignore_storage:
			continue
		if s.global_position.distance_to(world_pos) <= warehouse_place_clear_radius:
			return "附近已有仓库"
	return ""

func _can_place_warehouse_at_cell(cell: Vector2i, ignore_storage: Node2D = null) -> bool:
	return _get_warehouse_place_fail_reason(cell, ignore_storage) == ""

func _place_warehouse_at_cell(cell: Vector2i) -> void:
	var ui = _get_interface()
	if ui == null:
		return
	var wood_count = int(ui.inventory_data.get("wood", 0))
	var gold_count = int(ui.inventory_data.get("gold", 0))
	var meat_count = int(ui.inventory_data.get("meat", 0))
	if wood_count < pending_warehouse_cost_wood or gold_count < pending_warehouse_cost_gold or meat_count < pending_warehouse_cost_meat:
		return
	if free_warehouse_tokens > 0 and warehouse_count <= 0 and pending_warehouse_cost_wood == 0 and pending_warehouse_cost_gold == 0 and pending_warehouse_cost_meat == 0:
		free_warehouse_tokens -= 1
	ui.inventory_data["wood"] = wood_count - pending_warehouse_cost_wood
	ui.inventory_data["gold"] = gold_count - pending_warehouse_cost_gold
	ui.inventory_data["meat"] = meat_count - pending_warehouse_cost_meat
	ui.refresh_inventory_ui()
	var warehouse_pos = _cell_to_world(cell)
	var warehouse = _spawn_warehouse_at_position(warehouse_pos)
	warehouse_count += 1
	pending_warehouse_cost_wood = 0
	pending_warehouse_cost_gold = 0
	pending_warehouse_cost_meat = 0
	if warehouse != null:
		_dispatch_workers_from_warehouse(warehouse, workers_per_warehouse)

func _spawn_warehouse_at_position(world_pos: Vector2) -> Node2D:
	if storage_texture == null:
		return null
	var node = Node2D.new()
	node.name = "Warehouse"
	node.add_to_group("storage")
	var sprite = Sprite2D.new()
	sprite.texture = storage_texture
	sprite.scale = storage_scale
	node.add_child(sprite)
	node.global_position = world_pos
	if objects_container:
		objects_container.add_child(node)
	else:
		add_child(node)
	return node

func _dispatch_workers_from_warehouse(warehouse: Node2D, count: int) -> void:
	if worker_scene == null or warehouse == null or not is_instance_valid(warehouse):
		return
	if objects_container == null:
		return
	var base_position = warehouse.global_position
	for i in range(max(0, count)):
		var worker_instance = worker_scene.instantiate()
		if worker_instance == null or not (worker_instance is Node2D):
			continue
		var angle = world_rng.randf_range(0.0, TAU)
		var dist = max(12.0, worker_exit_distance + world_rng.randf_range(-6.0, 6.0))
		var candidate_exit = base_position + Vector2(cos(angle), sin(angle)) * dist
		var exit_target = _snap_position_to_land(candidate_exit, base_position, max(16.0, worker_exit_distance * 2.0))
		(worker_instance as Node2D).global_position = base_position
		_configure_worker_instance(worker_instance)
		objects_container.add_child(worker_instance)
		if "home_position" in worker_instance:
			worker_instance.home_position = base_position
		if "worker_storage_target" in worker_instance:
			worker_instance.worker_storage_target = warehouse
		if "worker_assigned_storage" in worker_instance:
			worker_instance.worker_assigned_storage = warehouse
		if "worker_exit_active" in worker_instance:
			worker_instance.worker_exit_active = true
		if "worker_exit_target" in worker_instance:
			worker_instance.worker_exit_target = exit_target
		if "worker_wander_active" in worker_instance:
			worker_instance.worker_wander_active = false
		if "worker_wander_target" in worker_instance:
			worker_instance.worker_wander_target = base_position

func _ensure_warehouse_preview() -> void:
	if warehouse_preview != null and is_instance_valid(warehouse_preview):
		warehouse_preview.visible = true
		return
	if storage_texture == null:
		return
	warehouse_preview = Node2D.new()
	warehouse_preview.name = "WarehousePreview"
	warehouse_preview.z_index = 95
	warehouse_preview_sprite = Sprite2D.new()
	warehouse_preview_sprite.texture = storage_texture
	warehouse_preview_sprite.scale = storage_scale
	warehouse_preview_sprite.modulate = Color(1, 1, 1, 0.85)
	warehouse_preview.add_child(warehouse_preview_sprite)
	if objects_container:
		objects_container.add_child(warehouse_preview)
	else:
		add_child(warehouse_preview)

func _clear_warehouse_preview() -> void:
	if warehouse_preview != null and is_instance_valid(warehouse_preview):
		warehouse_preview.queue_free()
	warehouse_preview = null
	warehouse_preview_sprite = null

func _cancel_warehouse_placement() -> void:
	if moving_warehouse != null and is_instance_valid(moving_warehouse):
		moving_warehouse.global_position = moving_warehouse_original_pos
		moving_warehouse.z_index = moving_warehouse_original_z
		var sprite = moving_warehouse.get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			sprite.modulate = Color(1, 1, 1, 1)
	moving_warehouse = null
	placing_warehouse = false
	pending_warehouse_cost_wood = 0
	pending_warehouse_cost_gold = 0
	pending_warehouse_cost_meat = 0
	_clear_warehouse_preview()

func request_plant_redwood_seed() -> void:
	if game_ended:
		return
	if not redwood_enabled:
		return
	var ui = _get_interface()
	if ui == null:
		return
	var seeds = 0
	if "inventory_data" in ui:
		seeds = int(ui.inventory_data.get("redwood_seed", 0))
	if seeds <= 0:
		placing_redwood_seed = false
		_clear_redwood_seed_preview()
		return
	placing_redwood_seed = true
	_ensure_redwood_seed_preview()

func request_release_lamb() -> void:
	if game_ended:
		return
	var ui = _get_interface()
	if ui == null or not ("inventory_data" in ui):
		return
	var count = int(ui.inventory_data.get("lamb", 0))
	if count <= 0:
		return
	ui.inventory_data["lamb"] = count - 1
	ui.refresh_inventory_ui()
	if sheep_scene == null:
		return
	var player = _get_player() as Node2D
	if player == null:
		return
	var spawn_pos = player.global_position + Vector2(world_rng.randf_range(-lamb_release_spawn_radius, lamb_release_spawn_radius), world_rng.randf_range(-lamb_release_spawn_radius, lamb_release_spawn_radius))
	var lamb_instance = sheep_scene.instantiate()
	if lamb_instance == null:
		return
	if lamb_instance is Node2D:
		(lamb_instance as Node2D).global_position = spawn_pos
	objects_container.add_child(lamb_instance)
	if lamb_instance.has_method("configure_released_lamb"):
		lamb_instance.call("configure_released_lamb", lamb_release_mutate_time_sec)
	if lamb_instance.has_signal("died"):
		if not lamb_instance.died.is_connected(_on_sheep_died.bind(lamb_instance)):
			lamb_instance.died.connect(_on_sheep_died.bind(lamb_instance))
	if lamb_instance.has_method("setup_roam"):
		var cell = _world_to_cell(spawn_pos)
		var roam_layer = sheep_spawn_layer
		if use_noise_terrain and ground_layer:
			roam_layer = ground_layer
		lamb_instance.call("setup_roam", roam_layer, cell, sheep_roam_cell_radius)

func _update_redwood_system(delta: float) -> void:
	if redwood_enabled:
		_update_redwood_growth(delta)
	_update_redwood_seed_preview()

func _update_redwood_seed_preview() -> void:
	if not placing_redwood_seed:
		_clear_redwood_seed_preview()
		return
	var mouse_world = get_global_mouse_position()
	var cell = _world_to_cell(mouse_world)
	var world_pos = _cell_to_world(cell)
	var can_place = _can_place_redwood_seed_at_cell(cell)
	_ensure_redwood_seed_preview()
	if redwood_seed_preview != null and is_instance_valid(redwood_seed_preview):
		redwood_seed_preview.global_position = world_pos + Vector2(0, -22)
		if redwood_seed_preview_label != null and is_instance_valid(redwood_seed_preview_label):
			redwood_seed_preview_label.modulate = Color(0.9, 1.0, 0.9, 0.95) if can_place else Color(1.0, 0.55, 0.55, 0.95)

func _ensure_redwood_seed_preview() -> void:
	if redwood_seed_preview != null and is_instance_valid(redwood_seed_preview):
		redwood_seed_preview.visible = true
		return
	redwood_seed_preview = Node2D.new()
	redwood_seed_preview.name = "RedwoodSeedPreview"
	redwood_seed_preview.z_index = 96
	var label = Label.new()
	label.text = "红木种子"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var settings = LabelSettings.new()
	settings.font = preload("res://Fonts/ark-pixel-10px-monospaced-zh_cn.ttf")
	settings.font_size = 18
	settings.outline_size = 5
	settings.outline_color = Color(0, 0, 0, 1)
	label.label_settings = settings
	redwood_seed_preview.add_child(label)
	redwood_seed_preview_label = label
	if objects_container:
		objects_container.add_child(redwood_seed_preview)
	else:
		add_child(redwood_seed_preview)

func _clear_redwood_seed_preview() -> void:
	if redwood_seed_preview != null and is_instance_valid(redwood_seed_preview):
		redwood_seed_preview.queue_free()
	redwood_seed_preview = null
	redwood_seed_preview_label = null

func _cancel_redwood_seed_placement() -> void:
	placing_redwood_seed = false
	_clear_redwood_seed_preview()

func _get_redwood_seed_place_fail_reason(cell: Vector2i) -> String:
	if not redwood_enabled:
		return "系统未启用"
	if not _is_grass_cell(cell):
		return "不是可放置地形"
	if _is_water_cell(cell):
		return "水面不可放置"
	if redwood_planted_cells.has(cell):
		return "已种下"
	var world_pos = _cell_to_world(cell)
	var obstacles = get_tree().get_nodes_in_group("obstacle")
	for obj in obstacles:
		if not (obj is Node2D):
			continue
		if not is_instance_valid(obj):
			continue
		if obj.global_position.distance_to(world_pos) <= redwood_seed_place_clear_radius:
			return "附近有障碍物"
	var storages = get_tree().get_nodes_in_group("storage")
	for s in storages:
		if not (s is Node2D):
			continue
		if not is_instance_valid(s):
			continue
		if s.global_position.distance_to(world_pos) <= redwood_seed_place_clear_radius:
			return "附近已有仓库"
	var piles = get_tree().get_nodes_in_group("collection_pile")
	for p in piles:
		if not (p is Node2D):
			continue
		if not is_instance_valid(p):
			continue
		if p.global_position.distance_to(world_pos) <= redwood_seed_place_clear_radius:
			return "附近已有收集桩"
	return ""

func _can_place_redwood_seed_at_cell(cell: Vector2i) -> bool:
	return _get_redwood_seed_place_fail_reason(cell) == ""

func _place_redwood_seed_at_cell(cell: Vector2i) -> void:
	var ui = _get_interface()
	if ui == null:
		return
	if not ("inventory_data" in ui):
		return
	var seeds = int(ui.inventory_data.get("redwood_seed", 0))
	if seeds <= 0:
		return
	ui.inventory_data["redwood_seed"] = seeds - 1
	ui.refresh_inventory_ui()
	redwood_planted_cells[cell] = true
	redwood_growth_queue.append({"cell_x": cell.x, "cell_y": cell.y, "time": max(0.1, redwood_growth_time_sec)})

func _update_redwood_growth(delta: float) -> void:
	if redwood_growth_queue.is_empty():
		return
	for i in range(redwood_growth_queue.size() - 1, -1, -1):
		var item = redwood_growth_queue[i]
		item["time"] = float(item.get("time", 0.0)) - delta
		redwood_growth_queue[i] = item
		if float(item["time"]) <= 0.0:
			var cell = Vector2i(int(item.get("cell_x", 0)), int(item.get("cell_y", 0)))
			_spawn_redwood_tree_at_cell(cell)
			redwood_planted_cells.erase(cell)
			redwood_growth_queue.remove_at(i)

func _spawn_redwood_tree_at_cell(cell: Vector2i) -> void:
	if redwood_tree_scene == null:
		return
	if not _is_grass_cell(cell) or _is_water_cell(cell):
		return
	var world_pos = _cell_to_world(cell)
	if not _is_respawn_position_clear(world_pos):
		return
	var inst = redwood_tree_scene.instantiate()
	if inst == null:
		return
	if inst is Node2D:
		(inst as Node2D).position = world_pos
	if "drop_item_type" in inst:
		inst.drop_item_type = "redwood"
	if "min_drop" in inst:
		inst.min_drop = 2
	if "max_drop" in inst:
		inst.max_drop = 4
	if "type" in inst:
		inst.type = "Tree"
	if "redwood_seed_drop_chance" in inst:
		inst.redwood_seed_drop_chance = 0.0
	if objects_container:
		objects_container.add_child(inst)
	else:
		add_child(inst)
	_register_spawned_object(inst)
	var sprite = inst.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)

func _update_warehouse_hover_and_preview() -> void:
	var mouse_world = get_global_mouse_position()
	hovered_warehouse = null
	var best = 28.0
	if placing_redwood_seed:
		hovered_warehouse = null
		return
	if not placing_warehouse:
		var storages = get_tree().get_nodes_in_group("storage")
		for s in storages:
			var node := s as Node2D
			if node == null:
				continue
			if not is_instance_valid(node):
				continue
			var d = mouse_world.distance_to(node.global_position)
			if d <= best:
				best = d
				hovered_warehouse = node
	if not placing_warehouse:
		_clear_warehouse_preview()
		return
	var cell = _world_to_cell(mouse_world)
	var world_pos = _cell_to_world(cell)
	var can_place = _can_place_warehouse_at_cell(cell, moving_warehouse)
	if moving_warehouse != null and is_instance_valid(moving_warehouse):
		moving_warehouse.global_position = world_pos
		var moving_sprite = moving_warehouse.get_node_or_null("Sprite2D") as Sprite2D
		if moving_sprite != null:
			moving_sprite.modulate = Color(0.9, 1.0, 0.9, 1.0) if can_place else Color(1.0, 0.6, 0.6, 1.0)
		return
	_ensure_warehouse_preview()
	if warehouse_preview != null and is_instance_valid(warehouse_preview):
		warehouse_preview.global_position = world_pos
		if warehouse_preview_sprite != null and is_instance_valid(warehouse_preview_sprite):
			warehouse_preview_sprite.modulate = Color(0.9, 1.0, 0.9, 0.85) if can_place else Color(1.0, 0.6, 0.6, 0.85)

func _recompute_exp_to_next() -> void:
	var base = max(1, exp_base_to_next)
	var lvl = max(1, player_level)
	exp_to_next = int(round(float(base) * pow(max(1.0, exp_growth), float(lvl - 1))))
	exp_to_next = max(1, exp_to_next)

func _add_experience(amount: int) -> void:
	if amount <= 0:
		return
	player_exp += amount
	while player_exp >= exp_to_next:
		player_exp -= exp_to_next
		player_level += 1
		_recompute_exp_to_next()
	_apply_worker_speed_multiplier()

func _get_total_worker_speed_multiplier() -> float:
	var exp_mult = 1.0 + float(max(0, player_level - 1)) * exp_speed_per_level
	return max(0.1, logistics_multiplier * exp_mult)

func _apply_worker_speed_multiplier() -> void:
	get_tree().call_group(worker_group_name, "set_logistics_multiplier", _get_total_worker_speed_multiplier())

func _spawn_threat_wave() -> bool:
	if archer_scene == null:
		return false
	var wave_count = _compute_next_wave_size()
	if wave_count <= 0:
		return false
	last_wave_spawned_count = 0
	for i in range(wave_count):
		var ok = _spawn_archer_at_cell()
		if ok:
			last_wave_spawned_count += 1
	if last_wave_spawned_count <= 0:
		return false
	waves_survived += 1
	return true

func _spawn_archer_at_cell() -> bool:
	var available_cells: Array[Vector2i] = deep_mountain_cells
	if available_cells.is_empty():
		available_cells = land_cells
	if available_cells.is_empty():
		return false
	var random_cell := Vector2i.ZERO
	var found_cell = false
	var tries = min(available_cells.size(), 48)
	for i in range(tries):
		var candidate = available_cells[world_rng.randi_range(0, available_cells.size() - 1)]
		if _is_water_cell(candidate) or not _is_grass_cell(candidate):
			continue
		random_cell = candidate
		found_cell = true
		break
	if not found_cell:
		return false
	var archer_instance = archer_scene.instantiate()
	archer_instance.position = _cell_to_world(random_cell)
	objects_container.add_child(archer_instance)
	if archer_instance.has_method("setup_roam"):
		var roam_layer = sheep_spawn_layer
		if use_noise_terrain and ground_layer:
			roam_layer = ground_layer
		archer_instance.setup_roam(roam_layer, random_cell, archer_roam_cell_radius)
	return true

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
	_maybe_make_rainbow_gold(obj_instance)
	_register_spawned_object(obj_instance)
	_mark_occupied(cell, occupied)

func _maybe_make_rainbow_gold(obj_instance: Node) -> void:
	if obj_instance == null:
		return
	if not ("drop_item_type" in obj_instance):
		return
	if str(obj_instance.drop_item_type) != "gold":
		return
	if rainbow_gold_spawn_chance <= 0.0:
		return
	if world_rng.randf() >= rainbow_gold_spawn_chance:
		return
	obj_instance.drop_item_type = "rainbow_gold"
	var sprite = obj_instance.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.modulate = Color.from_hsv(world_rng.randf(), 0.75, 1.0, 1.0)

func _register_spawned_object(obj_instance: Node) -> void:
	if obj_instance == null:
		return
	if obj_instance.has_signal("destroyed"):
		if not obj_instance.destroyed.is_connected(_on_object_destroyed):
			obj_instance.destroyed.connect(_on_object_destroyed)

func _award_player_exp_for_destroyed_object(object_type: String, drop_type: String) -> void:
	var obj = object_type.to_lower()
	var drop = drop_type.to_lower()
	var amount = 0
	if obj.find("tree") != -1 or drop == "wood":
		amount = exp_per_tree_harvest
	elif obj.find("gold") != -1:
		amount = exp_per_gold_harvest
	elif obj.find("rock") != -1:
		amount = exp_per_rock_harvest
	elif drop == "gold" or drop == "rainbow_gold":
		amount = exp_per_gold_harvest
	if amount > 0:
		_add_experience(amount)

func _on_object_destroyed(object_type: String, drop_type: String, _world_position: Vector2) -> void:
	if not game_ended:
		_award_player_exp_for_destroyed_object(object_type, drop_type)
	var obj = object_type.to_lower()
	if obj.find("tree") != -1:
		if not tree_respawn_enabled:
			return
		if tree_respawn_queue.size() >= tree_respawn_max_pending:
			return
		var delay = randf_range(tree_respawn_delay_min, tree_respawn_delay_max)
		if entropy_enabled and entropy_tree_respawn_delay_per_point > 0.0:
			var mult = 1.0 + entropy * entropy_tree_respawn_delay_per_point
			delay *= clamp(mult, 1.0, 6.0)
		tree_respawn_queue.append({"time": delay})
	elif obj.find("rock") != -1:
		if not rock_respawn_enabled:
			return
		if rock_respawn_queue.size() >= rock_respawn_max_pending:
			return
		var delay = randf_range(rock_respawn_delay_min, rock_respawn_delay_max)
		rock_respawn_queue.append({"time": delay})
	elif obj.find("gold") != -1:
		if not gold_respawn_enabled:
			return
		if gold_respawn_queue.size() >= gold_respawn_max_pending:
			return
		var delay = randf_range(gold_respawn_delay_min, gold_respawn_delay_max)
		gold_respawn_queue.append({"time": delay})

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
		var world_pos = _cell_to_world(cell)
		if _is_respawn_position_clear(world_pos):
			var scene = tree_scenes[world_rng.randi_range(0, tree_scenes.size() - 1)]
			var obj_instance = scene.instantiate()
			obj_instance.position = world_pos
			objects_container.add_child(obj_instance)
			_register_spawned_object(obj_instance)
			return true
	return false

func _update_rock_respawn(delta: float) -> void:
	if not rock_respawn_enabled:
		return
	if rock_respawn_queue.is_empty():
		return
	for i in range(rock_respawn_queue.size() - 1, -1, -1):
		var item = rock_respawn_queue[i]
		item["time"] = float(item["time"]) - delta
		rock_respawn_queue[i] = item
		if float(item["time"]) <= 0.0:
			if _spawn_respawn_object_from_set("rock", rock_respawn_attempts):
				rock_respawn_queue.remove_at(i)
			else:
				item["time"] = 1.5
				rock_respawn_queue[i] = item

func _update_gold_respawn(delta: float) -> void:
	if not gold_respawn_enabled:
		return
	if gold_respawn_queue.is_empty():
		return
	for i in range(gold_respawn_queue.size() - 1, -1, -1):
		var item = gold_respawn_queue[i]
		item["time"] = float(item["time"]) - delta
		gold_respawn_queue[i] = item
		if float(item["time"]) <= 0.0:
			if _spawn_respawn_object_from_set("gold", gold_respawn_attempts):
				gold_respawn_queue.remove_at(i)
			else:
				item["time"] = 1.5
				gold_respawn_queue[i] = item

func _spawn_respawn_object_from_set(set_key: String, attempts_raw: int) -> bool:
	var sets = _pick_object_scenes_by_type()
	var scenes = _to_packed_scene_array(sets.get(set_key, []))
	if scenes.is_empty():
		return false
	var attempts = max(1, attempts_raw)
	var candidate_cells: Array[Vector2i] = []
	if use_noise_terrain and not land_cells.is_empty():
		candidate_cells = land_cells
	else:
		candidate_cells = spawn_layer.get_used_cells()
	if candidate_cells.is_empty():
		return false
	for i in range(attempts):
		var cell = candidate_cells[world_rng.randi_range(0, candidate_cells.size() - 1)]
		var world_pos = _cell_to_world(cell)
		if _is_respawn_position_clear(world_pos):
			var scene = scenes[world_rng.randi_range(0, scenes.size() - 1)]
			var obj_instance = scene.instantiate()
			obj_instance.position = world_pos
			objects_container.add_child(obj_instance)
			_maybe_make_rainbow_gold(obj_instance)
			_register_spawned_object(obj_instance)
			return true
	return false

func _update_sheep_respawn(delta: float) -> void:
	if auto_workers_only or not sheep_respawn_enabled:
		return
	if sheep_respawn_queue.is_empty():
		return
	for i in range(sheep_respawn_queue.size() - 1, -1, -1):
		var item = sheep_respawn_queue[i]
		item["time"] = float(item["time"]) - delta
		sheep_respawn_queue[i] = item
		if float(item["time"]) <= 0.0:
			var pos = Vector2(item.get("pos", Vector2.ZERO))
			if _spawn_sheep_respawn(pos):
				sheep_respawn_queue.remove_at(i)
			else:
				item["time"] = 1.5
				sheep_respawn_queue[i] = item

func _spawn_sheep_respawn(origin_world_pos: Vector2) -> bool:
	if sheep_scene == null:
		return false
	var attempts = max(1, sheep_respawn_attempts)
	for i in range(attempts):
		var candidate_pos = origin_world_pos + Vector2(
			randf_range(-sheep_respawn_scatter_radius, sheep_respawn_scatter_radius),
			randf_range(-sheep_respawn_scatter_radius, sheep_respawn_scatter_radius)
		)
		if not _is_respawn_position_clear(candidate_pos):
			continue
		var sheep_instance = sheep_scene.instantiate()
		if sheep_instance == null:
			return false
		if sheep_instance is Node2D:
			(sheep_instance as Node2D).global_position = candidate_pos
		objects_container.add_child(sheep_instance)
		if sheep_instance.has_signal("died"):
			if not sheep_instance.died.is_connected(_on_sheep_died):
				sheep_instance.died.connect(_on_sheep_died.bind(sheep_instance))
		if sheep_instance.has_method("setup_roam"):
			var roam_layer = sheep_spawn_layer
			if use_noise_terrain and ground_layer:
				roam_layer = ground_layer
			var cell = roam_layer.local_to_map(roam_layer.to_local(candidate_pos))
			sheep_instance.setup_roam(roam_layer, cell, sheep_roam_cell_radius)
		return true
	return false

func _is_respawn_position_clear(world_pos: Vector2) -> bool:
	var obstacles = get_tree().get_nodes_in_group("obstacle")
	for obj in obstacles:
		if not (obj is Node2D):
			continue
		if not is_instance_valid(obj):
			continue
		if obj.global_position.distance_to(world_pos) < 24.0:
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
	var layer = _get_primary_map_layer()
	if layer != null:
		return layer.map_to_local(cell)
	return Vector2(cell) * 64.0

func _normalize_save_slot(value: String) -> String:
	var s = value.strip_edges()
	if s.is_empty():
		s = "默认存档"
	s = s.replace("/", "_")
	s = s.replace("\\", "_")
	s = s.replace("..", "_")
	s = s.replace(":", "_")
	s = s.replace("*", "_")
	s = s.replace("?", "_")
	s = s.replace("\"", "_")
	s = s.replace("<", "_")
	s = s.replace(">", "_")
	s = s.replace("|", "_")
	if s.length() > 40:
		s = s.substr(0, 40)
	return s

func _get_save_path(slot: String) -> String:
	return "user://save_" + _normalize_save_slot(slot) + ".json"

func set_save_slot(new_slot: String) -> void:
	save_slot = _normalize_save_slot(new_slot)

static var pending_boot_save_slot: String = ""

func get_save_slot() -> String:
	return save_slot

func list_save_slots() -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open("user://")
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if file_name.begins_with("save_") and file_name.ends_with(".json"):
			var slot = file_name.substr(5, file_name.length() - 5 - 5)
			result.append(slot)
	dir.list_dir_end()
	result.sort()
	return result

func rename_save_slot(from_slot: String, to_slot: String) -> bool:
	var from_name = _normalize_save_slot(from_slot)
	var to_name = _normalize_save_slot(to_slot)
	if from_name == to_name:
		return false
	var from_path = _get_save_path(from_name)
	var to_path = _get_save_path(to_name)
	if not FileAccess.file_exists(from_path):
		return false
	if FileAccess.file_exists(to_path):
		return false
	var abs_from = ProjectSettings.globalize_path(from_path)
	var abs_to = ProjectSettings.globalize_path(to_path)
	if DirAccess.rename_absolute(abs_from, abs_to) != OK:
		return false
	save_slot = to_name
	return true

func request_manual_load(slot: String = "") -> bool:
	if not save_enabled:
		return false
	var target = save_slot if slot.strip_edges().is_empty() else slot
	target = _normalize_save_slot(target)
	var path = _get_save_path(target)
	if not FileAccess.file_exists(path):
		return false
	pending_boot_save_slot = target
	get_tree().reload_current_scene()
	return true

func _load_save_if_enabled() -> bool:
	if not save_enabled:
		return false
	var ui = _get_interface()
	if ui == null:
		return false
	save_slot = _normalize_save_slot(save_slot)
	var d = _read_save_payload(save_slot)
	if d.is_empty():
		return false
	_apply_loaded_payload(d)
	return true

func _read_save_payload(slot: String) -> Dictionary:
	var normalized = _normalize_save_slot(slot)
	var path = _get_save_path(normalized)
	if not FileAccess.file_exists(path):
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text = f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data as Dictionary

func _apply_loaded_payload(d: Dictionary) -> void:
	if d.has("cpu_level"):
		cpu_level = max(1, int(d["cpu_level"]))
	if d.has("enemy_kill_exp"):
		enemy_kill_exp = max(0, int(d["enemy_kill_exp"]))
	if d.has("waves_survived"):
		waves_survived = max(0, int(d["waves_survived"]))
	if d.has("player_level"):
		player_level = max(1, int(d["player_level"]))
	if d.has("player_exp"):
		player_exp = max(0, int(d["player_exp"]))
	if d.has("entropy"):
		entropy = max(0.0, float(d["entropy"]))
	if d.has("energy_points"):
		energy_points = float(d["energy_points"])
	if d.has("archer_wave_timer"):
		archer_wave_timer = max(0.0, float(d["archer_wave_timer"]))
	if d.has("wood_burn_timer"):
		wood_burn_timer = max(0.0, float(d["wood_burn_timer"]))
	if d.has("pile_build_timer"):
		pile_build_timer = max(0.0, float(d["pile_build_timer"]))
	if d.has("game_time_sec"):
		game_time_sec = max(0.0, float(d["game_time_sec"]))
	if d.has("enemy_kills"):
		enemy_kills = max(0, int(d["enemy_kills"]))
	if d.has("free_warehouse_tokens"):
		free_warehouse_tokens = max(0, int(d["free_warehouse_tokens"]))
	logistics_multiplier = 1.0 + float(cpu_level - 1) * logistics_speed_per_level
	_apply_worker_speed_multiplier()
	_recompute_exp_to_next()
	var ui = _get_interface()
	if ui != null:
		if "inventory_data" in ui and d.has("inventory_data") and typeof(d["inventory_data"]) == TYPE_DICTIONARY:
			ui.inventory_data = d["inventory_data"]
		if d.has("quickbar_items") and typeof(d["quickbar_items"]) == TYPE_ARRAY and "quickbar_items" in ui:
			var raw := d["quickbar_items"] as Array
			var out: Array[String] = []
			for v in raw:
				out.append(String(v))
			var target_size = int((ui.quickbar_items as Array).size())
			while out.size() < target_size:
				out.append("")
			if out.size() > target_size:
				out = out.slice(0, target_size)
			ui.quickbar_items = out
		if ui.has_method("refresh_inventory_ui"):
			ui.refresh_inventory_ui()
	var player = _get_player()
	if player != null and d.has("player_pos") and typeof(d["player_pos"]) == TYPE_DICTIONARY:
		var pos_d := d["player_pos"] as Dictionary
		if pos_d.has("x") and pos_d.has("y"):
			player.global_position = Vector2(float(pos_d["x"]), float(pos_d["y"]))
			_reset_camera()
	redwood_growth_queue.clear()
	redwood_planted_cells.clear()
	if redwood_enabled and d.has("redwood_growth") and typeof(d["redwood_growth"]) == TYPE_ARRAY:
		for item in d["redwood_growth"]:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var it := item as Dictionary
			if not (it.has("cell_x") and it.has("cell_y") and it.has("time")):
				continue
			var cx = int(it["cell_x"])
			var cy = int(it["cell_y"])
			var t = max(0.0, float(it["time"]))
			redwood_growth_queue.append({"cell_x": cx, "cell_y": cy, "time": t})
			redwood_planted_cells[Vector2i(cx, cy)] = true
	_restore_warehouses_from_save(d)
	_restore_collection_piles_from_save(d)
	_restore_workers_from_save(d)

func _restore_warehouses_from_save(d: Dictionary) -> void:
	var storages = get_tree().get_nodes_in_group("storage")
	for node in storages:
		if node == null or not is_instance_valid(node):
			continue
		if node.name == "GlobalStorage":
			continue
		node.queue_free()
	warehouse_count = 0
	if not d.has("warehouses") or typeof(d["warehouses"]) != TYPE_ARRAY:
		if d.has("warehouse_count"):
			warehouse_count = max(0, int(d["warehouse_count"]))
		return
	var spawned = 0
	for item in d["warehouses"]:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var it := item as Dictionary
		if not (it.has("x") and it.has("y")):
			continue
		_spawn_warehouse_at_position(Vector2(float(it["x"]), float(it["y"])))
		spawned += 1
	warehouse_count = spawned

func _restore_collection_piles_from_save(d: Dictionary) -> void:
	var piles = get_tree().get_nodes_in_group("collection_pile")
	for node in piles:
		if node == null or not is_instance_valid(node):
			continue
		node.queue_free()
	collection_piles.clear()
	if not d.has("collection_piles") or typeof(d["collection_piles"]) != TYPE_ARRAY:
		return
	for item in d["collection_piles"]:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var it := item as Dictionary
		if not (it.has("x") and it.has("y")):
			continue
		_spawn_collection_pile_at_position_force(Vector2(float(it["x"]), float(it["y"])))
	_update_logistics_power()

func _spawn_collection_pile_at_position_force(pile_position: Vector2) -> void:
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

func _restore_workers_from_save(_d: Dictionary) -> void:
	var workers = get_tree().get_nodes_in_group(worker_group_name)
	for w in workers:
		if w == null or not is_instance_valid(w):
			continue
		if "worker_mode" in w and w.worker_mode:
			w.queue_free()
	_apply_worker_speed_multiplier()

func request_new_run() -> bool:
	pending_boot_save_slot = ""
	get_tree().reload_current_scene()
	return true

func _ensure_initial_warehouse_and_workers() -> void:
	if warehouse_count > 0:
		return
	var player = _get_player()
	if player == null:
		call_deferred("_ensure_initial_warehouse_and_workers")
		return
	var origin_cell = _world_to_cell(player.global_position)
	var chosen_cell = origin_cell
	var found = false
	for r in range(0, 17):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c = origin_cell + Vector2i(dx, dy)
				if not _can_place_warehouse_at_cell(c):
					continue
				chosen_cell = c
				found = true
				break
			if found:
				break
		if found:
			break
	var warehouse_pos = _cell_to_world(chosen_cell)
	if not found:
		warehouse_pos = _pick_land_position_near(player.global_position, 320.0, 200)
	var warehouse = _spawn_warehouse_at_position(warehouse_pos)
	warehouse_count = 1
	free_warehouse_tokens = 0
	if warehouse != null:
		_dispatch_workers_from_warehouse(warehouse, workers_per_warehouse)

func _save_game() -> bool:
	if not save_enabled:
		return false
	var ui = _get_interface()
	if ui == null:
		return false
	var payload: Dictionary = {
		"version": 3,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"noise_seed": int(noise_seed),
		"cpu_level": int(cpu_level),
		"enemy_kill_exp": int(enemy_kill_exp),
		"waves_survived": int(waves_survived),
		"player_level": int(player_level),
		"player_exp": int(player_exp),
		"entropy": float(entropy),
		"energy_points": float(energy_points),
		"archer_wave_timer": float(archer_wave_timer),
		"wood_burn_timer": float(wood_burn_timer),
		"pile_build_timer": float(pile_build_timer),
		"game_time_sec": float(game_time_sec),
		"enemy_kills": int(enemy_kills),
		"warehouse_count": int(warehouse_count),
		"free_warehouse_tokens": int(free_warehouse_tokens)
	}
	var player = _get_player()
	if player != null:
		payload["player_pos"] = {"x": float(player.global_position.x), "y": float(player.global_position.y)}
	if redwood_enabled and not redwood_growth_queue.is_empty():
		var out: Array = []
		for item in redwood_growth_queue:
			var cx = int(item.get("cell_x", 0))
			var cy = int(item.get("cell_y", 0))
			var t = float(item.get("time", 0.0))
			out.append({"cell_x": cx, "cell_y": cy, "time": t})
		payload["redwood_growth"] = out
	if "inventory_data" in ui:
		payload["inventory_data"] = ui.inventory_data
	if "quickbar_items" in ui:
		payload["quickbar_items"] = ui.quickbar_items
	var warehouses_out: Array = []
	for node in get_tree().get_nodes_in_group("storage"):
		if node == null or not is_instance_valid(node):
			continue
		if node.name == "GlobalStorage":
			continue
		if not (node is Node2D):
			continue
		var p = (node as Node2D).global_position
		warehouses_out.append({"x": float(p.x), "y": float(p.y)})
	payload["warehouses"] = warehouses_out
	var piles_out: Array = []
	for node in get_tree().get_nodes_in_group("collection_pile"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		var p = (node as Node2D).global_position
		piles_out.append({"x": float(p.x), "y": float(p.y)})
	payload["collection_piles"] = piles_out
	var workers_out: Array = []
	for node in get_tree().get_nodes_in_group(worker_group_name):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		if "worker_mode" in node and node.worker_mode:
			var p = (node as Node2D).global_position
			workers_out.append({"x": float(p.x), "y": float(p.y)})
	payload["workers"] = workers_out
	var json_text = JSON.stringify(payload)
	save_slot = _normalize_save_slot(save_slot)
	var path = _get_save_path(save_slot)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(json_text)
	f.close()
	return true

func request_manual_save(slot: String = "") -> bool:
	if not slot.strip_edges().is_empty():
		set_save_slot(slot)
	return _save_game()
