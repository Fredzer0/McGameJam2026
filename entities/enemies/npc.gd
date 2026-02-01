extends CharacterBody3D

signal panic_signal(position)
signal calm_signal()

var susDirector: Node
var gDirector: Node
var look_at_target: Node3D = null

const SPEED = 3.0
const PANIC_SPEED = 1.0
const ROTATION_SPEED = 14.0
const MIN_MOVE_RANGE = 12
const MAX_MOVE_RANGE = 30
const PANIC_MAX_DURATION = 10.0
const MOVE_TIMEOUT = 5.0

enum State {IDLE, WATING_TO_MOVE, MOVE, PANIC, FROG}
var state: State = State.IDLE

enum Form {HUMAN, FROG}
var form: Form = Form.HUMAN

var idle_wait_time: float = 1.5
var idle_timer_count: float = 0
var panic_timer: float = 0.0
var move_timer: float = 0.0
var path_update_timer: float = 0.0

@onready var spot_light_3d: SpotLight3D = $Area3D/SpotLight3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animPlayer = find_child("AnimationPlayer", true, false)

func _ready() -> void:
	susDirector = get_tree().get_first_node_in_group("suspicionDirector")
	gDirector = get_tree().get_first_node_in_group("gameDirector")

	if (susDirector):
		panic_signal.connect(susDirector.on_npc_panic_signal);
		calm_signal.connect(susDirector.on_npc_calm_signal);

	add_to_group("npc")
	
	# Desync path updates
	path_update_timer = randf_range(0.0, 0.2)

func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta;

	match state:
		State.IDLE:
			_on_idle()
		State.WATING_TO_MOVE:
			_on_wating_to_move(delta)
		State.MOVE:
			_on_move()
		State.PANIC:
			_on_panic()
		State.FROG:
			velocity = Vector3.ZERO
			
	move_and_slide()
	
	if look_at_target and state == State.PANIC:
		var direction = look_at_target.global_position - global_position
		var target_angle = atan2(direction.x, direction.z)
		rotate_mesh(target_angle, delta)
	else:
		var horizontal_velocity = Vector2(velocity.x, velocity.z)
		if horizontal_velocity.length() > 0.2:
			var target_angle = atan2(velocity.x, velocity.z)
			rotate_mesh(target_angle, delta)

func rotate_mesh(target_angle: float, delta: float) -> void:
	$NpcModel.rotation.y = lerp_angle($NpcModel.rotation.y, target_angle, ROTATION_SPEED * delta)
	$Area3D.rotation.y = lerp_angle($Area3D.rotation.y, target_angle - PI / 2, ROTATION_SPEED * delta)


func _on_idle() -> void:
	velocity = Vector3.ZERO;
	# Desync idle times to prevent cpu spikes
	idle_timer_count = randf_range(idle_wait_time * 0.5, idle_wait_time * 1.5);
	state = State.WATING_TO_MOVE;
	animPlayer.play("NPCAnimPlayer/NPCIdle")

func _on_wating_to_move(delta: float) -> void:
	idle_timer_count -= delta;
	if (idle_timer_count <= 0.0):
		var target = get_new_target_position();
		var nav_map = navigation_agent_3d.get_navigation_map();
		var safe_target = NavigationServer3D.map_get_closest_point(nav_map, target);
		navigation_agent_3d.target_position = safe_target;
		move_timer = MOVE_TIMEOUT
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
	animPlayer.play("NPCAnimPlayer/NPCWalk")
	
	move_timer -= get_physics_process_delta_time()
	if move_timer <= 0:
		state = State.IDLE

func get_flee_position(source: Node3D) -> Vector3:
	var npc_pos = global_transform.origin
	var player_pos = source.global_position
	var flee_direction = npc_pos - player_pos
	flee_direction.y = 0;
	if flee_direction.length() < 0.1:
		flee_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	
	flee_direction = flee_direction.normalized()
	var flee_distance = MAX_MOVE_RANGE
	var flee_target = npc_pos + flee_direction * flee_distance
	
	return flee_target

func _on_panic() -> void:
	panic_timer -= get_physics_process_delta_time()
	if panic_timer <= 0:
		state = State.IDLE
		calm_signal.emit()
		return

	if look_at_target:
		path_update_timer -= get_physics_process_delta_time()
		if path_update_timer <= 0:
			path_update_timer = 0.2
			var flee_target = get_flee_position(look_at_target)
			var nav_map = navigation_agent_3d.get_navigation_map()
			var safe_target = NavigationServer3D.map_get_closest_point(nav_map, flee_target)
			navigation_agent_3d.target_position = safe_target

	var current_position = global_transform.origin;
	var next_position = navigation_agent_3d.get_next_path_position();
	var direction = (next_position - current_position).normalized();
	var new_velocity = direction * PANIC_SPEED;
	navigation_agent_3d.set_velocity(new_velocity);
	animPlayer.play("NPCAnimPlayer/NPCWalk")

func start_panic(source: Node3D) -> void:
	panic_timer = PANIC_MAX_DURATION
	var flee_target = get_flee_position(source);
	var nav_map = navigation_agent_3d.get_navigation_map();
	var safe_target = NavigationServer3D.map_get_closest_point(nav_map, flee_target);
	navigation_agent_3d.target_position = safe_target;
	state = State.PANIC;

func become_frog() -> void:
	form = Form.FROG
	$NpcModel.hide()
	$FrogModel.show()
	$Area3D/SpotLight3D.hide()
	state = State.FROG
	gDirector.morphVillager()

func become_human() -> void:
	form = Form.HUMAN
	$NpcModel.show()
	$FrogModel.hide()
	$Area3D/SpotLight3D.show()
	state = State.IDLE
	gDirector.unmorphVillager()

func _on_area_3d_body_exited(body: Node3D) -> void:
	if (body.is_in_group("player")) and form == Form.HUMAN:
		calm_signal.emit();

func _on_area_3d_body_entered(body: Node3D) -> void:
	if (body.is_in_group("player")) and form == Form.HUMAN:
		if body.get("is_hiding"):
			return
		panic_signal.emit(body.global_position);
		start_panic(body);

func _on_navigation_agent_3d_target_reached() -> void:
	state = State.IDLE;

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity;

func _on_detect_look_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and form == Form.HUMAN:
		if body.get("is_hiding"):
			return
		look_at_target = body

func _on_detect_look_body_exited(body: Node3D) -> void:
	if body == look_at_target and form == Form.HUMAN:
		look_at_target = null

func is_panicking() -> bool:
	return state == State.PANIC


func is_frog() -> bool:
	return state == State.FROG
