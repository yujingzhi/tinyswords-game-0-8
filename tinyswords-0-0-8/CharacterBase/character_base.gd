extends CharacterBody2D
class_name CharacterBase # 注册为全局基类，方便 Player 等子类继承

# ==========================================
# ⚙️ 1. 编辑器配置区域 (Exports)
# ==========================================
@export_category("Node References")
@export var sprite: Sprite2D = null           # 务必在检查器拖入 Sprite2D
@export var animation_player: AnimationPlayer = null # 务必在检查器拖入 AnimationPlayer

@export_category("Movement & Stats")
@export var move_speed: float = 200.0         # 移动速度
# 💡 引擎哲学：暴露资源路径，方便后续如果换了文件夹，不用改代码
@export_dir var texture_folder_path: String = "res://CharacterBase" 

@export_category("Audio SFX")
@export var sfx_wood: AudioStream             # 砍树交互音效
@export var sfx_stone: AudioStream            # 挖矿交互音效
@export var sfx_heavy: AudioStream            # 沉重武器切换音效 (锤子)
@export var sfx_sharp: AudioStream            # 清脆利器切换音效 (斧、镐、刀)
@export var sfx_hand: AudioStream             # 空手切换音效

# ==========================================
# 🔗 2. 内部节点与状态变量
# ==========================================
@onready var attack_area_collision: CollisionShape2D = $AreaAttack/CollisionShape2D
@onready var step_audio: AudioStreamPlayer = $StepAudio
@onready var fx_audio: AudioStreamPlayer = $FXAudio 

# --- ⚔️ 武器系统状态 ---
var current_weapon_index: int = -1 
var current_weapon_suffix: String = "" 
const MAX_WEAPON_COUNT: int = 4 

# --- 🏃‍♂️ 角色状态机 ---
var current_state: String = "Idle" # 可选状态: "Idle", "Run", "Attack"
var current_texture_path: String = "" # 性能优化：缓存当前图片路径，防止每帧重复加载

# ==========================================
# 🚀 3. 生命周期与输入中枢
# ==========================================
func _ready() -> void:
	# 游戏开始时，默认空手并刷新 UI
	_update_weapon_state()
	
	# ⚠️ 防错：确保一开始攻击判定框是关闭的
	if attack_area_collision:
		attack_area_collision.disabled = true

func _unhandled_input(event: InputEvent) -> void:
	# 只有在非攻击状态下，才允许切换武器
	if current_state == "Attack": return

	# 【按键切换】
	if event.is_action_pressed("weapon_1"): _toggle_weapon(0)
	elif event.is_action_pressed("weapon_2"): _toggle_weapon(1)
	elif event.is_action_pressed("weapon_3"): _toggle_weapon(2)
	elif event.is_action_pressed("weapon_4"): _toggle_weapon(3)
	
	# 【滚轮切换】
	elif event.is_action_pressed("scroll_up"): _cycle_weapon(1)
	elif event.is_action_pressed("scroll_down"): _cycle_weapon(-1)
	
	# 【攻击触发】(假设你绑定了鼠标左键为 attack)
	elif event.is_action_pressed("attack") and current_weapon_index != -1:
		_start_attack()

# ==========================================
# 🔄 4. 武器切换逻辑 (高内聚)
# ==========================================
func _toggle_weapon(target_index: int) -> void:
	if current_weapon_index == target_index:
		current_weapon_index = -1 # 收起武器
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
		-1: 
			current_weapon_suffix = ""
			_play_sfx(sfx_hand)
		0: 
			current_weapon_suffix = "_Hammer"
			_play_sfx(sfx_heavy)
		1: 
			current_weapon_suffix = "_Axe"
			_play_sfx(sfx_sharp)
		2: 
			current_weapon_suffix = "_Knife"
			_play_sfx(sfx_sharp)
		3: 
			current_weapon_suffix = "_Pickaxe"
			_play_sfx(sfx_sharp)
			
	# 武器改变后，立刻刷新一次画面表现
	_refresh_visuals()

func _play_sfx(stream: AudioStream) -> void:
	if fx_audio and stream:
		fx_audio.stream = stream
		fx_audio.play()

