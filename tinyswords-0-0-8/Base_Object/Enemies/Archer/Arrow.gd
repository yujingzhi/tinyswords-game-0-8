extends Area2D

@export var speed: float = 260.0
@export var damage: int = 1
@export var life_time: float = 3.0

var direction: Vector2 = Vector2.RIGHT

func setup(dir: Vector2, new_speed: float, new_damage: int) -> void:
	direction = dir.normalized()
	speed = new_speed
	damage = new_damage

func _ready() -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("peao"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return
	if body is TileMapLayer:
		queue_free()
