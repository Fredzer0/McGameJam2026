extends CharacterBody3D

signal panic_signal();
signal calm_signal();

var director: Node;

const SPEED = 5.0
const MIN_MOVE_RANGE = 6
const MAX_MOVE_RANGE = 10

enum State {IDLE, WATING_TO_MOVE, MOVE}
var state: State = State.IDLE

var idle_wait_time: float = 1.5
var idle_timer_count: float = 0

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D


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
	
func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta;

	match state:
		State.IDLE:
			_on_idle()
		State.WATING_TO_MOVE:
			_on_wating_to_move(delta)
		State.MOVE:
			_on_move()
			
	move_and_slide()


func _on_idle() -> void:
	velocity = Vector3.ZERO;
	idle_timer_count = idle_wait_time;
	state = State.WATING_TO_MOVE;

func _on_wating_to_move(delta: float) -> void:
	idle_timer_count -= delta;
	if (idle_timer_count <= 0.0):
		var target = get_new_target_position();
		var nav_map = navigation_agent_3d.get_navigation_map();
		var safe_target = NavigationServer3D.map_get_closest_point(nav_map, target);
		navigation_agent_3d.target_position = safe_target;
		state = State.MOVE;

func get_new_target_position() -> Vector3:
	var offset_x = randf_range(MIN_MOVE_RANGE, MAX_MOVE_RANGE) * (-1 if randf() < 0.5 else 1);
	var offset_z = randf_range(MIN_MOVE_RANGE, MAX_MOVE_RANGE) * (-1 if randf() < 0.5 else 1);
	return global_transform.origin + Vector3(offset_x, 0, offset_z);

func _on_move() -> void:
	var current_position = global_transform.origin;
	var next_position = navigation_agent_3d.get_next_path_position();
	var direction = (next_position - current_position).normalized();
	var new_velocity = direction * SPEED;
	navigation_agent_3d.set_velocity(new_velocity);


func _on_area_3d_body_exited(body: Node3D) -> void:
	if (body.is_in_group("player")):
		calm_signal.emit();
	pass # Replace with function body.


func _on_area_3d_body_entered(body: Node3D) -> void:
	if (body.is_in_group("player")):
		panic_signal.emit();
	pass # Replace with function body.


func _on_navigation_agent_3d_target_reached() -> void:
	state = State.IDLE;


func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity;
