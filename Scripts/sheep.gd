extends Node3D

@onready var animPlayer = find_child("AnimationPlayer", true, false)
# Called when the node enters the scene tree for the first time.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	animPlayer.play("SheepAnimationPlayer/idleSheep")
