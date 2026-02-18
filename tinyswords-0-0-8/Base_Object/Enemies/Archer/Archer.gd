extends CharacterBody2D
# 弓箭手敌人：巡逻、寻找玩家、发射箭矢

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
@export var hit_flash_color: Color = Color(1, 0.4, 0.4, 1)
@export var hit_flash_time: float = 0.12
# 上面是可在编辑器中调参的内容：血量、巡逻范围、动画和射击配置

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: TextureProgressBar = $HealthBar/Fill
# health_bar 用于显示敌人的血量

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
var hit_tween: Tween
var hit_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Explosion_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Explosion_02.png"), "frames": 10}
]
# hit_fx_defs 定义受击时的爆炸特效

func _ready() -> void:
	# 初始化敌人，加入敌人分组并设置血量
	add_to_group("enemy")
	current_health = max_health
	_update_health_bar()
	home_position = global_position
	_build_animations()
	_enter_idle()

func _physics_process(delta: float) -> void:
	# 处理射击冷却与巡逻逻辑
	shoot_timer -= delta
	if anim_timer > 0.0:
		anim_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if anim_timer <= 0.0:
			_enter_idle()
		return
	# 查找玩家，进入攻击距离就射击
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
	# 受击后扣血并播放闪烁效果
	current_health = max(current_health - amount, 0)
	_update_health_bar()
	if anim:
		if hit_tween and hit_tween.is_running():
			hit_tween.kill()
		var base_scale = anim.scale
		anim.modulate = hit_flash_color
		hit_tween = create_tween()
		hit_tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), hit_flash_time)
		hit_tween.parallel().tween_property(anim, "scale", base_scale * 1.08, hit_flash_time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hit_tween.tween_property(anim, "scale", base_scale, hit_flash_time * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hit_tween.tween_callback(func(): anim.scale = base_scale)
		_spawn_hit_fx()
	print("Archer受击 | 伤害=", amount, " | HP=", current_health, "/", max_health)
	if current_health <= 0:
		queue_free()

func _spawn_hit_fx() -> void:
	# 随机选择受击特效
	if hit_fx_defs.is_empty():
		return
	var fx = hit_fx_defs.pick_random()
	var texture = fx["texture"]
	var frame_count = int(fx["frames"])
	_spawn_world_fx(texture, frame_count, global_position + Vector2(0, -10), Vector2(0.6, 0.6))

func _spawn_world_fx(texture: Texture2D, frame_count: int, fx_position: Vector2, fx_scale: Vector2) -> void:
	# 在世界中播放一次性特效
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
	# 将贴图切成多帧动画
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

func _shoot(target_global_position: Vector2) -> void:
	# 发射箭矢：进入射击动画并生成箭
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
	# 根据贴图构建 idle/move/shoot 三套动画
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
	# 将一张横向帧贴图切成动画
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
	# 更新血条的最大值和当前值
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func _enter_idle() -> void:
	# 进入待机状态
	state = "idle"
	state_timer = randf_range(idle_time_range.x, idle_time_range.y)
	if anim:
		anim.play("idle")

func _enter_move() -> void:
	# 进入移动状态，选择随机目标点
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
	# 设定巡逻使用的瓦片层与范围
	roam_layer = layer
	home_cell = cell
	home_position = roam_layer.map_to_local(home_cell)
	roam_cells = _collect_cells_in_radius(roam_layer.get_used_cells(), home_cell, radius_cells)

func _collect_cells_in_radius(cells: Array[Vector2i], center: Vector2i, radius_cells: int) -> Array[Vector2i]:
	# 过滤出半径内的瓦片坐标
	var result: Array[Vector2i] = []
	var center_vec = Vector2(center)
	for c in cells:
		if (Vector2(c) - center_vec).length() <= radius_cells:
			result.append(c)
	return result
