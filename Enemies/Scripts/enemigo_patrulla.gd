extends CharacterBody3D

# --- SEÑALES (La forma correcta de comunicarse) ---
# Emitimos esto cuando el enemigo toca al jugador.
# Quien use este enemigo (el Nivel) conectará esta señal para restar vidas.
signal jugador_atrapado(cantidad_dano)

# --- CONFIGURACIÓN ---
@export var velocidad_movimiento: float = 3.0
@export var waypoints_grupo: String = "RutaEnemigo1" # El grupo de Marker3D a seguir
@export var puntos_dano: int = 1 # Cuánto daño hace este enemigo

# --- REFERENCIAS INTERNAS ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
# Asegúrate de que tu modelo visual no bloquee el RayCast de navegación, 
# o usa un nodo Node3D simple como pivote.
@onready var modelo_visual: Node3D = $Rogue_Mesh 

var puntos_destino: Array[Node3D] = []
var indice_actual: int = 0
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var esta_persiguiendo: bool = true

func _ready():
	# Retrasamos un frame la búsqueda para asegurar que el mapa cargó
	await get_tree().physics_frame
	configurar_ruta()

func configurar_ruta():
	# Busca todos los nodos (Marker3D) que tengan la etiqueta de grupo
	var nodos = get_tree().get_nodes_in_group(waypoints_grupo)
	
	if nodos.size() > 0:
		puntos_destino = nodos
		actualizar_destino()
	else:
		# Imprimimos una advertencia si el diseñador de niveles olvidó poner la ruta
		push_warning("Enemigo: No encontré waypoints en el grupo '" + waypoints_grupo + "'")
		esta_persiguiendo = false

func _physics_process(delta):
	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y -= gravedad * delta

	# Si no hay ruta o paramos, solo aplicamos gravedad y fricción
	if not esta_persiguiendo or puntos_destino.is_empty():
		move_and_slide()
		return

	# 2. Navegación Inteligente
	if nav_agent.is_navigation_finished():
		ir_al_siguiente_waypoint()
		return

	# Obtener hacia dónde ir según el NavigationServer
	var siguiente_pos = nav_agent.get_next_path_position()
	var direccion = global_position.direction_to(siguiente_pos)
	
	# Anulamos Y para que no intente volar o atravesar el suelo hacia abajo
	direccion.y = 0
	direccion = direccion.normalized()
	
	# 3. Movimiento
	velocity.x = direccion.x * velocidad_movimiento
	velocity.z = direccion.z * velocidad_movimiento
	
	# 4. Rotación suave (Mirar a donde camina)
	if direccion != Vector3.ZERO:
		var angulo_deseado = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, angulo_deseado, 10 * delta)

	move_and_slide()

func actualizar_destino():
	if puntos_destino.size() > 0:
		nav_agent.target_position = puntos_destino[indice_actual].global_position

func ir_al_siguiente_waypoint():
	indice_actual += 1
	# Bucle infinito de patrulla
	if indice_actual >= puntos_destino.size():
		indice_actual = 0
	actualizar_destino()

# --- CONEXIÓN DE SEÑAL ---

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Verificamos si es el jugador usando Grupos 
	if body.is_in_group("Jugador") or body.name == "Jugador":
		
		
		jugador_atrapado.emit(puntos_dano)
		
		print("Enemigo: Toqué al jugador. Señal emitida.")
