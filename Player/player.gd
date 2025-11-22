extends CharacterBody3D

# --- ESTE SCRIPT ES EXCLUSIVO DEL JUGADOR (VERSIÓN FINAL CORREGIDA) ---

# Señales para la interfaz y juego
signal vida_cambiada(vida_actual)
signal jugador_muerto

# --- CONFIGURACIÓN ---
@export_group("Movimiento")
@export var velocidad: float = 5.0
@export var velocidad_salto: float = 4.5
@export var sensibilidad_mouse: float = 0.003 

@export_group("Stats")
@export var vida_maxima: int = 3
var vida_actual: int

# --- ANIMACIONES (NOMBRES DE ESTADOS) ---
# Asegúrate de que estos nombres coincidan con tu AnimationTree
@export_group("Animaciones")
@export var anim_tree: AnimationTree # ¡ARRASTRA TU ANIMATIONTREE AQUÍ!
@export var estado_spawn: String = "Rig_Medium_General_Spawn_Ground"
@export var estado_idle: String = "Rig_Medium_General_Idle_A"
@export var estado_correr: String = "Rig_Medium_MovementBasic_Running_A"
@export var estado_saltar: String = "Rig_Medium_MovementBasic_Jump_Full_Short"
@export var estado_golpe: String = "Rig_Medium_General_Hit_A"
@export var estado_muerte: String = "Rig_Medium_General_Death_A"
@export var estado_recoger: String = "Rig_Medium_General_PickUp"

# --- REFERENCIAS ---
@onready var brazo_camara: SpringArm3D = $SpringArm3D
# Usa @export para el modelo por si el nodo se llama diferente (ej. Rig, Armature)
@export var modelo: Node3D 

# --- VARIABLES INTERNAS ---
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state_machine # Controlador de la máquina de estados
var control_bloqueado: bool = false # Para muerte
var esta_herido: bool = false # Para aturdimiento por golpe

func _ready():
	# Grupo para que los enemigos nos detecten
	add_to_group("Jugador")
	
	# Atrapamos el mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Salud inicial
	vida_actual = vida_maxima
	vida_cambiada.emit(vida_actual)
	
	# Iniciar Animaciones
	if anim_tree:
		if not anim_tree.active:
			anim_tree.active = true
		state_machine = anim_tree.get("parameters/playback")
		# Iniciamos con la aparición
		start_anim(estado_spawn)
	else:
		push_error("ERROR: Falta asignar el AnimationTree en el Inspector del Jugador")

func _input(event):
	# Si estamos muertos, no movemos la cámara
	if control_bloqueado: return

	# --- CÁMARA (MOUSE) ---
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# 1. Girar al personaje entero (Eje Y - Izquierda/Derecha)
		# El signo "-" es lo estándar. Si gira al revés, quítalo.
		rotate_y(-event.relative.x * sensibilidad_mouse)
		
		# 2. Mover solo la cabeza/brazo (Eje X - Arriba/Abajo)
		# El signo "-" aquí hace que Mouse Arriba = Mirar Arriba (Estilo Shooter)
		brazo_camara.rotate_x(-event.relative.y * sensibilidad_mouse)
		
		# Limitar cuello (Clamp)
		brazo_camara.rotation.x = clamp(brazo_camara.rotation.x, deg_to_rad(-70), deg_to_rad(60))

	# Tecla ESC para liberar mouse
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# 1. Gravedad (Siempre aplica, estemos como estemos)
	if not is_on_floor():
		velocity.y -= gravedad * delta

	# 2. SI ESTAMOS HERIDOS O MUERTOS, NO NOS MOVEMOS
	if control_bloqueado or esta_herido:
		# Solo aplicamos la gravedad calculada arriba y salimos
		move_and_slide()
		return 

	# 3. Salto
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = velocidad_salto
		travel_anim(estado_saltar)

	# 4. Movimiento WASD
	# get_vector: (neg_x, pos_x, neg_y, pos_y) -> (Izquierda, Derecha, Adelante, Atras)
	var input_dir = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	
	# Calculamos la dirección relativa a hacia donde mira el personaje
	# Vector3(x, 0, y) es lo estándar.
	var direccion = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direccion:
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
		
		# Animación correr solo si estamos en el piso (para no cortar el salto)
		if is_on_floor():
			travel_anim(estado_correr)
	else:
		# Frenado
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)
		
		# Animación Idle
		if is_on_floor():
			travel_anim(estado_idle)

	move_and_slide()

# --- AYUDANTES DE ANIMACIÓN ---
func travel_anim(nombre: String):
	if state_machine: state_machine.travel(nombre)

func start_anim(nombre: String):
	if state_machine: state_machine.start(nombre)

# --- DAÑO Y EVENTOS ---
func recibir_dano(cantidad: int):
	if vida_actual <= 0: return # Ya está muerto
	
	# 1. Restar vida
	vida_actual -= cantidad
	print("Jugador: ¡Auch! Vida restante: ", vida_actual)
	vida_cambiada.emit(vida_actual)
	
	# 2. Activar estado de herido (Bloquea movimiento en _physics_process)
	esta_herido = true
	
	# 3. Forzar animación de golpe inmediatamente
	start_anim(estado_golpe)
	
	# 4. Verificar muerte o recuperación
	if vida_actual <= 0:
		morir()
	else:
		# Esperamos 0.5 segundos aturdidos para ver la animación
		await get_tree().create_timer(0.5).timeout
		esta_herido = false
		# Al terminar el tiempo, _physics_process volverá a permitir moverse

func morir():
	print("Jugador: GAME OVER")
	control_bloqueado = true
	start_anim(estado_muerte)
	jugador_muerto.emit()

func recolectar_item():
	print("Jugador: ¡Item recolectado!")
	start_anim(estado_recoger)
