extends StaticBody2D

@export var max_level: int = 10
@export var level: int = 1
@export var base_health: int = 200
@export var health_per_level: int = 80
@export var current_health: int = 200

@onready var level_label: Label = $LevelLabel

func _ready() -> void:
	_update_health_from_level()
	_update_level_label()

func set_level(new_level: int) -> void:
	level = clamp(new_level, 1, max_level)
	_update_health_from_level()
	_update_level_label()

func _update_health_from_level() -> void:
	current_health = base_health + (level - 1) * health_per_level

func _update_level_label() -> void:
	if level_label:
		level_label.text = "Lv." + str(level)

