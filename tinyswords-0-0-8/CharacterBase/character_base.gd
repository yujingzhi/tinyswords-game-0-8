extends CharacterBody2D
class_name CharacterBase 
# 这个脚本作为玩家角色的基础类，负责移动、攻击、动画与受伤逻辑



# ==========================================
# ⚙️ 1. 编辑器配置区域 (Exports)
# ==========================================
@export_category("Node References")
@export var sprite: Sprite2D = null           
@export var animation_player: AnimationPlayer = null 
@onready var area_attack_node: Area2D = $AreaAttack
# AreaAttack 是一个检测攻击范围的 Area2D，用于获取被击中的物体
@export_category("Movement & Stats")
@export var move_speed: float = 200.0         
@export_dir var texture_folder_path: String = "res://CharacterBase" 
@export var max_health: int = 10
@export var max_stamina: int = 100
@export var stamina_drain_rate: float = 8.0
@export var stamina_regen_rate: float = 18.0
@export var hit_flash_color: Color = Color(1, 0.4, 0.4, 1)
@export var hit_flash_time: float = 0.12
# 以上属性都会在编辑器中显示，方便美术或策划直接调整数值

@export_category("Audio SFX")
@export var sfx_wood: AudioStream             
@export var sfx_stone: AudioStream            
@export var sfx_heavy: AudioStream            
@export var sfx_sharp: AudioStream            
@export var sfx_knife: AudioStream            
@export var sfx_hand: AudioStream             
# 不同工具或材质触发不同音效

# ✨ 优化：使用强类型的枚举来定义工具
enum ToolType { 
	HAND = -1, 
	HAMMER = 0, 
	AXE = 1, 
	KNIFE = 2, 
	PICKAXE = 3 
}
# 使用枚举可以避免魔法数字，阅读和维护更直观

# ==========================================
# 🔗 2. 内部节点与状态变量
# ==========================================
@onready var attack_area_collision: CollisionShape2D = $AreaAttack/CollisionShape2D
@onready var step_audio: AudioStreamPlayer = $StepAudio
@onready var fx_audio: AudioStreamPlayer = $FXAudio 
# onready 变量会在节点进入场景树后再赋值，确保节点存在

# --- ⚔️ 武器系统状态 ---
# 将原本的 int 替换为 ToolType
var current_weapon_index: ToolType = ToolType.HAND
var current_weapon_suffix: String = "" 
const MAX_WEAPON_COUNT: int = 4
# current_weapon_suffix 用于拼接贴图文件名

# --- 🏃‍♂️ 角色状态机 ---
var is_attacking: bool = false 
var current_health: int
var current_stamina: float
var hit_tween: Tween
var hit_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Explosion_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Explosion_02.png"), "frames": 10}
]
# hit_fx_defs 提供受击特效的贴图和帧数配置

# --- 🎵 行走音效时钟 ---
var step_timer: float = 0.0
const STEP_INTERVAL: float = 0.35 # 脚步声间隔(秒)，数值越小响得越快
# 通过计时器控制脚步声频率，防止播放过于密集

# 💡 图片缓存字典
var texture_cache: Dictionary = {}
var last_move_dir: Vector2 = Vector2.ZERO
var attack_range: float = 40.0
# texture_cache 用于缓存加载过的贴图，减少重复加载

# ==========================================
# 🚀 3. 生命周期与输入中枢
# ==========================================
func _ready() -> void:
	# 场景加载完成后初始化角色数据
	add_to_group("player")
	add_to_group("peao")
	current_health = max_health
	current_stamina = float(max_stamina)
	# 通知 UI 刷新血量和体力显示
	get_tree().call_group("interface", "update_player_health", current_health, max_health)
	get_tree().call_group("interface", "update_player_stamina", int(round(current_stamina)), max_stamina)
	
	_update_weapon_state()
	if attack_area_collision:
		attack_area_collision.disabled = true
		# 初始时禁用攻击碰撞，只有攻击时才开启
		
	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	# 读取攻击范围的碰撞半径，便于后续判断
	if attack_area_collision and attack_area_collision.shape is CircleShape2D:
		attack_range = (attack_area_collision.shape as CircleShape2D).radius + 6.0

