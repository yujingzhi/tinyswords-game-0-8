extends CharacterBody2D
class_name CharacterBase 



# ==========================================
# ⚙️ 1. 编辑器配置区域 (Exports)
# ==========================================
@export_category("Node References")
@export var sprite: Sprite2D = null           
@export var animation_player: AnimationPlayer = null 
@onready var area_attack_node: Area2D = $AreaAttack
@export_category("Movement & Stats")
@export var move_speed: float = 200.0         
@export_dir var texture_folder_path: String = "res://CharacterBase" 
@export var max_health: int = 10
@export var max_stamina: int = 100
@export var stamina_drain_rate: float = 8.0
@export var stamina_regen_rate: float = 18.0
@export var hit_flash_color: Color = Color(1, 0.4, 0.4, 1)
@export var hit_flash_time: float = 0.12

@export_category("Audio SFX")
@export var sfx_wood: AudioStream             
@export var sfx_stone: AudioStream            
@export var sfx_heavy: AudioStream            
@export var sfx_sharp: AudioStream            
@export var sfx_knife: AudioStream            
@export var sfx_hand: AudioStream             

# ✨ 优化：使用强类型的枚举来定义工具
enum ToolType { 
	HAND = -1, 
	HAMMER = 0, 
	AXE = 1, 
	KNIFE = 2, 
	PICKAXE = 3 
}



# ==========================================
# 🔗 2. 内部节点与状态变量
# ==========================================
@onready var attack_area_collision: CollisionShape2D = $AreaAttack/CollisionShape2D
@onready var step_audio: AudioStreamPlayer = $StepAudio
@onready var fx_audio: AudioStreamPlayer = $FXAudio 

# --- ⚔️ 武器系统状态 ---
# 将原本的 int 替换为 ToolType
var current_weapon_index: ToolType = ToolType.HAND
var current_weapon_suffix: String = "" 
const MAX_WEAPON_COUNT: int = 4

# --- 🏃‍♂️ 角色状态机 ---
var is_attacking: bool = false 
var current_health: int
var current_stamina: float
var hit_tween: Tween
var hit_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Explosion_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Explosion_02.png"), "frames": 10}
]

# --- 🎵 行走音效时钟 ---
var step_timer: float = 0.0
const STEP_INTERVAL: float = 0.35 # 脚步声间隔(秒)，数值越小响得越快

# 💡 图片缓存字典
var texture_cache: Dictionary = {}
var navigation_layer: TileMapLayer = null
var navigation_grid: AStarGrid2D = null
var navigation_region: Rect2i
var navigation_tile_size: Vector2 = Vector2.ZERO
var auto_path: Array[Vector2] = []
var auto_path_index: int = 0
var auto_move_active: bool = false
var auto_target: Node2D = null
var auto_attack_active: bool = false
var auto_attack_timer: float = 0.0
var auto_repath_timer: float = 0.0
var attack_range: float = 40.0

# ==========================================
# 🚀 3. 生命周期与输入中枢
# ==========================================
func _ready() -> void:
	# 🌟 强制给主角上户口，确保无论在哪个地图，掉落物都能认出你！
	add_to_group("player")
	add_to_group("peao")
	current_health = max_health
	current_stamina = float(max_stamina)
	get_tree().call_group("interface", "update_player_health", current_health, max_health)
	get_tree().call_group("interface", "update_player_stamina", int(round(current_stamina)), max_stamina)
	
	_update_weapon_state()
	if attack_area_collision:
		attack_area_collision.disabled = true
		
	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	if attack_area_collision and attack_area_collision.shape is CircleShape2D:
		attack_range = (attack_area_collision.shape as CircleShape2D).radius + 6.0
	_setup_navigation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(get_global_mouse_position())
		return
	if is_attacking:
		return

	if event.is_action_pressed("weapon_1"): _toggle_weapon(0)
	elif event.is_action_pressed("weapon_2"): _toggle_weapon(1)
	elif event.is_action_pressed("weapon_3"): _toggle_weapon(2)
	elif event.is_action_pressed("weapon_4"): _toggle_weapon(3)
	
	elif event.is_action_pressed("scroll_up"): _cycle_weapon(1)
	elif event.is_action_pressed("scroll_down"): _cycle_weapon(-1)
	
	elif event.is_action_pressed("attack") and current_weapon_index != ToolType.HAND and not (event is InputEventMouseButton):
		_start_attack()

