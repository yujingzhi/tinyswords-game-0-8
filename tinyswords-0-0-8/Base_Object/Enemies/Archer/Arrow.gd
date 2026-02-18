extends Area2D
# 箭矢逻辑：直线飞行、检测碰撞、命中后销毁

@export var speed: float = 260.0
@export var damage: int = 1
@export var life_time: float = 3.0
# 可以在编辑器调整速度、伤害和存活时间

var direction: Vector2 = Vector2.RIGHT
# 飞行方向，默认向右

func setup(dir: Vector2, new_speed: float, new_damage: int) -> void:
	# 初始化箭矢参数，由发射者调用
	direction = dir.normalized()
	speed = new_speed
	damage = new_damage

func _ready() -> void:
	# 启用区域检测，并根据方向旋转
	monitoring = true
	monitorable = true
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	# 沿方向移动，并在生存时间结束后销毁
	global_position += direction * speed * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()
		return
	# 通过重叠检测命中玩家本体
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body and body.is_in_group("peao"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
				print("Arrow命中主角 | 伤害=", damage, " | ArrowPos=", global_position)
			queue_free()
			return
	# 通过碰撞盒命中玩家受击区域
	var areas = get_overlapping_areas()
	for area in areas:
		if area and area.is_in_group("player_hurtbox"):
			var player = area.get_parent()
			if player and player.has_method("take_damage"):
				player.take_damage(damage)
				print("Arrow命中Hurtbox | 伤害=", damage, " | ArrowPos=", global_position)
			queue_free()
			return

func _on_body_entered(body: Node) -> void:
	# 信号回调：与刚体/角色碰撞时触发
	if body == null:
		return
	if body.is_in_group("peao"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return
	if body is TileMapLayer:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# 信号回调：进入受击区域则造成伤害
	if area == null:
		return
	if area.is_in_group("player_hurtbox"):
		var player = area.get_parent()
		if player and player.has_method("take_damage"):
			player.take_damage(damage)
		queue_free()
