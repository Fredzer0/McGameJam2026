extends Node3D

@onready var model_pivot: Node3D = $ModelPivot
@onready var left_arrow: Area3D = $LeftArrow
@onready var right_arrow: Area3D = $RightArrow

const SPAWN_ROTATION = Vector3(0, -15, 0)

func _ready() -> void:
	# Load initial model
	load_model(CharacterManager.get_current_model_path())
	
	# Connect to singleton signal
	CharacterManager.character_changed.connect(_on_character_changed)
	
	# Connect input signals
	left_arrow.input_event.connect(_on_left_arrow_input)
	right_arrow.input_event.connect(_on_right_arrow_input)

func _on_left_arrow_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		CharacterManager.previous_character()

func _on_right_arrow_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		CharacterManager.next_character()

func _on_character_changed(model_path: String) -> void:
	load_model(model_path)

func load_model(path: String) -> void:
	# Clear existing children
	for child in model_pivot.get_children():
		child.queue_free()
	
	# Load and instantiate new model
	var model_scene = load(path)
	if model_scene:
		var model_instance = model_scene.instantiate()
		model_pivot.add_child(model_instance)
		
		# Apply rotation
		model_instance.rotation_degrees = SPAWN_ROTATION
		
		# Setup animation
		var anim_player: AnimationPlayer = model_instance.find_child("AnimationPlayer", true, false)
		if not anim_player:
			anim_player = AnimationPlayer.new()
			model_instance.add_child(anim_player)
			anim_player.name = "AnimationPlayer"
			
		var idle_anim = load("res://animation/witch/animations/Idle.res")
		if idle_anim:
			idle_anim.loop_mode = Animation.LOOP_LINEAR
			var lib: AnimationLibrary
			if anim_player.has_animation_library(""):
				lib = anim_player.get_animation_library("")
			else:
				lib = AnimationLibrary.new()
				anim_player.add_animation_library("", lib)
			
			if not lib.has_animation("Idle"):
				lib.add_animation("Idle", idle_anim)
			
			anim_player.play("Idle")
	else:
		push_error("Failed to load model path: " + path)
