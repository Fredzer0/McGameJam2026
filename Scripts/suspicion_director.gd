extends Node3D

@export var maxPanic = 100;
var currentPanic;
var panicStatus = false;
@export var panicRate = 1;
@export var cooloffRate = 1;
@export var passiveCooling = 0.01;
var detection = false;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	currentPanic = 0;
	detection = false;


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:


	if (detection && !panicStatus):
		raisePanic();


	print_debug(currentPanic);
	if (currentPanic >= 100):
		panicStatus = true;
		panic();
	elif (currentPanic <= 0):
		panicStatus = false;
	
	if (panicStatus):
		currentPanic -= cooloffRate;

	currentPanic -= passiveCooling;

func panic() -> void:
	print_debug('PANIC TIME');
	#call panic on priest
	pass

func raisePanic() -> void:

	currentPanic += panicRate;

func on_npc_panic_signal() -> void:
	detection = true;

func on_npc_calm_signal() -> void:
	detection = false;

