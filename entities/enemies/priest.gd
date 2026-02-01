extends CharacterBody3D

signal panic_signal(position);
signal calm_signal();

var director: Node;

const SPEED = 3.0
const ROTATION_SPEED = 14.0
const MIN_MOVE_RANGE = 6
const MAX_MOVE_RANGE = 10

const MIN_DETECT_RADIUS = 2.0
const MAX_DETECT_RADIUS = 8.0
const MIN_LIGHT_ENERGY = 3.0
const MAX_LIGHT_ENERGY = 11.0
const MIN_LIGHT_RANGE = 4.0
const MAX_LIGHT_RANGE = 8.0

enum State {IDLE, WATING_TO_MOVE, MOVE, INVESTIGATE, PRAYING, GAME_OVER}
var state: State = State.IDLE
var is_global_chase: bool = false

var idle_wait_time: float = 1.5
var idle_timer_count: float = 0
var move_timer: float = 0.0
var path_update_timer: float = 0.0
@onready var collision_shape_3d: CollisionShape3D = $detectplayer/CollisionShape3D
@onready var spot_light_3d: SpotLight3D = $Area3D/SpotLight3D


@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animPlayer = find_child("AnimationPlayer", true, false)
const SMOKE_VFX = preload("res://vfx/SmokePouff/Smoke.tscn")

func _ready() -> void:
	# Removed bad self-connections
	director = get_tree().get_first_node_in_group("suspicionDirector");

	if (director):
		panic_signal.connect(director.on_npc_panic_signal);
		calm_signal.connect(director.on_npc_calm_signal);

	add_to_group("priest")


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta;

	match state:
		State.IDLE:
			print("IDLE")
			_on_idle()
		State.WATING_TO_MOVE:
			print("WATING_TO_MOVE")
			_on_wating_to_move(delta)
		State.MOVE:
			print("MOVE")
			_on_move()
		State.INVESTIGATE:
			print("INVESTIGATE")
			_on_move()
		State.PRAYING:
			print("PRAYING")
			velocity = Vector3.ZERO
		State.GAME_OVER:
			print("GAME_OVER")
			velocity = Vector3.ZERO
			
	if target_node:
		_on_follow_target()

	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player") and state != State.GAME_OVER:
			state = State.GAME_OVER
			velocity = Vector3.ZERO
			
			if collider.has_method("disable_movement") and not (collider.get("is_hiding") if "is_hiding" in collider else false):
				collider.disable_movement()
			else:
				# If player is hiding, ignore collision/game over logic (or just return/pass)
				if "is_hiding" in collider and collider.is_hiding:
					return

			animPlayer.play("NPCAnimPlayer/ClerkPrayer")
			
			var tree = get_tree()
			if tree:
				await tree.create_timer(0.8).timeout
			else:
				return
				
			if not is_inside_tree(): return
			
			var smoke = SMOKE_VFX.instantiate()
			get_parent().add_child(smoke)
			smoke.global_position = collider.global_position
			

			await animPlayer.animation_finished
			
			if not is_inside_tree(): return
			
			var game_director = get_tree().get_first_node_in_group("gameDirector")
			if game_director:
				game_director.lose()
	
	if state != State.PRAYING:
		var bodies = $detectplayer.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("npc"):
				if body.has_method("is_frog") and body.is_frog():
					state = State.PRAYING
					velocity = Vector3.ZERO
					animPlayer.play("NPCAnimPlayer/ClerkPrayer")
					await animPlayer.animation_finished
					body.become_human()
					state = State.IDLE
					break
	
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > 0.2:
		var target_angle = atan2(velocity.x, velocity.z)
		$NPCModel.rotation.y = lerp_angle($NPCModel.rotation.y, target_angle, ROTATION_SPEED * delta)
		$Area3D.rotation.y = lerp_angle($Area3D.rotation.y, target_angle - PI / 2, ROTATION_SPEED * delta)


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
	
	move_timer -= get_physics_process_delta_time()
	if move_timer <= 0:
		state = State.IDLE

var target_node: Node3D = null

func set_follow_target(target: Node3D):
	target_node = target

func _on_follow_target():
	if not target_node: return
	if target_node.get("is_hiding"):
		target_node = null
		state = State.IDLE
		velocity = Vector3.ZERO
		return

	var nav_map = navigation_agent_3d.get_navigation_map()
	if not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return
		
	path_update_timer -= get_physics_process_delta_time()
	if path_update_timer <= 0:
		path_update_timer = 0.2
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
	animPlayer.play("NPCAnimPlayer/NPCWalk")


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


func start_global_chase(target: Node3D) -> void:
	is_global_chase = true
	set_follow_target(target)

func stop_global_chase() -> void:
	is_global_chase = false
	# If we are not currently detecting the player, update target to null
	# We need to check if the player is actually in the detection area
	var detect_area = $detectplayer
	if detect_area:
		var bodies = detect_area.get_overlapping_bodies()
		var player_in_zone = false
		for b in bodies:
			if b.is_in_group("player"):
				player_in_zone = true
				break
		
		if not player_in_zone:
			set_follow_target(null)
	else:
		set_follow_target(null)

func _on_detectplayer_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Check if player is hiding
		if body.get("is_hiding"):
			target_node = null
			state = State.IDLE
			velocity = Vector3.ZERO
			return
			
		if body.has_method("apply_slowdown"):
			panic_signal.emit(body.global_position);
			body.apply_slowdown()
		set_follow_target(body)


func _on_detectplayer_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("remove_slowdown"):
			body.remove_slowdown()
		
		if not is_global_chase:
			set_follow_target(null)
