extends Camera3D

var player
# Map limits (world coordinates)
@export var min_x := -40.0
@export var max_x := 40.0
@export var min_z := -30.0
@export var max_z := 30.0

var offset: Vector3

func _ready():

    player = get_tree().get_first_node_in_group("player")
    offset = global_position - player.global_position

func _process(delta):
    if not player:
        return

    var target_pos = player.global_position + offset

    target_pos.x = clamp(target_pos.x, min_x, max_x)
    target_pos.z = clamp(target_pos.z, min_z, max_z)

    global_position = target_pos