# ==========================================
# 🏃‍♂️ 5. 物理移动与状态判定
# ==========================================
func _physics_process(_delta: float) -> void:
	# 💡 极简状态机：如果正在攻击，禁止移动！
	if current_state == "Attack":
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	# 获取输入向量
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * move_speed
	move_and_slide()
	
	# 判定当前的运动状态
	if velocity.length() > 0:
		current_state = "Run"
		if sprite: sprite.flip_h = velocity.x < 0
	else:
		current_state = "Idle"
		
	# 每帧调用视觉刷新（内部有性能锁，不用担心掉帧）
	_refresh_visuals()

# ==========================================
# 🎨 6. 动态渲染引擎 (核心神识)
# ==========================================
func _refresh_visuals() -> void:
	if not sprite or not animation_player: return
	
	var file_prefix: String = "Idle"
	var anim_name: String = "Idle"
	var target_hframes: int = 8
	
	# 🟢 根据当前状态，推演对应的图片前缀、动画名和帧数
	if current_state == "Attack":
		file_prefix = "Interact" # Tiny Swords 的攻击图叫 Interact
		if "_Hammer" in current_weapon_suffix:
			anim_name = "Attack_Hammer_3f"; target_hframes = 3
		elif "_Knife" in current_weapon_suffix:
			anim_name = "Attack_Knife_4f"; target_hframes = 4
		elif "_Axe" in current_weapon_suffix:
			anim_name = "Attack_Axe_6f"; target_hframes = 6
		elif "_Pickaxe" in current_weapon_suffix:
			anim_name = "Attack_Pickaxe_6f"; target_hframes = 6
			
	elif current_state == "Run":
		file_prefix = "Run"
		anim_name = "Run"
		target_hframes = 6
		
	else: # Idle
		file_prefix = "Idle"
		anim_name = "Idle"
		target_hframes = 8 
	
	# 🌟 性能极简派：拼凑目标图片路径
	# 格式如：res://CharacterBase/Pawn_Run_Axe.png
	var target_texture_path = texture_folder_path + "/Pawn_" + file_prefix + current_weapon_suffix + ".png"
	
	# 🔒 性能锁：只有当需要更换的图片路径，和当前路径【不一样】时，才去读内存/硬盘！
	if current_texture_path != target_texture_path:
		if ResourceLoader.exists(target_texture_path):
			sprite.texture = load(target_texture_path)
			sprite.hframes = target_hframes
			sprite.frame = 0 # ⚠️ 致命防错：换图片必须归零帧，否则数组越界
			current_texture_path = target_texture_path
		else:
			printerr("❌ 渲染错误！找不到图片: ", target_texture_path)
			
	# 确保动画在播放正确的那一个
	if animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)

# ==========================================
# ⚔️ 7. 攻击行为控制
# ==========================================
func _start_attack() -> void:
	current_state = "Attack"
	if attack_area_collision:
		attack_area_collision.disabled = false # 开启伤害判定框
	_refresh_visuals()

# ⚠️ 必须连接 AnimationPlayer 的 animation_finished 信号到这个函数！
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if "Attack" in anim_name:
		current_state = "Idle" # 攻击结束，恢复站立状态
		if attack_area_collision:
			attack_area_collision.disabled = true # 关闭伤害判定框

# ==========================================
# 💥 8. 伤害与物理碰撞 (向外输出神识)
# ==========================================
func _on_area_attack_body_entered(body: Node2D) -> void:
	# 💡 极简派【鸭子类型 Duck Typing】哲学：
	# 我们不管碰到的是树、是石头还是敌人。
	# 只要这个物体身上有 `update_health` 这个函数，我们就认定它可以被伤害！
	if body.has_method("update_health"):
		
		# 假设基础伤害是 1 (以后可以根据手里拿的武器种类改成不同的伤害)
		var damage = 1 
		body.update_health(damage)
		
		# ✨ 进阶手感：播放砍中物体的反馈音效
		if "_Axe" in current_weapon_suffix or "_Hammer" in current_weapon_suffix:
			_play_sfx(sfx_wood) # 砍中木头的闷响
		elif "_Pickaxe" in current_weapon_suffix:
			_play_sfx(sfx_stone) # 敲击石头的清脆声
