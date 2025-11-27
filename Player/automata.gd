extends CharacterBody3D
@export_group("Movimiento")
@export var velocidad: float = 5.0
@export var velocidad_salto: float = 4.5
@export var sensibilidad_mouse: float = 0.003
@export var nombre_idle: String = "Idle"
@export var nombre_run: String = "Run"
@export var nombre_jump: String = "Jump"
@export var nombre_crouch: String = "Crouch"
@export var anim_tree: AnimationTree
enum Estados {
	PARADO,     # q0
	CAMINANDO,  # q1
	SALTANDO,   # q2
	AGACHADO    # q3
}

var estado_actual = Estados.PARADO

const VELOCIDAD = 5.0
const VELOCIDAD_SALTO = 4.5
var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var brazo_camara: SpringArm3D = $SpringArm3D

@onready var arbol_animacion = $AnimationTree
@onready var maquina_estados = arbol_animacion.get("parameters/playback")
var state_machine
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if anim_tree:
		anim_tree.active = true
		state_machine = anim_tree.get("parameters/playback")
func _input(event):
	# girar la cámara y el personaje con el mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensibilidad_mouse)
		brazo_camara.rotate_x(-event.relative.y * sensibilidad_mouse)
		brazo_camara.rotation.x = clamp(brazo_camara.rotation.x, deg_to_rad(-70), deg_to_rad(60))

	# Para liberar el mouse con ESC
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direccion = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	match estado_actual:
		
		# ESTADO q0: PARADO
		Estados.PARADO:
			maquina_estados.travel("Idle")
			velocity.x = 0
			velocity.z = 0
			
			# Transiciones desde q0
			if Input.is_action_just_pressed("ui_accept") and is_on_floor(): # Entrada: jump
				cambiar_estado(Estados.SALTANDO)
			elif Input.is_action_pressed("ui_text_completion_query"): # Entrada: crouch
				cambiar_estado(Estados.AGACHADO)
			elif direccion != Vector3.ZERO: # Entrada: walk
				cambiar_estado(Estados.CAMINANDO)

		# ESTADO q1: CAMINANDO
		Estados.CAMINANDO:
			maquina_estados.travel("Run")
			
			# Lógica de movimiento
			if direccion:
				velocity.x = direccion.x * VELOCIDAD
				velocity.z = direccion.z * VELOCIDAD
				var angulo_destino = atan2(direccion.x, direccion.z)
				
			
			# Transiciones desde q1
			if Input.is_action_just_pressed("ui_accept") and is_on_floor(): # Entrada: jump
				cambiar_estado(Estados.SALTANDO)
			elif Input.is_action_pressed("ui_text_completion_query"): # Entrada: crouch
				cambiar_estado(Estados.AGACHADO)
			elif direccion == Vector3.ZERO: # Entrada: stop_walk
				cambiar_estado(Estados.PARADO)

		# ESTADO q2: SALTANDO
		Estados.SALTANDO:
			maquina_estados.travel("Jump")
			if direccion:
				velocity.x = direccion.x * VELOCIDAD
				velocity.z = direccion.z * VELOCIDAD
			
			# Transición desde q2
			if is_on_floor() and velocity.y <= 0:
				cambiar_estado(Estados.PARADO)

		# ESTADO q3: AGACHADO
		Estados.AGACHADO:
			maquina_estados.travel("Crouch")
			velocity.x = 0 # No se mueve agachado 
			velocity.z = 0
			
			# Transición desde q3
			if not Input.is_action_pressed("ui_text_completion_query"): 
				cambiar_estado(Estados.PARADO)

	
	move_and_slide()


func cambiar_estado(nuevo_estado):
	if nuevo_estado == Estados.SALTANDO:
		velocity.y = VELOCIDAD_SALTO
	

	estado_actual = nuevo_estado
	print("Transición a estado: ", estado_actual)
