extends Control

@export var next_scene: String = "res://ui/menus/MainMenu3D.tscn"

@onready var anim: AnimationPlayer = $ColorRect/AnimationPlayer

var is_exiting := false

func _ready():
	$MarginContainer/HBoxContainer/VBoxContainer/QuitButton.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	if is_exiting:
		return

	is_exiting = true
	anim.play("fade_out")
	await anim.animation_finished
	get_tree().change_scene_to_file(next_scene)
