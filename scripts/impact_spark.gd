extends Node3D

@export var lifetime: float = 0.22
@export var start_scale: float = 0.22

@onready var spark_mesh: MeshInstance3D = %SparkMesh
@onready var spark_light: OmniLight3D = %SparkLight


func _ready() -> void:
	scale = Vector3.ONE * start_scale

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, lifetime)
	tween.tween_property(spark_light, "light_energy", 0.0, lifetime)
	tween.tween_property(spark_mesh, "transparency", 1.0, lifetime)
	tween.chain().tween_callback(queue_free)
