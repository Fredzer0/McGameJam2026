extends Control

signal close_requested
signal quit_to_menu

@onready var fullscreen_btn = %FullscreenButton
@onready var back_btn = %BackButton
@onready var quit_btn = %QuitButton

func _ready() -> void:
	# Connect signals
	fullscreen_btn.pressed.connect(_on_fullscreen_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	quit_btn.pressed.connect(func(): quit_to_menu.emit())
	
	_update_labels()

func show_quit_button(should_show: bool) -> void:
	quit_btn.visible = should_show

func _update_labels() -> void:
	var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_btn.text = "FULLSCREEN: " + ("ON" if is_fs else "OFF")

func _on_fullscreen_pressed() -> void:
	var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	_update_labels()

func _on_back_pressed() -> void:
	close_requested.emit()
