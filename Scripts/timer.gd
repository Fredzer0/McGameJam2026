extends Label


var director 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	director = get_tree().get_first_node_in_group("gameDirector");
	text = ""


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	if (director.remainingTime):
		text = format_time(director.remainingTime)

	
func format_time(seconds: float) -> String:
	var m = int(seconds) / 60
	var s = int(seconds) % 60
	return "%02d:%02d" % [m, s]
