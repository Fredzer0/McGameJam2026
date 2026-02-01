extends TextureButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(_on_pressed)

	pivot_offset = size / 2



func _on_pressed():
	get_tree().change_scene_to_file("res://ui/menus/MainMenu3D.tscn")
