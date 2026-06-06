extends Node
class_name HealthComponent

signal damaged(amount: int, health: int)
signal died

@export var max_health: int = 100

var current_health: int


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	if current_health <= 0:
		return

	current_health = max(current_health - amount, 0)
	damaged.emit(amount, current_health)

	if current_health == 0:
		died.emit()
