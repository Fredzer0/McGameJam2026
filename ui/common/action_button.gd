extends Button

func _ready() -> void:
	# Connect signals for interaction feedback
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	
	pivot_offset = size / 2

func _on_mouse_entered() -> void:
	pass

func _on_mouse_exited() -> void:
	pass

func _on_pressed() -> void:
	# Override this function on the specific instance
	pass
