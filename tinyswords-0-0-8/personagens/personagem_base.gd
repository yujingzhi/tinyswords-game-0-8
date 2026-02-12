extends CharacterBody2D
class_name PersonagemBase

# ==========================================
# --- 1. 变量定义与编辑器配置 (Exports) ---
# ==========================================

@export_category("Objetos")
@export var _textura: Sprite2D = null         # 引用主角的精灵节点
@export var _animador: AnimationPlayer = null # 引用动画播放器

@export_category("Movimento")
@export var move_speed: float = 200.0         # 移动速度
@export_dir var texture_folder_path: String = "res://personagens" # 图片资源文件夹路径

@export_category("Audio SFX")
@export var sfx_wood: AudioStream             # 砍树时的受击音效
@export var sfx_stone: AudioStream            # 挖矿时的受击音效

@export_group("Audio Switch")
# 这里存放切换武器时的反馈音效，建议使用 AudioStreamRandomizer (随机包)
@export var sfx_heavy: AudioStream # 沉重武器音效 (对应 锤子)
@export var sfx_sharp: AudioStream # 清脆利器音效 (对应 斧头、镐子、小刀)
@export var sfx_hand: AudioStream  # 收起武器音效 (对应 空手)

# ==========================================
# --- 2. 节点引用与内部变量 ---
# ==========================================

@onready var attack_area_collision: CollisionShape2D = $AreaAttack/CollisionShape2D
@onready var step_audio: AudioStreamPlayer = $StepAudio
@onready var fx_audio: AudioStreamPlayer = $FXAudio # 专门播放交互音效的节点

# 武器系统核心数据
# 顺序必须与 UI 快捷栏一致：0:空手, 1:锤子, 2:斧头, 3:小刀, 4:镐子
var weapon_suffixes: Array = ["", "_Hammer", "_Axe", "_Knife", "_Pickaxe"]
var current_weapon_index: int = 0             # 当前选中的武器索引
var current_weapon_suffix: String = ""        # 当前选中的武器后缀 (如 "_Axe")
var is_attacking: bool = false                # 状态锁：攻击时禁止移动和切换

# 步频控制
var footstep_interval: float = 0.3            # 脚步声间隔时间
var footstep_timer: float = 0.0               # 脚步声计时器

# ==========================================
# --- 3. 生命周期与物理循环 ---
# ==========================================

func _ready() -> void:
	# 监听动画完成信号，以便在攻击动画结束时解锁状态
	if _animador:
		_animador.animation_finished.connect(_on_animation_finished)
	
func _physics_process(delta: float) -> void:
	# 检测攻击输入
	if Input.is_action_just_pressed("attack"):
		attack()

	# 移动逻辑：攻击时速度归零
	if is_attacking:
		velocity = Vector2.ZERO
	else:
		# 获取输入向量 (上下左右)
		var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction != Vector2.ZERO:
			velocity = direction * move_speed
		else:
			velocity = Vector2.ZERO

	move_and_slide() # 执行物理移动
	_handle_footstep_audio(delta) # 处理脚步声
	_update_animation_state()    # 更新动画和皮肤

	# 处理攻击范围的左右翻转 (基于主角精灵的朝向)
	if _textura.flip_h: 
		attack_area_collision.position.x = -80
	else: 
		attack_area_collision.position.x = 80
		
	# 确保攻击 Area 不受父级缩放影响
	if $AreaAttack:
		$AreaAttack.scale = Vector2(1, 1)

# ==========================================
# --- 4. 武器切换核心逻辑 ---
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	# 如果正在攻击，锁死输入，防止快速切武器导致动画崩坏
	if is_attacking: return
		
	var changed: bool = false
	var size = weapon_suffixes.size()
	
	# --- A. 鼠标滚轮逻辑 ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_weapon_index = (current_weapon_index - 1 + size) % size
			changed = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_weapon_index = (current_weapon_index + 1) % size
			changed = true

	# --- B. 数字快捷键逻辑 (1, 2, 3, 4) ---
	var target_index: int = -1
	# 检查 Input Map 中定义的动作
	if Input.is_action_just_pressed("weapon_1"): target_index = 1
	elif Input.is_action_just_pressed("weapon_2"): target_index = 2
	elif Input.is_action_just_pressed("weapon_3"): target_index = 3
	elif Input.is_action_just_pressed("weapon_4"): target_index = 4
	
	if target_index != -1:
		# ✨ Toggle逻辑：如果当前已经是该武器，再次按下则收回(变为0：空手)
		if current_weapon_index == target_index:
			current_weapon_index = 0
		else:
			current_weapon_index = target_index
		changed = true

	# --- C. 统一应用变换 ---
	if changed:
		_apply_weapon_change()

