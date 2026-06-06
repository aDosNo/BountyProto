extends Area3D

signal extraction_reached

@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var visual_root: Node3D = %VisualRoot

var is_active: bool = false


func _ready() -> void:
	add_to_group("extraction_zone")
	body_entered.connect(_on_body_entered)
	set_active(false)


func set_active(active: bool) -> void:
	is_active = active
	visible = active
	monitoring = active
	monitorable = active
	collision_shape.disabled = not active
	visual_root.visible = active


func _on_body_entered(body: Node) -> void:
	if not is_active:
		return

	if body.is_in_group("player"):
		print("Player reached extraction.")
		extraction_reached.emit()
