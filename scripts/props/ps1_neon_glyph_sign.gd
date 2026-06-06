extends Node3D

@export var pulse_speed: float = 2.0
@export var pulse_amount: float = 0.25

@onready var glyph_label: Label3D = %GlyphLabel

var _base_modulate: Color


func _ready() -> void:
	_base_modulate = glyph_label.modulate


func _process(_delta: float) -> void:
	var pulse := 1.0 + (sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * pulse_amount)
	glyph_label.modulate = Color(_base_modulate.r * pulse, _base_modulate.g * pulse, _base_modulate.b * pulse, 1.0)
