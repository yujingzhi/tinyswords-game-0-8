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

@export_category("Audio SFX")
@export var sfx_wood: AudioStream             
@export var sfx_stone: AudioStream            
@export var sfx_heavy: AudioStream            
@export var sfx_sharp: AudioStream            
@export var sfx_hand: AudioStream             

# ✨ 优化：使用强类型的枚举来定义工具
enum ToolType { 
	HAND = -1, 
	SWORD = 0, 
	AXE = 1, 
	PICKAXE = 2, 
	HAMMER = 3 
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

# --- 🎵 行走音效时钟 ---
var step_timer: float = 0.0
const STEP_INTERVAL: float = 0.35 # 脚步声间隔(秒)，数值越小响得越快

# 💡 图片缓存字典
var texture_cache: Dictionary = {}

# ==========================================
# 🚀 3. 生命周期与输入中枢
# ==========================================
func _ready() -> void:
	# 🌟 强制给主角上户口，确保无论在哪个地图，掉落物都能认出你！
	add_to_group("player")
	add_to_group("peao")
	
	_update_weapon_state()
	if attack_area_collision:
		attack_area_collision.disabled = true
		
	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)

func _unhandled_input(event: InputEvent) -> void:
	if is_attacking: return

	if event.is_action_pressed("weapon_1"): _toggle_weapon(0)
	elif event.is_action_pressed("weapon_2"): _toggle_weapon(1)
	elif event.is_action_pressed("weapon_3"): _toggle_weapon(2)
	elif event.is_action_pressed("weapon_4"): _toggle_weapon(3)
	
	elif event.is_action_pressed("scroll_up"): _cycle_weapon(1)
	elif event.is_action_pressed("scroll_down"): _cycle_weapon(-1)
	
	elif event.is_action_pressed("attack") and current_weapon_index != -1:
		_start_attack()

# ==========================================
# 🔄 4. 武器切换逻辑
# ==========================================
func _toggle_weapon(target_index: int) -> void:
	if current_weapon_index == target_index:
		current_weapon_index = -1 
	else:
		current_weapon_index = target_index
	_update_weapon_state()

func _cycle_weapon(direction: int) -> void:
	current_weapon_index += direction
	if current_weapon_index >= MAX_WEAPON_COUNT:
		current_weapon_index = -1 
	elif current_weapon_index < -1:
		current_weapon_index = MAX_WEAPON_COUNT - 1 
	_update_weapon_state()

func _update_weapon_state() -> void:
	get_tree().call_group("interface", "update_weapon_indicator", current_weapon_index)
	
	match current_weapon_index:
		-1: current_weapon_suffix = ""; _play_sfx(sfx_hand)
		0: current_weapon_suffix = "_Hammer"; _play_sfx(sfx_heavy)
		1: current_weapon_suffix = "_Axe"; _play_sfx(sfx_sharp)
		2: current_weapon_suffix = "_Knife"; _play_sfx(sfx_sharp)
		3: current_weapon_suffix = "_Pickaxe"; _play_sfx(sfx_sharp)

func _play_sfx(stream: AudioStream) -> void:
	if fx_audio and stream:
		fx_audio.stream = stream
		fx_audio.play()

# ==========================================
# 🏃‍♂️ 5. 物理移动与渲染引擎
# ==========================================
func _physics_process(_delta: float) -> void:
	if is_attacking:
		velocity = Vector2.ZERO
	else:
		var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction != Vector2.ZERO:
			velocity = direction * move_speed
			
			# 🎵 播放极其精准的脚步声
			step_timer -= _delta
			if step_timer <= 0.0:
				if step_audio: step_audio.play()
				step_timer = STEP_INTERVAL # 重置时钟
		else:
			velocity = Vector2.ZERO
			step_timer = 0.0 # 停下时瞬间归零，保证下次一迈步就响
			
	move_and_slide()
	
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

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if "Attack" in anim_name:
		is_attacking = false
		if attack_area_collision:
			attack_area_collision.disabled = true

# ==========================================
# 🏃‍♂️ 7. 物理移动与渲染引擎
# ==========================================
func _character_base(_delta: float) -> void:
	if is_attacking:
		velocity = Vector2.ZERO
	else:
		var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction != Vector2.ZERO:
			velocity = direction * move_speed
			# 🎵 播放脚步声逻辑... (保留你原有的 step_audio 逻辑)
			step_timer -= _delta
			if step_timer <= 0.0:
				if step_audio: step_audio.play()
				step_timer = STEP_INTERVAL 
		else:
			velocity = Vector2.ZERO
			step_timer = 0.0 
			
	move_and_slide()
	
	# --- 🌟 解决攻击范围不转的世纪难题 ---
	var area_attack_node = get_node_or_null("AreaAttack") # 获取攻击范围的父节点
	
	var state_name = "Idle"
	var file_prefix = "Idle"
	var target_hframes = 8
	
	if is_attacking:
		file_prefix = "Interact"
		# ... (保留你原有的攻击动画状态判断)
	elif velocity != Vector2.ZERO:
		state_name = "Run"
		file_prefix = "Run"
		target_hframes = 6
		
		# 🌟 核心修复：不但要翻转图片，还要把攻击框翻转过去！
		if velocity.x < 0: 
			sprite.flip_h = true
			if area_attack_node: area_attack_node.scale.x = -1 # 攻击判定转到左边
		elif velocity.x > 0: 
			sprite.flip_h = false
			if area_attack_node: area_attack_node.scale.x = 1  # 攻击判定转回右边
	else:
		state_name = "Idle"
		file_prefix = "Idle"
		target_hframes = 8 
		
	# ... (保留你下方的换图缓存代码) ...

# ==========================================
# 💥 7. 伤害与物理碰撞 (强力鉴定系统)
# ==========================================
func _on_area_attack_body_entered(body: Node2D) -> void:
	# 1. 快速过滤自己或地图层，避免误伤
	if body == self or body is TileMapLayer:
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
			ToolType.SWORD:
				if target_type == "enemy": can_damage = true # 为未来的敌人预留
				
		# 3. 结算伤害
		if can_damage:
			# 假设默认造成 1 点伤害。如果你的主角有攻击力变量，请替换为 attack_damage
			interactable.update_health(1) 
			
			# (可选) 在这里根据工具播放你提前 @export 好的对应音效，比如 sfx_wood 或 sfx_stone
		else:
			print("【导师提示】工具不匹配！你拿着工具ID: ", current_weapon_index, " 敲不动 ", target_type)
