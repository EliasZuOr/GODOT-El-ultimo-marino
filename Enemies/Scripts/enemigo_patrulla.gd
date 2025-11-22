extends CharacterBody3D

signal jugador_atrapado(cantidad_dano)

# --- CONFIGURACIÓN DE MOVIMIENTO ---
@export var velocidad_caminar: float = 2.0
@export var velocidad_correr: float = 5.5
@export var waypoints_grupo: String = "RutaEnemigo1"
@export var puntos_dano: int = 1

# --- CONFIGURACIÓN DE LA MÁQUINA DE ESTADOS ---
# IMPORTANTE: Estos nombres deben ser IGUALES a los que pusiste 
# en los cuadritos dentro del AnimationTree (no el nombre del archivo .anim)
@export var estado_quieto: String = "Quieto"
@export var estado_caminar: String = "Correr" # Si usas la misma para caminar y correr
@export var estado_atacar: String = "Atacar"

# --- REFERENCIAS ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# ARRASTRA AQUÍ TU NODO ANIMATIONTREE DESDE EL EDITOR
@export var anim_tree: AnimationTree 

@onready var ojos: Node3D = self 

var puntos_destino: Array[Node3D] = []
var indice_actual: int = 0
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Variable para controlar la reproducción
var state_machine: AnimationNodeStateMachinePlayback

# --- ESTADOS LÓGICOS ---
var objetivo_actual: Node3D = null
var viendo_al_jugador: bool = false
var jugador_detectado: Node3D = null
var esta_atacando: bool = false

func _ready():
	# Verificación de seguridad
	if not anim_tree:
		push_error("ERROR: ¡Falta asignar el AnimationTree en el Inspector!")
		set_physics_process(false)
		return
	
	# Obtenemos el controlador de la máquina de estados
	state_machine = anim_tree.get("parameters/playback")

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

	verificar_linea_de_vision()

	var velocidad_actual = velocidad_caminar
	var estado_anim_actual = estado_caminar # Por defecto usamos la de movimiento

	if viendo_al_jugador:
		velocidad_actual = velocidad_correr
		# Aquí podrías tener un estado "CorrerRapido" si tuvieras la animación
		estado_anim_actual = estado_caminar 
		nav_agent.target_position = jugador_detectado.global_position
	else:
		velocidad_actual = velocidad_caminar
		estado_anim_actual = estado_caminar
		
		# Si llegamos al punto y estamos esperando
		if nav_agent.is_navigation_finished():
			ir_al_siguiente_waypoint()
			state_machine.travel(estado_quieto) # Viajar a Quieto
			return

	var siguiente_pos = nav_agent.get_next_path_position()
	var direccion = global_position.direction_to(siguiente_pos)
	direccion.y = 0
	direccion = direccion.normalized()
	
	velocity.x = direccion.x * velocidad_actual
	velocity.z = direccion.z * velocidad_actual
	
	if direccion != Vector3.ZERO:
		var angulo = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, angulo, 10 * delta)
		
		# ACTIVAR MOVIMIENTO EN EL TREE
		state_machine.travel(estado_anim_actual)
	else:
		# ACTIVAR IDLE EN EL TREE
		state_machine.travel(estado_quieto)

	move_and_slide()

func verificar_linea_de_vision():
	if jugador_detectado == null:
		viendo_al_jugador = false
		return

	var espacio = get_world_3d().direct_space_state
	var origen = global_position + Vector3(0, 1, 0) 
	var destino = jugador_detectado.global_position + Vector3(0, 1, 0)
	var query = PhysicsRayQueryParameters3D.create(origen, destino)
	query.exclude = [self.get_rid()]
	var resultado = espacio.intersect_ray(query)
	
	if resultado:
		if resultado.collider == jugador_detectado:
			viendo_al_jugador = true
		else:
			viendo_al_jugador = false
			if nav_agent.target_position != puntos_destino[indice_actual].global_position:
				nav_agent.target_position = puntos_destino[indice_actual].global_position
	else:
		viendo_al_jugador = false

func actualizar_destino_patrulla():
	if puntos_destino.size() > 0:
		nav_agent.target_position = puntos_destino[indice_actual].global_position

func ir_al_siguiente_waypoint():
	if viendo_al_jugador: return
	indice_actual += 1
	if indice_actual >= puntos_destino.size():
		indice_actual = 0
	actualizar_destino_patrulla()

func _on_area_vision_body_entered(body):
	if body.is_in_group("Jugador"):
		jugador_detectado = body

func _on_area_vision_body_exited(body):
	if body == jugador_detectado:
		jugador_detectado = null
		viendo_al_jugador = false
		actualizar_destino_patrulla()

func _on_area_dano_body_entered(body):
	if body.is_in_group("Jugador"):
		atacar()

func atacar():
	if esta_atacando: return
	esta_atacando = true
	velocity = Vector3.ZERO
	
	state_machine.travel(estado_atacar)
	
	jugador_atrapado.emit(puntos_dano)
	
	# --- APLICACIÓN DE DAÑO DIRECTO ---
	# Verificamos si podemos dañar al jugador
	if jugador_detectado and jugador_detectado.has_method("recibir_dano"):
		jugador_detectado.recibir_dano(puntos_dano)
	elif jugador_detectado == null:
		# Si el jugador ya se alejó pero el ataque se disparó, intentamos buscarlo en el grupo
		var jugadores = get_tree().get_nodes_in_group("Jugador")
		if jugadores.size() > 0:
			# Si está muy cerca (rango de golpe), le damos
			if global_position.distance_to(jugadores[0].global_position) < 2.5:
				if jugadores[0].has_method("recibir_dano"):
					jugadores[0].recibir_dano(puntos_dano)
	# ----------------------------------
	
	await get_tree().create_timer(1.0).timeout 
	esta_atacando = false
