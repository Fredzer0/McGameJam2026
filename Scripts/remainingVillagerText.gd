extends Label


var director

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = "Villager remaining: "
	director = get_tree().get_first_node_in_group("gameDirector");
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	text = "Villager remaining : " + str(director.currentVillagerCount)
	pass
