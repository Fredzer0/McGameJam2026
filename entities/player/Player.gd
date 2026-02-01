extends CharacterBody3D


func apply_slowdown() -> void:
	move_speed = SLOW_SPEED

func remove_slowdown() -> void:
	move_speed = BASE_SPEED

func _ready() -> void:
	add_to_group("player")
	
	var model_path = CharacterManager.get_current_model_path()
	var new_model = load(model_path).instantiate()
	
	for child in $WitchModel.get_children():
		$WitchModel.remove_child(child)
		child.queue_free()
		
	$WitchModel.add_child(new_model)
	
	animPlayer = new_model.find_child("AnimationPlayer", true, false)
	if not animPlayer:
		animPlayer = find_child("AnimationPlayer", true, false)
	
	if fireball_scene:
		fireball_model = fireball_scene.instantiate()
		add_child(fireball_model)
		fireball_model.hide()

const BASE_SPEED = 5.0
var move_speed = BASE_SPEED
const SLOW_SPEED = 2.0
const ACCELERATION = 100.0
const FRICTION = 80.0
const ROTATION_SPEED = 14.0
const DASH_SPEED = 20.0
const DASH_DURATION = 0.09

var is_dashing = false
var dash_timer = 0.0
var currentMana = 100
var is_hiding = false
var is_casting = false

@export var maxMana = 100
@export var manaRegen = 0.1
@export var dashCost = 30
@export var hideCost = 20

@onready var animPlayer = find_child("AnimationPlayer", true, false)
@export var vfx_scene: PackedScene
@export var castingCircle: PackedScene
@export var fireball_scene: PackedScene

@onready var spellSound = $Audio/Spell
@onready var dashSound = $Audio/Dash
@onready var walkSound = $Audio/Walk


var fireball_model: Node3D
var can_move = true

func disable_movement():
	can_move = false
	velocity = Vector3.ZERO
	animPlayer.play("WitchAnimPlayer/Idle")

func _physics_process(delta):
	if not can_move:
		move_and_slide()
		return

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if Input.is_action_just_pressed("dash") and direction and not is_dashing and currentMana >= dashCost and not is_casting:
		is_dashing = true
		dash_timer = DASH_DURATION
		velocity.x = direction.x * DASH_SPEED
		velocity.z = direction.z * DASH_SPEED
		currentMana -= dashCost
		dashSound.play()
		start_dash_visuals()

	if Input.is_action_just_pressed("attack") and not is_casting:
		var bodies = $Area3D.get_overlapping_bodies()
		for body in bodies:
			try_transform_npc(body)

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			end_dash_visuals()
	elif direction:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, ACCELERATION * delta)
		
		var target_angle = atan2(direction.x, direction.z)
		$WitchModel.rotation.y = lerp_angle($WitchModel.rotation.y, target_angle, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	if !is_hiding and not is_casting:
		move_and_slide()
		if input_dir:
			animPlayer.play("WitchAnimPlayer/Walk")
			if !walkSound.playing:
				walkSound.play(0.5)
		else:
			animPlayer.play("WitchAnimPlayer/Idle")
			walkSound.stop()


	if Input.is_action_just_pressed("hide") and not is_dashing and not is_casting:
		if walkSound.playing:
			walkSound.stop()
		becomeBox()

	if !is_dashing and not is_hiding and currentMana < 100 and not is_casting:
		currentMana += manaRegen


func becomeBox():
	if (!is_hiding and currentMana >= hideCost):
		is_casting = true
		animPlayer.play("WitchAnimPlayer/Spell")
		spellSound.play()
		var cast = castingCircle.instantiate()
		add_child(cast)
		cast.transform.origin = Vector3.ZERO
		await animPlayer.animation_finished
		is_hiding = true
		var vfx = vfx_scene.instantiate()
		add_child(vfx)
		vfx.transform.origin = Vector3.ZERO
		$WitchModel.hide()
		$BoxModel.show()
		is_casting = false
		
		currentMana -= hideCost;
	elif is_hiding:
		is_hiding = false
		var vfx = vfx_scene.instantiate()
		add_child(vfx)
		vfx.transform.origin = Vector3.ZERO
		$WitchModel.show()
		$BoxModel.hide()

func start_dash_visuals() -> void:
	# Spawn pouff
	#if vfx_scene:
		#var vfx = vfx_scene.instantiate()
		#add_child(vfx)
		#vfx.transform.origin = Vector3.ZERO
	$WitchModel.hide()
	$BoxModel.hide()
	if fireball_model:
		fireball_model.show()
		var target_angle = atan2(velocity.x, velocity.z)
		fireball_model.rotation.y = target_angle - PI / 2

func end_dash_visuals() -> void:
	# Spawn pouff
	#if vfx_scene:
		#var vfx = vfx_scene.instantiate()
		#add_child(vfx)
		#vfx.transform.origin = Vector3.ZERO
	if fireball_model:
		fireball_model.hide()
		
	if is_hiding:
		$BoxModel.show()
	else:
		$WitchModel.show()

func try_transform_npc(body: Node3D) -> void:
	if body.is_in_group("npc"):
		if body.has_method("is_panicking") and body.is_panicking() or body.is_frog():
			return
		
		if body.has_method("become_frog"):
			is_casting = true
			animPlayer.play("WitchAnimPlayer/Spell")
			spellSound.play()
			var cast = castingCircle.instantiate()
			body.add_child(cast)
			cast.transform.origin = Vector3.ZERO
			await animPlayer.animation_finished
			var vfx = vfx_scene.instantiate()
			body.add_child(vfx)
			vfx.transform.origin = Vector3.ZERO
			body.become_frog()
			is_casting = false

var active_target_visuals = {}

func _process(delta: float) -> void:
	update_target_visuals()

func is_valid_target(body: Node3D) -> bool:
	if not body.is_in_group("npc"):
		return false
	if body.has_method("is_panicking") and body.is_panicking():
		return false
	if body.has_method("is_frog") and body.is_frog():
		return false
	if not body.has_method("become_frog"):
		return false
	return true

func update_target_visuals() -> void:
	if is_casting or is_hiding:
		# cleanup all visuals if we are busy
		for body in active_target_visuals.keys():
			if is_instance_valid(active_target_visuals[body]):
				active_target_visuals[body].queue_free()
		active_target_visuals.clear()
		return

	var current_bodies = []
	if $Area3D:
		current_bodies = $Area3D.get_overlapping_bodies()
	
	# Check for new targets
	for body in current_bodies:
		if is_valid_target(body):
			if not active_target_visuals.has(body):
				if vfx_scene:
					var vfx = vfx_scene.instantiate()
					body.add_child(vfx)
					vfx.transform.origin = Vector3.ZERO
					active_target_visuals[body] = vfx
	
	# Cleanup targets that are no longer valid or in range
	var bodies_to_remove = []
	for body in active_target_visuals.keys():
		if not is_instance_valid(body) or body not in current_bodies or not is_valid_target(body):
			if is_instance_valid(active_target_visuals[body]):
				active_target_visuals[body].queue_free()
			bodies_to_remove.append(body)
	
	for body in bodies_to_remove:
		active_target_visuals.erase(body)