func _unhandled_input(event: InputEvent) -> void:
	# 攻击时不允许切换武器或再次攻击
	if is_attacking:
		return

	if event.is_action_pressed("weapon_1"): _toggle_weapon(0)
	elif event.is_action_pressed("weapon_2"): _toggle_weapon(1)
	elif event.is_action_pressed("weapon_3"): _toggle_weapon(2)
	elif event.is_action_pressed("weapon_4"): _toggle_weapon(3)
	# 也支持滚轮切换武器
	
	elif event.is_action_pressed("scroll_up"): _cycle_weapon(1)
	elif event.is_action_pressed("scroll_down"): _cycle_weapon(-1)
	
	elif event.is_action_pressed("attack") and current_weapon_index != ToolType.HAND and not (event is InputEventMouseButton):
		# 只在有工具时触发攻击，避免空手动画
		_start_attack()

# ==========================================
# 🔄 4. 武器切换逻辑
# ==========================================
func _toggle_weapon(target_index: int) -> void:
	# 按同一个编号时取消装备，相当于收起工具
	var target_tool = target_index as ToolType
	if current_weapon_index == target_tool:
		current_weapon_index = ToolType.HAND
	else:
		current_weapon_index = target_tool
	_update_weapon_state()

func _cycle_weapon(direction: int) -> void:
	# 通过滚轮上下切换工具，并做循环边界处理
	var next_index = int(current_weapon_index) + direction
	if next_index >= MAX_WEAPON_COUNT:
		next_index = int(ToolType.HAND)
	elif next_index < int(ToolType.HAND):
		next_index = MAX_WEAPON_COUNT - 1
	current_weapon_index = next_index as ToolType
	_update_weapon_state()

func _update_weapon_state() -> void:
	# UI 展示当前工具
	get_tree().call_group("interface", "update_weapon_indicator", current_weapon_index)
	# 根据工具类型切换贴图后缀并播放装备音效
	match current_weapon_index:
		ToolType.HAND: current_weapon_suffix = ""; _play_sfx(sfx_hand)
		ToolType.HAMMER: current_weapon_suffix = "_Hammer"; _play_sfx(sfx_heavy)
		ToolType.AXE: current_weapon_suffix = "_Axe"; _play_sfx(sfx_sharp)
		ToolType.KNIFE: current_weapon_suffix = "_Knife"; _play_sfx(sfx_knife if sfx_knife else sfx_sharp)
		ToolType.PICKAXE: current_weapon_suffix = "_Pickaxe"; _play_sfx(sfx_sharp)

func _play_sfx(stream: AudioStream) -> void:
	# 统一的音效播放入口，避免重复写判断
	if fx_audio and stream:
		fx_audio.stream = stream
		fx_audio.play()

func _equip_tool(tool: ToolType) -> void:
	# 外部脚本可直接调用，强制装备某个工具
	if current_weapon_index == tool:
		return
	current_weapon_index = tool
	_update_weapon_state()

