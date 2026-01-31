extends Node3D

@onready var priest = $Priest
@onready var player = $Player

func _ready() -> void:
	if priest and player:
		priest.set_follow_target(player)
	pass