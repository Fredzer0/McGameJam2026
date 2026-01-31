extends ProgressBar

var suspicionDirector;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	suspicionDirector = get_tree().get_first_node_in_group("suspicionDirector");
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	value = suspicionDirector.currentPanic;
	pass
