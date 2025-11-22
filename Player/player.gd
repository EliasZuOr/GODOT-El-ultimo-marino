extends CharacterBody3D

# --- ESTE SCRIPT ES EXCLUSIVO DEL JUGADOR ---

# Señales para la barra de vida
signal vida_cambiada(vida_actual)
signal jugador_muerto

# --- CONFIGURACIÓN DE MOVIMIENTO ---
@export_group("Movimiento")
@export var velocidad: float = 5.0
@export var velocidad_salto: float = 4.5
@export var sensibilidad_mouse: float = 0.003 

@export_group("Stats")
@export var vida_maxima: int = 3
var vida_actual: int

# --- ANIMACIONES (MACHINE STATE) ---
@export_group("Animaciones")
@export var anim_tree: AnimationTree # ¡ARRASTRA TU ANIMATIONTREE AQUÍ EN EL INSPECTOR!

# Nombres exactos de los estados (según tu imagen):
@export var estado_spawn: String = "Rig_Medium_General_Spawn_Ground"
@export var estado_idle: String = "Rig_Medium_General_Idle_A"
@export var estado_correr: String = "Rig_Medium_MovementBasic_Running_A"
@export var estado_saltar: String = "Rig_Medium_MovementBasic_Jump_Full_Short"
@export var estado_golpe: String = "Rig_Medium_General_Hit_A"
@export var estado_muerte: String = "Rig_Medium_General_Death_A"
@export var estado_recoger: String = "Rig_Medium_General_PickUp"

# --- REFERENCIAS ---
@onready var brazo_camara: SpringArm3D = $SpringArm3D
@onready var modelo: Node3D = $MeshInstance3D 

var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state_machine # Controlador de la máquina de estados
var control_bloqueado: bool = false # Para impedir movimiento al morir

func _ready():
	# Nos aseguramos de estar en el grupo Jugador para que los enemigos nos vean
	add_to_group("Jugador")
	
	# Atrapamos el mouse dentro de la ventana del juego
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	vida_actual = vida_maxima
	vida_cambiada.emit(vida_actual)
	
	# Iniciar la máquina de estados
	if anim_tree:
		state_machine = anim_tree.get("parameters/playback")
		# Reproducir animación de aparición al inicio
		state_machine.travel(estado_spawn)
	else:
		print("¡ALERTA! No asignaste el AnimationTree en el Inspector del Jugador.")

func _input(event):
	if control_bloqueado: return # Si mueres, no mueves la cámara

	# --- CÁMARA ---
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Girar al personaje (Izquierda/Derecha)
		rotate_y(-event.relative.x * sensibilidad_mouse)
		
		# Mirar Arriba/Abajo (Mouse Arriba = Mirar Arriba)
		brazo_camara.rotate_x(-event.relative.y * sensibilidad_mouse)
		
		# Limitar la rotación para no romperse el cuello
		brazo_camara.rotation.x = clamp(brazo_camara.rotation.x, deg_to_rad(-70), deg_to_rad(60))

	# Tecla ESC para liberar el mouse
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravedad * delta

	if control_bloqueado:
		move_and_slide()
		return

	# Salto
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = velocidad_salto
		state_machine.travel(estado_saltar) # Activar animación salto

	# Movimiento WASD
	var input_dir = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	
	# CORRECCIÓN DE DIRECCIÓN:

	var direccion = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direccion:
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
		
		# Si estamos en el suelo y moviéndonos -> ANIMACIÓN CORRER
		if is_on_floor():
			state_machine.travel(estado_correr)
			
	else:
		# Frenado suave
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)
		
		# Si estamos en el suelo y quietos -> ANIMACIÓN IDLE
		if is_on_floor():
			state_machine.travel(estado_idle)

	move_and_slide()

# --- DAÑO Y MUERTE ---
func recibir_dano(cantidad: int):
	if vida_actual <= 0: return
	
	vida_actual -= cantidad
	print("Jugador: ¡Auch! Vida restante: ", vida_actual)
	vida_cambiada.emit(vida_actual)
	
	# Animación de recibir golpe
	state_machine.travel(estado_golpe)
	
	if vida_actual <= 0:
		morir()

func morir():
	print("Jugador: GAME OVER")
	control_bloqueado = true
	state_machine.travel(estado_muerte)
	jugador_muerto.emit()

func recolectar_item():
	print("Jugador: ¡Item recolectado!")
	# Animación de recoger (usamos start para forzarla instantáneamente)
	state_machine.start(estado_recoger)
