extends CharacterBody3D

signal jugador_atrapado(cantidad_dano)

# --- CONFIGURACIÓN DE MOVIMIENTO ---
@export var velocidad_caminar: float = 2.0
@export var velocidad_correr: float = 5.5 # Más rápido cuando persigue
@export var waypoints_grupo: String = "RutaEnemigo1"
@export var puntos_dano: int = 1

# --- CONFIGURACIÓN DE ANIMACIONES ---
@export var anim_quieto: String = "Idle"
@export var anim_caminar: String = "Walk" # Animación relajada
@export var anim_correr: String = "Run"   # Animación intensa (Ataque/Persecución)
@export var anim_atacar: String = "Attack"

# --- REFERENCIAS ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $Rogue_Mesh/AnimationPlayer 
# Referencia al punto de los ojos para el RayCast (crea un Marker3D a la altura de la cabeza si quieres ser preciso)
@onready var ojos: Node3D = self 

var puntos_destino: Array[Node3D] = []
var indice_actual: int = 0
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- ESTADOS ---
var objetivo_actual: Node3D = null # Puede ser un waypoint o el jugador
var viendo_al_jugador: bool = false
var jugador_detectado: Node3D = null # Guardamos referencia al jugador si entra en el área
var esta_atacando: bool = false

func _ready():
	# Conexión de seguridad para que el mapa cargue
	await get_tree().physics_frame
	configurar_ruta()

func configurar_ruta():
	var nodos = get_tree().get_nodes_in_group(waypoints_grupo)
	if nodos.size() > 0:
		puntos_destino.clear()
		for nodo in nodos:
			if nodo is Node3D:
				puntos_destino.append(nodo)
		if puntos_destino.size() > 0:
			actualizar_destino_patrulla()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta

	if esta_atacando:
		move_and_slide()
		return

	# --- LÓGICA DE VISIÓN (RAYCAST MANUAL) ---
	verificar_linea_de_vision()

	# --- DEFINIR VELOCIDAD Y ANIMACIÓN ---
	var velocidad_actual = velocidad_caminar
	var anim_actual = anim_caminar

	if viendo_al_jugador:
		# MODO PERSECUCIÓN
		velocidad_actual = velocidad_correr
		anim_actual = anim_correr
		# Actualizamos el destino a la posición actual del jugador en cada frame
		nav_agent.target_position = jugador_detectado.global_position
	else:
		# MODO PATRULLA
		velocidad_actual = velocidad_caminar
		anim_actual = anim_caminar
		
		# Si llegamos al waypoint, cambiar al siguiente
		if nav_agent.is_navigation_finished():
			ir_al_siguiente_waypoint()
			anim_player.play(anim_quieto)
			return

	# --- MOVIMIENTO ---
	var siguiente_pos = nav_agent.get_next_path_position()
	var direccion = global_position.direction_to(siguiente_pos)
	direccion.y = 0
	direccion = direccion.normalized()
	
	velocity.x = direccion.x * velocidad_actual
	velocity.z = direccion.z * velocidad_actual
	
	# ROTACIÓN SUAVE
	if direccion != Vector3.ZERO:
		var angulo = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, angulo, 10 * delta)
		anim_player.play(anim_actual)
	else:
		anim_player.play(anim_quieto)

	move_and_slide()

# --- SISTEMA DE VISION ---
# Esta función evita que el enemigo te vea a través de las paredes del laberinto
func verificar_linea_de_vision():
	if jugador_detectado == null:
		viendo_al_jugador = false
		return

	# Usamos el sistema de física para lanzar un rayo desde el enemigo hasta el jugador
	var espacio = get_world_3d().direct_space_state
	# Creamos la consulta del rayo (Desde: Enemigo + 1 metro altura, Hasta: Jugador + 1 metro altura)
	var origen = global_position + Vector3(0, 1, 0) 
	var destino = jugador_detectado.global_position + Vector3(0, 1, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origen, destino)
	# Excluimos al propio enemigo del rayo para que no choque consigo mismo
	query.exclude = [self.get_rid()]
	
	var resultado = espacio.intersect_ray(query)
	
	if resultado:
		if resultado.collider == jugador_detectado:
			viendo_al_jugador = true
		else:
			# Hay una pared entre el enemigo y el jugador
			viendo_al_jugador = false
			# Si pierde de vista al jugador, vuelve a patrullar su último waypoint
			if nav_agent.target_position != puntos_destino[indice_actual].global_position:
				nav_agent.target_position = puntos_destino[indice_actual].global_position
	else:
		viendo_al_jugador = false

# --- CONTROL DE WAYPOINTS ---
func actualizar_destino_patrulla():
	if puntos_destino.size() > 0:
		nav_agent.target_position = puntos_destino[indice_actual].global_position

func ir_al_siguiente_waypoint():
	if viendo_al_jugador: return # No cambiar waypoints si estamos persiguiendo
	
	indice_actual += 1
	if indice_actual >= puntos_destino.size():
		indice_actual = 0
	actualizar_destino_patrulla()

# --- SEÑALES ---
# CONECTAR ESTAS EN EL EDITOR DESDE EL AreaVision
func _on_area_vision_body_entered(body):
	if body.is_in_group("Jugador"):
		jugador_detectado = body
		print("Enemigo: Alguien entró en mi rango, verificando visión...")

func _on_area_vision_body_exited(body):
	if body == jugador_detectado:
		jugador_detectado = null
		viendo_al_jugador = false
		print("Enemigo: Perdí el rastro, volviendo a patrulla.")
		actualizar_destino_patrulla()

# CONECTAR ESTA DESDE EL AreaDano (Cuerpo a cuerpo)
func _on_area_dano_body_entered(body):
	if body.is_in_group("Jugador"):
		atacar()

func atacar():
	if esta_atacando: return
	esta_atacando = true
	velocity = Vector3.ZERO
	anim_player.play(anim_atacar)
	jugador_atrapado.emit(puntos_dano)
	await anim_player.animation_finished
	esta_atacando = false
