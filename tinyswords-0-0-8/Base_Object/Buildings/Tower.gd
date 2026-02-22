extends StaticBody2D

@export var max_level: int = 10
@export var level: int = 1
@export var base_health: int = 150
@export var health_per_level: int = 60
@export var current_health: int = 150

@onready var slot_position: Node2D = $ArcherSlot

func _ready() -> void:
	_update_health_from_level()

func set_level(new_level: int) -> void:
	level = clamp(new_level, 1, max_level)
	_update_health_from_level()

func _update_health_from_level() -> void:
	current_health = base_health + (level - 1) * health_per_level

func get_archer_slot_global_position() -> Vector2:
	if slot_position:
		return slot_position.global_position
	return global_position

