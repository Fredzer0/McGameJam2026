extends CharacterBody3D

const SPEED = 8.0
const ACCELERATION = 100.0
const FRICTION = 80.0
const ROTATION_SPEED = 14.0
const DASH_SPEED = 25.0
const DASH_DURATION = 0.1

var is_dashing = false
var dash_timer = 0.0

func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if Input.is_action_just_pressed("dash") and direction and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		velocity.x = direction.x * DASH_SPEED
		velocity.z = direction.z * DASH_SPEED

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	elif direction:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCELERATION * delta)
		
		var target_angle = atan2(direction.x, direction.z)
		$MeshInstance3D.rotation.y = lerp_angle($MeshInstance3D.rotation.y, target_angle, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	move_and_slide()