func _apply_weapon_change() -> void:
	# 更新当前武器后缀
	current_weapon_suffix = weapon_suffixes[current_weapon_index]
	
	# 控制台打印调试信息
	print("切换武器: ", current_weapon_suffix if current_weapon_suffix != "" else "空手") 
	
	# 刷新动画播放器和贴图
	_update_animation_state()
	
	# 播放对应材质的物理切换音效
	match current_weapon_suffix:
		"_Hammer":
			_play_sfx(sfx_heavy)     # 沉重金属感
		"_Axe", "_Pickaxe", "_Knife":
			_play_sfx(sfx_sharp)     # 清脆锐利感
		"": 
			_play_sfx(sfx_hand)      # 皮革或布料摩擦感
	
	# 通知全局 UI 组：更新选中的武器高亮框
	get_tree().call_group("interface", "update_weapon_indicator", current_weapon_index)

# ==========================================
# --- 5. 音效与动画辅助函数 ---
# ==========================================

func _play_sfx(stream: AudioStream) -> void:
	# 通用音效播放器，自动加入随机音调变化让声音更自然
	if fx_audio and stream:
		fx_audio.stream = stream
		fx_audio.pitch_scale = randf_range(0.9, 1.1)
		fx_audio.play()

func _handle_footstep_audio(delta: float) -> void:
	# 基于移动速度和时间计时的脚步声逻辑
	if not step_audio: return
	if velocity.length() > 0:
		footstep_timer -= delta
		if footstep_timer <= 0:
			footstep_timer = footstep_interval 
			step_audio.pitch_scale = randf_range(0.9, 1.1)
			step_audio.play()
	else:
		footstep_timer = 0 # 停下时重置，确保下次起步立即有声音

# ==========================================
# --- 6. 战斗与交互逻辑 ---
# ==========================================

func attack() -> void:
	# 空手状态不允许攻击
	if current_weapon_suffix == "":
		return
	is_attacking = true
	_update_animation_state()

func _on_animation_finished(anim_name: String) -> void:
	# 当任何以 "Attack" 开头的动画结束时，释放攻击锁
	if anim_name.begins_with("Attack"):
		is_attacking = false
		_update_animation_state()

func _on_area_attack_body_entered(body: Node2D) -> void:
	# 排除掉自己、其他玩家或者地形层，防止误伤
	if body is TileMapLayer or body.is_in_group("player") or body.is_in_group("peao"):
		return

	# 检测目标是否有 update_health 方法 (即是否为可破坏物体)
	if body.has_method("update_health"):
		var obj_type = ""
		if "type" in body:
			obj_type = body.type.to_lower()
		var damage = 1 
		
		# 匹配资源采集逻辑
		if obj_type == "tree":
			if "_Axe" in current_weapon_suffix:
				body.update_health(damage)
				_play_sfx(sfx_wood)
			else:
				print("无法采集：你需要一把斧头！")
		elif obj_type == "rock" or obj_type == "gold":
			if "_Pickaxe" in current_weapon_suffix:
				body.update_health(damage)
				_play_sfx(sfx_stone)
			else:
				print("无法采集：你需要一把镐子！")

# ==========================================
# --- 7. 动画状态机 (核心) ---
# ==========================================

func _update_animation_state() -> void:
	if _textura == null or _animador == null: return

	var state_name = ""       # 动画名
	var file_prefix = ""      # 贴图前缀
	var target_hframes = 6    # 贴图水平帧数
	
	# 状态优先级判断
	if is_attacking:
		file_prefix = "Interact" 
		# 这里需要根据武器类型，手动匹配你在动画播放器里创建的名称和帧数
		if "_Hammer" in current_weapon_suffix:
			state_name = "Attack_Hammer_3f" 
			target_hframes = 3
		elif "_Knife" in current_weapon_suffix:
			state_name = "Attack_Knife_4f" 
			target_hframes = 4
		elif "_Axe" in current_weapon_suffix:
			state_name = "Attack_Axe_6f" 
			target_hframes = 6
		elif "_Pickaxe" in current_weapon_suffix:
			state_name = "Attack_Pickaxe_6f"       
			target_hframes = 6
		else:
			state_name = "Attack_Axe_6f"
			target_hframes = 6

	elif velocity != Vector2.ZERO:
		state_name = "Run"
		file_prefix = "Run"
		target_hframes = 6
		# 左右转向处理
		if velocity.x < 0: _textura.flip_h = true
		elif velocity.x > 0: _textura.flip_h = false
	else:
		state_name = "Idle"
		file_prefix = "Idle"
		target_hframes = 8 
	
	# 如果帧数变化了，重置当前帧，防止贴图错位
	if _textura.hframes != target_hframes:
		_textura.frame = 0 
		_textura.hframes = target_hframes

	# 播放动画
	if _animador.has_animation(state_name):
		if _animador.current_animation != state_name:
			_animador.play(state_name)
			# 动态加速攻击动画，让打击感更爽快
			if "Attack" in state_name:
				_animador.speed_scale = 2.0 
			else:
				_animador.speed_scale = 1.0 

	# 拼接文件路径 (规则：Pawn_动作_武器后缀.png)
	var file_name = "Pawn_" + file_prefix + current_weapon_suffix + ".png"
	var full_path = texture_folder_path.path_join(file_name)
	
	# 只有当路径变化时才加载新贴图，节省性能
	if _textura.texture == null or _textura.texture.resource_path != full_path:
		if FileAccess.file_exists(full_path):
			_textura.texture = load(full_path)
