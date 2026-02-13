extends CharacterBody2D
class_name CharacterBase 

# ==========================================
# ⚙️ 1. 编辑器配置区域 (Exports)
# ==========================================
@export_category("Node References")
@export var sprite: Sprite2D = null           
@export var animation_player: AnimationPlayer = null 

@export_category("Movement & Stats")
@export var move_speed: float = 200.0         
@export_dir var texture_folder_path: String = "res://CharacterBase" 

@export_category("Audio SFX")
@export var sfx_wood: AudioStream             
@export var sfx_stone: AudioStream            
@export var sfx_heavy: AudioStream            
@export var sfx_sharp: AudioStream            
@export var sfx_hand: AudioStream             

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
		if velocity.x < 0: sprite.flip_h = true
		elif velocity.x > 0: sprite.flip_h = false
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
# 💥 7. 伤害与物理碰撞
# ==========================================
func _on_area_attack_body_entered(body: Node2D) -> void:
	if body is TileMapLayer or body.is_in_group("player") or body.name == "Player":
		return
		
	if body.has_method("update_health"):
		var damage = 1 
		body.update_health(damage)
		
		if "_Axe" in current_weapon_suffix or "_Hammer" in current_weapon_suffix:
			_play_sfx(sfx_wood) 
		elif "_Pickaxe" in current_weapon_suffix:
			_play_sfx(sfx_stone)
