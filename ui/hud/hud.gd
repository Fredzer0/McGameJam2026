extends CanvasLayer

@onready var task_container = %TaskContainer
@onready var tip_panel = %TipPanel
@onready var tip_label = %TipLabel
@onready var settings_menu = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect settings close signal
	settings_menu.close_requested.connect(_on_settings_closed)
	settings_menu.quit_to_menu.connect(_on_quit_to_menu)
	
	# Enable Quit Button for in-game settings
	settings_menu.show_quit_button(true)

	# Hide tip initially
	tip_panel.hide()

	await get_tree().create_timer(1.0).timeout
	show_tip("This is a tip!", 3.0)
	add_task("Transform all villagers into frogs!.")
	add_task("Press ESC for Settings")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_settings()

func toggle_settings() -> void:
	var is_open = settings_menu.visible
	if is_open:
		settings_menu.hide()
		get_tree().paused = false
	else:
		settings_menu.show()
		get_tree().paused = true

func _on_settings_closed() -> void:
	toggle_settings() # This will hide it and unpause

func _on_quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/menus/MainMenu3D.tscn")

func add_task(text: String) -> void:
	var label = Label.new()
	label.text = "- " + text
	task_container.add_child(label)

func clear_tasks() -> void:
	for child in task_container.get_children():
		child.queue_free()

func show_tip(text: String, duration: float = 3.0) -> void:
	tip_label.text = text
	tip_panel.show()
	tip_panel.modulate.a = 1.0 # Ensure visible
	
	await get_tree().create_timer(duration).timeout
	
	tip_panel.hide()
