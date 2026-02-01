extends CharacterBody3D


func apply_slowdown() -> void:
	move_speed = SLOW_SPEED

func remove_slowdown() -> void:
	move_speed = BASE_SPEED

func _ready() -> void:
	add_to_group("player")

const BASE_SPEED = 5.0
var move_speed = BASE_SPEED
const SLOW_SPEED = 2.0
const ACCELERATION = 100.0
const FRICTION = 80.0
const ROTATION_SPEED = 14.0
const DASH_SPEED = 25.0
const DASH_DURATION = 0.1

var is_dashing = false
var dash_timer = 0.0
var currentMana = 100
var is_hiding = false
var is_casting = false

@export var maxMana = 100
@export var manaRegen = 0.1
@export var dashCost = 10
@export var hideCost = 20

@onready var animPlayer = find_child("AnimationPlayer", true, false)
@export var vfx_scene: PackedScene
@export var castingCircle: PackedScene

func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if Input.is_action_just_pressed("dash") and direction and not is_dashing and currentMana >= dashCost and not is_casting:
		is_dashing = true
		dash_timer = DASH_DURATION
		velocity.x = direction.x * DASH_SPEED
		velocity.z = direction.z * DASH_SPEED
		currentMana -= dashCost;

	if Input.is_action_just_pressed("attack") and not is_casting:
		var bodies = $Area3D.get_overlapping_bodies()
		for body in bodies:
			try_transform_npc(body)

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
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
		else:
			animPlayer.play("WitchAnimPlayer/Idle")


	if Input.is_action_just_pressed("hide") and not is_dashing and not is_casting:
		becomeBox()

	if !is_dashing and not is_hiding and currentMana < 100 and not is_casting:
		currentMana += manaRegen


func becomeBox():
	if (!is_hiding and currentMana >= hideCost):
		is_hiding = true
		is_casting = true
		animPlayer.play("WitchAnimPlayer/Spell")
		var cast = castingCircle.instantiate()
		add_child(cast)
		cast.transform.origin = Vector3.ZERO
		await animPlayer.animation_finished
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

func try_transform_npc(body: Node3D) -> void:
	if body.is_in_group("npc"):
		if body.has_method("is_panicking") and body.is_panicking() or body.is_frog():
			return
		
		if body.has_method("become_frog"):
			is_casting = true
			animPlayer.play("WitchAnimPlayer/Spell")
			var cast = castingCircle.instantiate()
			body.add_child(cast)
			cast.transform.origin = Vector3.ZERO
			await animPlayer.animation_finished
			var vfx = vfx_scene.instantiate()
			body.add_child(vfx)
			vfx.transform.origin = Vector3.ZERO
			body.become_frog()
			is_casting = false
