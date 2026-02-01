extends Node3D

@export var maxPanic = 100;
var currentPanic;
var panicStatus = false;
@export var panicRate = 30;
@export var cooloffRate = 30;
@export var passiveCooling = 1;
var detection = false;
@onready var player: CharacterBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	currentPanic = 0;
	detection = false;
	player = get_tree().get_first_node_in_group("player")
	priest = get_tree().get_first_node_in_group("priest")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (detection && !panicStatus):
		raisePanic(delta);

	if (currentPanic >= 100):
		panicStatus = true;
		panic();
	elif (currentPanic <= 0):
		panicStatus = false;
	
	if (panicStatus):
		currentPanic -= cooloffRate * delta;

	if (currentPanic > 0):
		currentPanic -= passiveCooling * delta;
	
	if priest:
		var panic_ratio = clamp(float(currentPanic) / float(maxPanic), 0.0, 1.0)
		priest.update_awareness(panic_ratio)

func panic() -> void:
	print_debug('PANIC TIME');
	#call panic on priest
	pass

func raisePanic(delta: float) -> void:
	currentPanic += panicRate * delta;

@onready var priest: CharacterBody3D


func on_npc_panic_signal(position: Vector3) -> void:
	if !player.is_hiding:
		detection = true;
		if priest:
			priest.investigate(position)

func on_npc_calm_signal() -> void:
	detection = false;
