extends CharacterBody3D

signal panic_signal(position);
signal calm_signal();

var director: Node;

const SPEED = 3.0
const ROTATION_SPEED = 14.0
const MIN_MOVE_RANGE = 6
const MAX_MOVE_RANGE = 10

const MIN_DETECT_RADIUS = 1.0
const MAX_DETECT_RADIUS = 6.0
const MIN_LIGHT_ENERGY = 3.0
const MAX_LIGHT_ENERGY = 10.0
const MIN_LIGHT_RANGE = 2.0
const MAX_LIGHT_RANGE = 6.0

enum State {IDLE, WATING_TO_MOVE, MOVE, INVESTIGATE}
var state: State = State.IDLE

var idle_wait_time: float = 1.5
var idle_timer_count: float = 0
@onready var collision_shape_3d: CollisionShape3D = $detectplayer/CollisionShape3D
@onready var spot_light_3d: SpotLight3D = $Area3D/SpotLight3D


@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animPlayer = find_child("AnimationPlayer", true, false)

func _ready() -> void:
	# Removed bad self-connections
	director = get_tree().get_first_node_in_group("suspicionDirector");

	if (director):
		panic_signal.connect(director.on_npc_panic_signal);
		calm_signal.connect(director.on_npc_calm_signal);

	add_to_group("priest")

func _process(_delta: float) -> void:
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
		State.INVESTIGATE:
			_on_move() # Re-use move logic to follow path
			
	if target_node:
		_on_follow_target()

	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player"):
			var game_director = get_tree().get_first_node_in_group("gameDirector")
			if game_director:
				game_director.lose()
	
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > 0.2:
		var target_angle = atan2(velocity.x, velocity.z) - PI / 2
		$NPCModel.rotation.y = lerp_angle($NPCModel.rotation.y, target_angle, ROTATION_SPEED * delta)
		$Area3D.rotation.y = lerp_angle($Area3D.rotation.y, target_angle, ROTATION_SPEED * delta)


func _on_idle() -> void:
	if target_node: return
	velocity = Vector3.ZERO;
	idle_timer_count = idle_wait_time;
	state = State.WATING_TO_MOVE;
	animPlayer.play("NPCAnimPlayer/NPCIdle")

func _on_wating_to_move(delta: float) -> void:
	if target_node: return
	idle_timer_count -= delta;
	if (idle_timer_count <= 0.0):
		var target = get_new_target_position();
		var nav_map = navigation_agent_3d.get_navigation_map();
		var safe_target = NavigationServer3D.map_get_closest_point(nav_map, target);
		navigation_agent_3d.target_position = safe_target;
		state = State.MOVE;

func investigate(target_pos: Vector3) -> void:
	var nav_map = navigation_agent_3d.get_navigation_map()
	var safe_target = NavigationServer3D.map_get_closest_point(nav_map, target_pos)
	navigation_agent_3d.target_position = safe_target
	state = State.INVESTIGATE

func update_awareness(panic_ratio: float) -> void:
	var new_radius = lerp(MIN_DETECT_RADIUS, MAX_DETECT_RADIUS, panic_ratio)
	if collision_shape_3d and collision_shape_3d.shape:
		collision_shape_3d.shape.radius = new_radius
	
	var new_energy = lerp(MIN_LIGHT_ENERGY, MAX_LIGHT_ENERGY, panic_ratio)
	var new_range = lerp(MIN_LIGHT_RANGE, MAX_LIGHT_RANGE, panic_ratio)
	
	if spot_light_3d:
		spot_light_3d.light_energy = new_energy
		spot_light_3d.spot_range = new_range

func get_new_target_position() -> Vector3:
	var offset_x = randf_range(MIN_MOVE_RANGE, MAX_MOVE_RANGE) * (-1 if randf() < 0.5 else 1);
	var offset_z = randf_range(MIN_MOVE_RANGE, MAX_MOVE_RANGE) * (-1 if randf() < 0.5 else 1);
	return global_transform.origin + Vector3(offset_x, 0, offset_z);

func _on_move() -> void:
	if target_node: return
	var current_position = global_transform.origin;
	var next_position = navigation_agent_3d.get_next_path_position();
	var direction = (next_position - current_position).normalized();
	var new_velocity = direction * SPEED;
	navigation_agent_3d.set_velocity(new_velocity);
	animPlayer.play("NPCAnimPlayer/NPCWalk")

var target_node: Node3D = null

func set_follow_target(target: Node3D):
	target_node = target

func _on_follow_target():
	if not target_node: return

	var nav_map = navigation_agent_3d.get_navigation_map()
	if not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return
		
	var target_pos = target_node.global_position
	var safe_target = NavigationServer3D.map_get_closest_point(nav_map, target_pos)
	navigation_agent_3d.target_position = safe_target
	
	if navigation_agent_3d.is_target_reached():
		return


	var current_position = global_transform.origin
	var next_position = navigation_agent_3d.get_next_path_position()
	var direction = (next_position - current_position).normalized()
	
	var new_velocity = direction * SPEED
	navigation_agent_3d.set_velocity(new_velocity)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if (body.is_in_group("player")):
		pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if (body.is_in_group("player")):
		pass

func _on_navigation_agent_3d_target_reached() -> void:
	if not target_node:
		state = State.IDLE;
		
	if state == State.INVESTIGATE:
		state = State.IDLE


func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity;


func _on_detectplayer_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("apply_slowdown"):
			body.apply_slowdown()
		set_follow_target(body)


func _on_detectplayer_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("remove_slowdown"):
			body.remove_slowdown()
		set_follow_target(null)
