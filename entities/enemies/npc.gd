extends Node3D

signal panic_signal();
signal calm_signal();

var director: Node;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	panic_signal.connect(_on_area_3d_body_entered);
	calm_signal.connect(_on_area_3d_body_exited);
	

	director = get_tree().get_first_node_in_group("suspicionDirector");

	if (director):
		panic_signal.connect(director.on_npc_panic_signal);
		calm_signal.connect(director.on_npc_calm_signal);

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	pass





func _on_area_3d_body_exited(body: Node3D) -> void:
	if (body.is_in_group("player")):
		calm_signal.emit();
	pass # Replace with function body.


func _on_area_3d_body_entered(body: Node3D) -> void:
	if (body.is_in_group("player")):
		panic_signal.emit();	
	pass # Replace with function body.