# ==========================================
# 🔄 4. 武器切换逻辑
# ==========================================
func _toggle_weapon(target_index: int) -> void:
	var target_tool = target_index as ToolType
	if current_weapon_index == target_tool:
		current_weapon_index = ToolType.HAND
	else:
		current_weapon_index = target_tool
	_update_weapon_state()

func _cycle_weapon(direction: int) -> void:
	var next_index = int(current_weapon_index) + direction
	if next_index >= MAX_WEAPON_COUNT:
		next_index = int(ToolType.HAND)
	elif next_index < int(ToolType.HAND):
		next_index = MAX_WEAPON_COUNT - 1
	current_weapon_index = next_index as ToolType
	_update_weapon_state()

func _update_weapon_state() -> void:
	get_tree().call_group("interface", "update_weapon_indicator", current_weapon_index)
	
	match current_weapon_index:
		ToolType.HAND: current_weapon_suffix = ""; _play_sfx(sfx_hand)
		ToolType.HAMMER: current_weapon_suffix = "_Hammer"; _play_sfx(sfx_heavy)
		ToolType.AXE: current_weapon_suffix = "_Axe"; _play_sfx(sfx_sharp)
		ToolType.KNIFE: current_weapon_suffix = "_Knife"; _play_sfx(sfx_knife if sfx_knife else sfx_sharp)
		ToolType.PICKAXE: current_weapon_suffix = "_Pickaxe"; _play_sfx(sfx_sharp)

func _play_sfx(stream: AudioStream) -> void:
	if fx_audio and stream:
		fx_audio.stream = stream
		fx_audio.play()

func _equip_tool(tool: ToolType) -> void:
	if current_weapon_index == tool:
		return
	current_weapon_index = tool
	_update_weapon_state()

func _setup_navigation() -> void:
	navigation_layer = get_tree().current_scene.get_node_or_null("Terrain/Layer_Ground") as TileMapLayer
	if navigation_layer == null:
		return
	navigation_grid = AStarGrid2D.new()
	navigation_tile_size = Vector2(navigation_layer.tile_set.tile_size)
	navigation_region = navigation_layer.get_used_rect()
	navigation_grid.region = navigation_region
	navigation_grid.cell_size = navigation_tile_size
	navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation_grid.update()
	_refresh_navigation_solids()

func _handle_click(world_pos: Vector2) -> void:
	if navigation_layer == null or navigation_grid == null:
		return
	var target_node = _pick_click_target(world_pos)
	if is_instance_valid(target_node):
		var tool = _desired_tool_for_target(target_node)
		if tool != ToolType.HAND:
			_equip_tool(tool)
		auto_target = target_node
		auto_attack_active = tool != ToolType.HAND
		_start_move_to_position(target_node.global_position)
	else:
		auto_target = null
		auto_attack_active = false
		_start_move_to_position(world_pos)

