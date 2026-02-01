extends Node3D

@export var auto_fill: bool = true

@onready var bar = $Sprite3D/SubViewport/TextureProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	bar.value = 0
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if auto_fill:
		bar.value += 1


	if bar.value == bar.max_value:
		queue_free()
	pass
