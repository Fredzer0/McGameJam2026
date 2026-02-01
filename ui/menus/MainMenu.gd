extends Control

@onready var settings_menu = $SettingsMenu
@onready var main_container = $MarginContainer
@onready var character_switcher: Control = $MarginContainer2/CharacterSwitcher

func _ready() -> void:
	# Connect Button Signals
	var menu_container = $MarginContainer/HBoxContainer/VBox
	
	menu_container.get_node("PlayButton").pressed.connect(_on_play_pressed)
	menu_container.get_node("OptionsButton").pressed.connect(_on_options_pressed)
	menu_container.get_node("QuitButton").pressed.connect(_on_quit_pressed)
	
	# Connect Settings Signal
	settings_menu.close_requested.connect(_on_settings_closed)

func _on_play_pressed() -> void:
	# Disable button to prevent double clicks
	$MarginContainer/HBoxContainer/VBox/PlayButton.disabled = true
	
	# Transition to level scene
	SceneLoader.load_scene("res://levels/gameLoop.tscn")

func _on_options_pressed() -> void:
	SceneLoader.load_scene("res://levels/HowToPlay.tscn")

func _on_settings_closed() -> void:
	settings_menu.hide()
	main_container.show()

func _on_quit_pressed() -> void:
	get_tree().quit()
