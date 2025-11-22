extends CharacterBody3D

# Señales
signal vida_cambiada(vida_actual)
signal jugador_muerto
signal item_recolectado(cantidad_actual)
signal juego_ganado # ¡NUEVA SEÑAL DE VICTORIA!

# --- CONFIGURACIÓN ---
@export_group("Movimiento")
@export var velocidad: float = 5.0
@export var velocidad_salto: float = 4.5
@export var sensibilidad_mouse: float = 0.003 

@export_group("Stats")
@export var vida_maxima: int = 3
@export var items_para_ganar: int = 10 # Meta configurable
var vida_actual: int
var items_totales: int = 0

# --- ANIMACIONES ---
@export_group("Animaciones")
@export var anim_tree: AnimationTree 
@export var estado_spawn: String = "Rig_Medium_General_Spawn_Ground"
@export var estado_idle: String = "Rig_Medium_General_Idle_A"
@export var estado_correr: String = "Rig_Medium_MovementBasic_Running_A"
@export var estado_saltar: String = "Rig_Medium_MovementBasic_Jump_Full_Short"
@export var estado_golpe: String = "Rig_Medium_General_Hit_A"
@export var estado_muerte: String = "Rig_Medium_General_Death_A"
@export var estado_recoger: String = "Rig_Medium_General_PickUp"

# --- REFERENCIAS ---
@onready var brazo_camara: SpringArm3D = $SpringArm3D
@export var modelo: Node3D 

var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state_machine 
var control_bloqueado: bool = false 
var esta_herido: bool = false 

func _ready():
	add_to_group("Jugador")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	vida_actual = vida_maxima
	call_deferred("emitir_datos_iniciales")
	
	if anim_tree:
		if not anim_tree.active: anim_tree.active = true
		state_machine = anim_tree.get("parameters/playback")
		start_anim(estado_spawn)

func emitir_datos_iniciales():
	vida_cambiada.emit(vida_actual)
	item_recolectado.emit(items_totales)

func _input(event):
	if control_bloqueado: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensibilidad_mouse)
		brazo_camara.rotate_x(-event.relative.y * sensibilidad_mouse) # Sin invertir (Estándar)
		brazo_camara.rotation.x = clamp(brazo_camara.rotation.x, deg_to_rad(-70), deg_to_rad(60))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if not is_on_floor(): velocity.y -= gravedad * delta
	if control_bloqueado or esta_herido:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return 

	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = velocidad_salto
		travel_anim(estado_saltar)

	var input_dir = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var direccion = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direccion:
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
		if is_on_floor(): travel_anim(estado_correr)
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)
		if is_on_floor(): travel_anim(estado_idle)
	move_and_slide()

func travel_anim(nombre: String):
	if state_machine: state_machine.travel(nombre)
func start_anim(nombre: String):
	if state_machine: state_machine.start(nombre)

func recibir_dano(cantidad: int):
	if vida_actual <= 0: return
	vida_actual -= cantidad
	print("Jugador: Vida restante: ", vida_actual)
	vida_cambiada.emit(vida_actual)
	esta_herido = true
	start_anim(estado_golpe)
	if vida_actual <= 0:
		morir()
	else:
		await get_tree().create_timer(0.5).timeout
		esta_herido = false

func morir():
	print("Jugador: GAME OVER")
	control_bloqueado = true
	start_anim(estado_muerte)
	jugador_muerto.emit()

func recolectar_item():
	items_totales += 1
	print("Jugador: Item recolectado. Total: ", items_totales)
	item_recolectado.emit(items_totales)
	start_anim(estado_recoger)
	
	# --- VERIFICACIÓN DE VICTORIA ---
	if items_totales >= items_para_ganar:
		ganar_juego()

func ganar_juego():
	print("Jugador: ¡VICTORIA! Recogiste todos los items.")
	control_bloqueado = true # Bloqueamos el movimiento
	juego_ganado.emit()      # Avisamos al HUD
