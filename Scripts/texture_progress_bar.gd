extends TextureProgressBar


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	value = 0
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	value += 1


	if value == max_value:
		get_parent().get_parent().get_parent().queue_free()
	pass