func _apply_move_direction(direction: Vector2, delta: float) -> void:
	# 根据输入方向更新速度，并处理体力消耗/恢复
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
	# 物理帧更新：处理移动、动画、贴图切换和体力显示
	var stamina_before = int(round(current_stamina))
	var prev_position = global_position
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_attacking:
		velocity = Vector2.ZERO
	else:
		_apply_move_direction(input_direction, _delta)
			
	move_and_slide()
	# 计算上一帧到这一帧的移动距离，用于记录朝向
	var moved_distance = global_position.distance_to(prev_position)
	if moved_distance >= 0.5:
		last_move_dir = (global_position - prev_position).normalized()
	# 体力有变化时才刷新 UI，避免每帧刷新
	var stamina_now = int(round(current_stamina))
	if stamina_now != stamina_before:
		get_tree().call_group("interface", "update_player_stamina", stamina_now, max_stamina)
	# 速度接近 0 时清零，减少抖动
	if velocity.length() < 1.0:
		velocity = Vector2.ZERO
	
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
		var is_moving_left: bool = sprite.flip_h
		if last_move_dir != Vector2.ZERO:
			is_moving_left = last_move_dir.x < 0
		sprite.flip_h = is_moving_left
		
		# 安全判定后，左转 scale.x 为 -1，否则为 1
		if is_instance_valid(area_attack_node):
			# 攻击范围也需要跟随朝向翻转
			area_attack_node.scale.x = -1.0 if is_moving_left else 1.0
	else:
		state_name = "Idle"
		file_prefix = "Idle"
		target_hframes = 8 
	
	if sprite.hframes != target_hframes:
		# 切换帧数时重置到第一帧，避免动画跳帧
		sprite.frame = 0 
		sprite.hframes = target_hframes

	if animation_player.has_animation(state_name):
		if animation_player.current_animation != state_name:
			animation_player.play(state_name)
			# 攻击动画加速播放
			if "Attack" in state_name:
				animation_player.speed_scale = 2.0 
			else:
				animation_player.speed_scale = 1.0 
				
	var target_texture_path = texture_folder_path + "/Pawn_" + file_prefix + current_weapon_suffix + ".png"
	# 首次使用某张贴图时才加载，并缓存起来
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
	# 启动攻击：打开碰撞并计算命中目标
	is_attacking = true
	if attack_area_collision:
		attack_area_collision.disabled = false 
	if area_attack_node:
		_apply_attack_hits.call_deferred()
	# 根据工具播放更贴合的挥击音效
	match current_weapon_index:
		ToolType.HAMMER:
			_play_sfx(sfx_heavy)
		ToolType.KNIFE:
			_play_sfx(sfx_knife if sfx_knife else sfx_sharp)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	# 攻击动画结束后关闭碰撞，恢复可移动状态
	if "Attack" in anim_name:
		is_attacking = false
		if attack_area_collision:
			attack_area_collision.disabled = true

# ==========================================
# 💥 7. 伤害与物理碰撞 (强力鉴定系统)
# ==========================================
func _on_area_attack_body_entered(body: Node2D) -> void:
	# 有物体进入攻击范围就尝试计算伤害
	_apply_attack_hit(body)

func _apply_attack_hits() -> void:
	# 攻击开始时主动扫描范围内所有物体
	if area_attack_node == null:
		return
	var bodies = area_attack_node.get_overlapping_bodies()
	for body in bodies:
		_apply_attack_hit(body as Node2D)

func _apply_attack_hit(body: Node2D) -> void:
	# 对单个目标判定伤害
	if body == null:
		return
	# 1. 快速过滤自己或地图层，避免误伤
	if body == self or body is TileMapLayer:
		return
	# 优先处理动物
	var sheep: Sheep = body as Sheep
	if is_instance_valid(sheep):
		if current_weapon_index == ToolType.KNIFE:
			sheep.take_damage(1)
			print("攻击命中: Sheep | 伤害=1 | Weapon=", current_weapon_index, " | SheepHP=", sheep.health)
		return
	# 再处理敌人组
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
	# 受伤处理：扣血、播放闪烁和缩放特效
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
	# 随机选择一个受击特效播放
	if hit_fx_defs.is_empty():
		return
	var fx = hit_fx_defs.pick_random()
	var texture = fx["texture"]
	var frame_count = int(fx["frames"])
	_spawn_world_fx(texture, frame_count, global_position + Vector2(0, -10), Vector2(0.6, 0.6))

func _spawn_world_fx(texture: Texture2D, frame_count: int, fx_position: Vector2, fx_scale: Vector2) -> void:
	# 在世界中生成一次性特效并自动销毁
	if texture == null or frame_count <= 0:
		return
	var sprite_fx = AnimatedSprite2D.new()
	sprite_fx.sprite_frames = _build_fx_frames(texture, frame_count, 12.0)
	sprite_fx.animation = "fx"
	sprite_fx.global_position = fx_position
	sprite_fx.scale = fx_scale
	sprite_fx.z_index = 15
	var root = get_tree().current_scene
	if root:
		root.add_child(sprite_fx)
	sprite_fx.play()
	if not sprite_fx.animation_finished.is_connected(sprite_fx.queue_free):
		sprite_fx.animation_finished.connect(sprite_fx.queue_free)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_fx, "scale", fx_scale * 1.25, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite_fx, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(sprite_fx.queue_free)

func _build_fx_frames(texture: Texture2D, frame_count: int, fps: float) -> SpriteFrames:
	# 将一张精灵表切分成多帧动画
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