func _pick_click_target(world_pos: Vector2) -> Node2D:
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 1 | 4
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var results = get_world_2d().direct_space_state.intersect_point(query, 32)
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for hit in results:
		var collider = hit.collider
		if collider == self:
			continue
		if collider is ObjectBase or collider is Sheep or collider.is_in_group("enemy"):
			var node = collider as Node2D
			if node:
				var dist = world_pos.distance_to(node.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = node
	return nearest

func _desired_tool_for_target(target: Node) -> ToolType:
	if target is Sheep:
		return ToolType.KNIFE
	if target.is_in_group("enemy"):
		return ToolType.KNIFE
	var obj = target as ObjectBase
	if is_instance_valid(obj):
		var target_type = obj.type.to_lower()
		if target_type == "tree":
			return ToolType.AXE
		if target_type == "rock" or target_type == "gold":
			return ToolType.PICKAXE
	return ToolType.HAND

func _start_move_to_position(target_pos: Vector2) -> void:
	if navigation_layer == null or navigation_grid == null:
		return
	_refresh_navigation_solids()
	var start_cell = _world_to_cell(global_position)
	var target_cell = _world_to_cell(target_pos)
	if not navigation_region.has_point(start_cell):
		return
	target_cell = _find_walkable_cell(target_cell)
	if not navigation_region.has_point(target_cell):
		return
	var cell_path = navigation_grid.get_id_path(start_cell, target_cell)
	auto_path.clear()
	for cell_value in cell_path:
		var cell = cell_value
		if cell_value is Vector2:
			cell = Vector2i(int(round(cell_value.x)), int(round(cell_value.y)))
		auto_path.append(_cell_to_world(cell))
	auto_path_index = 0
	auto_move_active = auto_path.size() > 0

func _find_walkable_cell(cell: Vector2i) -> Vector2i:
	if navigation_region.has_point(cell) and not navigation_grid.is_point_solid(cell):
		return cell
	for radius in range(1, 4):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var candidate = cell + Vector2i(x, y)
				if navigation_region.has_point(candidate) and not navigation_grid.is_point_solid(candidate):
					return candidate
	return cell

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return navigation_layer.local_to_map(navigation_layer.to_local(world_pos))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return navigation_layer.to_global(navigation_layer.map_to_local(cell))

func _refresh_navigation_solids() -> void:
	if navigation_grid == null or navigation_layer == null:
		return
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [self]
	for x in range(navigation_region.position.x, navigation_region.position.x + navigation_region.size.x):
		for y in range(navigation_region.position.y, navigation_region.position.y + navigation_region.size.y):
			var cell = Vector2i(x, y)
			navigation_grid.set_point_solid(cell, false)
			var world_point = _cell_to_world(cell)
			query.position = world_point
			var hits = space_state.intersect_point(query, 8)
			for hit in hits:
				var collider = hit.collider
				if collider is TileMapLayer or collider is StaticBody2D:
					navigation_grid.set_point_solid(cell, true)
					break

func _get_auto_direction() -> Vector2:
	if not auto_move_active or auto_path.is_empty():
		return Vector2.ZERO
	if auto_path_index >= auto_path.size():
		auto_move_active = false
		return Vector2.ZERO
	var target_point = auto_path[auto_path_index]
	var to_target = target_point - global_position
	if to_target.length() < 6.0:
		auto_path_index += 1
		if auto_path_index >= auto_path.size():
			auto_move_active = false
			return Vector2.ZERO
		target_point = auto_path[auto_path_index]
		to_target = target_point - global_position
	return to_target.normalized()

func _stop_auto(clear_target: bool) -> void:
	auto_move_active = false
	auto_path.clear()
	auto_path_index = 0
	auto_attack_active = false
	if clear_target:
		auto_target = null

func _apply_move_direction(direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		velocity = direction * move_speed
		current_stamina = clamp(current_stamina - stamina_drain_rate * delta, 0.0, float(max_stamina))
		step_timer -= delta
		if step_timer <= 0.0:
			if step_audio:
				step_audio.play()
			step_timer = STEP_INTERVAL
	else:
		velocity = Vector2.ZERO
		step_timer = 0.0
		current_stamina = clamp(current_stamina + stamina_regen_rate * delta, 0.0, float(max_stamina))

# ==========================================
# 🏃‍♂️ 5. 物理移动与渲染引擎
# ==========================================
func _physics_process(_delta: float) -> void:
	var stamina_before = int(round(current_stamina))
	auto_attack_timer = max(auto_attack_timer - _delta, 0.0)
	auto_repath_timer = max(auto_repath_timer - _delta, 0.0)
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != Vector2.ZERO:
		_stop_auto(true)
	if auto_target and not is_instance_valid(auto_target):
		_stop_auto(true)
	if is_attacking:
		velocity = Vector2.ZERO
	else:
		if auto_attack_active and is_instance_valid(auto_target):
			var target_pos = auto_target.global_position
			var distance = global_position.distance_to(target_pos)
			if distance <= attack_range:
				velocity = Vector2.ZERO
				auto_move_active = false
				if current_weapon_index != ToolType.HAND and auto_attack_timer <= 0.0 and not is_attacking:
					_start_attack()
					auto_attack_timer = 0.1
			else:
				if auto_repath_timer <= 0.0:
					_start_move_to_position(target_pos)
					auto_repath_timer = 0.4
				var auto_direction = _get_auto_direction()
				_apply_move_direction(auto_direction, _delta)
		elif auto_move_active:
			var auto_direction = _get_auto_direction()
			_apply_move_direction(auto_direction, _delta)
		else:
			_apply_move_direction(input_direction, _delta)
			
	move_and_slide()
	var stamina_now = int(round(current_stamina))
	if stamina_now != stamina_before:
		get_tree().call_group("interface", "update_player_stamina", stamina_now, max_stamina)
	
	# --- 状态与动画名推演 ---
	var state_name = "Idle"
	var file_prefix = "Idle"
	var target_hframes = 8
	
	if is_attacking:
		file_prefix = "Interact"
		if "_Hammer" in current_weapon_suffix:
			state_name = "Attack_Hammer_3f"; target_hframes = 3
		elif "_Knife" in current_weapon_suffix:
			state_name = "Attack_Knife_4f"; target_hframes = 4
		elif "_Axe" in current_weapon_suffix:
			state_name = "Attack_Axe_6f"; target_hframes = 6
		elif "_Pickaxe" in current_weapon_suffix:
			state_name = "Attack_Pickaxe_6f"; target_hframes = 6
		else:
			state_name = "Attack_Axe_6f"; target_hframes = 6

	elif velocity != Vector2.ZERO:
		state_name = "Run"
		file_prefix = "Run"
		target_hframes = 6
# ✨ 核心优化：利用布尔值和三元运算符，告别臃肿的 if/else
		var is_moving_left: bool = velocity.x < 0
		sprite.flip_h = is_moving_left
		
		# 安全判定后，左转 scale.x 为 -1，否则为 1
		if is_instance_valid(area_attack_node):
			area_attack_node.scale.x = -1.0 if is_moving_left else 1.0
	else:
		state_name = "Idle"
		file_prefix = "Idle"
		target_hframes = 8 
	
	if sprite.hframes != target_hframes:
		sprite.frame = 0 
		sprite.hframes = target_hframes

	if animation_player.has_animation(state_name):
		if animation_player.current_animation != state_name:
			animation_player.play(state_name)
			if "Attack" in state_name:
				animation_player.speed_scale = 2.0 
			else:
				animation_player.speed_scale = 1.0 
				
	var target_texture_path = texture_folder_path + "/Pawn_" + file_prefix + current_weapon_suffix + ".png"
	if not texture_cache.has(target_texture_path):
		if ResourceLoader.exists(target_texture_path):
			texture_cache[target_texture_path] = load(target_texture_path)
		else:
			return 
			
	var target_tex = texture_cache[target_texture_path]
	if sprite.texture != target_tex:
		sprite.texture = target_tex

# ==========================================
# ⚔️ 6. 攻击行为控制
# ==========================================
func _start_attack() -> void:
	is_attacking = true
	if attack_area_collision:
		attack_area_collision.disabled = false 
	if area_attack_node:
		_apply_attack_hits.call_deferred()
	match current_weapon_index:
		ToolType.HAMMER:
			_play_sfx(sfx_heavy)
		ToolType.KNIFE:
			_play_sfx(sfx_knife if sfx_knife else sfx_sharp)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if "Attack" in anim_name:
		is_attacking = false
		if attack_area_collision:
			attack_area_collision.disabled = true
		if auto_attack_active and is_instance_valid(auto_target):
			var distance = global_position.distance_to(auto_target.global_position)
			if distance <= attack_range and current_weapon_index != ToolType.HAND:
				_start_attack()

# ==========================================
# 💥 7. 伤害与物理碰撞 (强力鉴定系统)
# ==========================================
func _on_area_attack_body_entered(body: Node2D) -> void:
	_apply_attack_hit(body)

func _apply_attack_hits() -> void:
	if area_attack_node == null:
		return
	var bodies = area_attack_node.get_overlapping_bodies()
	for body in bodies:
		_apply_attack_hit(body as Node2D)

func _apply_attack_hit(body: Node2D) -> void:
	if body == null:
		return
	# 1. 快速过滤自己或地图层，避免误伤
	if body == self or body is TileMapLayer:
		return
	var sheep: Sheep = body as Sheep
	if is_instance_valid(sheep):
		if current_weapon_index == ToolType.KNIFE:
			sheep.take_damage(1)
			print("攻击命中: Sheep | 伤害=1 | Weapon=", current_weapon_index, " | SheepHP=", sheep.health)
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		if current_weapon_index == ToolType.KNIFE:
			body.take_damage(1)
			print("攻击命中: Enemy | 伤害=1 | Weapon=", current_weapon_index, " | Enemy=", body.name)
		return
		
	# ✨ 核心优化：多态转换。如果 body 不是 ObjectBase 的子类，这里会返回 null
	var interactable: ObjectBase = body as ObjectBase
	
	# 如果转换成功，说明它绝对是我们定义的互动物体 (树、矿石等)
	if is_instance_valid(interactable):
		var can_damage: bool = false
		
		# 提取并统一转化为小写，防止你在编辑器里手滑写成 "tree" 或 "Tree"
		var target_type: String = interactable.type.to_lower()
		
		# 2. 严谨的工具门禁匹配 (配合优化一的枚举)
		match current_weapon_index:
			ToolType.AXE:
				if target_type == "tree": can_damage = true
			ToolType.PICKAXE, ToolType.HAMMER:
				if target_type == "rock" or target_type == "gold": can_damage = true
			ToolType.KNIFE:
				if target_type == "enemy": can_damage = true # 为未来的敌人预留
				
		# 3. 结算伤害
		if can_damage:
			# 假设默认造成 1 点伤害。如果你的主角有攻击力变量，请替换为 attack_damage
			interactable.update_health(1) 
			if target_type == "tree":
				_play_sfx(sfx_wood)
			elif target_type == "rock" or target_type == "gold":
				_play_sfx(sfx_stone)
		else:
			print("【导师提示】工具不匹配！你拿着工具ID: ", current_weapon_index, " 敲不动 ", target_type)

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	if sprite:
		if hit_tween and hit_tween.is_running():
			hit_tween.kill()
		var base_scale = sprite.scale
		sprite.modulate = hit_flash_color
		hit_tween = create_tween()
		hit_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), hit_flash_time)
		hit_tween.parallel().tween_property(sprite, "scale", base_scale * 1.08, hit_flash_time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hit_tween.tween_property(sprite, "scale", base_scale, hit_flash_time * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hit_tween.tween_callback(func(): sprite.scale = base_scale)
		_spawn_hit_fx()
	print("主角受击 | 伤害=", amount, " | HP=", current_health, "/", max_health)
	get_tree().call_group("interface", "update_player_health", current_health, max_health)

func _spawn_hit_fx() -> void:
	if hit_fx_defs.is_empty():
		return
	var fx = hit_fx_defs.pick_random()
	var texture = fx["texture"]
	var frame_count = int(fx["frames"])
	_spawn_world_fx(texture, frame_count, global_position + Vector2(0, -10), Vector2(0.6, 0.6))

func _spawn_world_fx(texture: Texture2D, frame_count: int, position: Vector2, scale: Vector2) -> void:
	if texture == null or frame_count <= 0:
		return
	var sprite_fx = AnimatedSprite2D.new()
	sprite_fx.sprite_frames = _build_fx_frames(texture, frame_count, 12.0)
	sprite_fx.animation = "fx"
	sprite_fx.global_position = position
	sprite_fx.scale = scale
	sprite_fx.z_index = 15
	var root = get_tree().current_scene
	if root:
		root.add_child(sprite_fx)
	sprite_fx.play()
	if not sprite_fx.animation_finished.is_connected(sprite_fx.queue_free):
		sprite_fx.animation_finished.connect(sprite_fx.queue_free)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_fx, "scale", scale * 1.25, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
