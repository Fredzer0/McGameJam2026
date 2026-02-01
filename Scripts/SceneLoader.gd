extends Node

signal scene_loaded

@onready var loading_screen_path = "res://ui/menus/LoadingScreen.tscn"
var _target_scene_path: String
var _loading_screen_instance: Node

func load_scene(target_scene_path: String) -> void:
	_target_scene_path = target_scene_path
	
	# Instantiate loading screen
	var loading_screen_res = load(loading_screen_path)
	if loading_screen_res:
		_loading_screen_instance = loading_screen_res.instantiate()
		get_tree().root.add_child(_loading_screen_instance)
	
	# Start threaded loading
	ResourceLoader.load_threaded_request(_target_scene_path)
	
	# Start checking loop
	set_process(true)

func _process(_delta: float) -> void:
	if _target_scene_path == "":
		set_process(false)
		return
		
	var status = ResourceLoader.load_threaded_get_status(_target_scene_path)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		_complete_loading()
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status == ResourceLoader.THREAD_LOAD_FAILED:
		set_process(false)
		printerr("Failed to load scene: " + _target_scene_path)
		if _loading_screen_instance:
			_loading_screen_instance.queue_free()

func _complete_loading() -> void:
	var new_scene_resource = ResourceLoader.load_threaded_get(_target_scene_path)
	
	# Change scene to the new resource
	get_tree().change_scene_to_packed(new_scene_resource)
	
	# Cleanup loading screen after a small delay to ensure the new scene is ready
	# Or strict cleanup now
	if _loading_screen_instance:
		_loading_screen_instance.queue_free()
		
	_target_scene_path = ""
	emit_signal("scene_loaded")
