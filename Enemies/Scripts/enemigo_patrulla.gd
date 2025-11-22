extends CharacterBody3D

signal jugador_atrapado(cantidad_dano)

# --- CONFIGURACIÓN DE MOVIMIENTO ---
@export var velocidad_caminar: float = 2.0
@export var velocidad_correr: float = 5.5
@export var waypoints_grupo: String = "RutaEnemigo1"
@export var puntos_dano: int = 1

# --- CONFIGURACIÓN DE LA MÁQUINA DE ESTADOS ---
@export var estado_quieto: String = "Quieto"
@export var estado_caminar: String = "Correr"
@export var estado_atacar: String = "Atacar"

# --- REFERENCIAS ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@export var anim_tree: AnimationTree 
@onready var ojos: Node3D = self 

var puntos_destino: Array[Node3D] = []
var indice_actual: int = 0
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var state_machine: AnimationNodeStateMachinePlayback

# --- ESTADOS LÓGICOS ---
var objetivo_actual: Node3D = null
var viendo_al_jugador: bool = false
var jugador_detectado: Node3D = null
var esta_atacando: bool = false

func _ready():
	if not anim_tree:
		push_error("ERROR: ¡Falta asignar el AnimationTree en el Inspector!")
		set_physics_process(false)
		return
	
	# Hack para loops si usas animaciones importadas sin bucle configurado
	var animaciones_con_loop = ["Idle", "Run", "Walk"]
	var player_path = anim_tree.anim_player
	if has_node(player_path):
		var player = get_node(player_path)
		var lista = player.get_animation_list()
		for nombre_anim in lista:
			for clave in animaciones_con_loop:
				if clave in nombre_anim: 
					var anim = player.get_animation(nombre_anim)
					anim.loop_mode = Animation.LOOP_LINEAR

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
		else:
			print("Enemigo: Grupo encontrado pero sin nodos 3D válidos.")
	else:
		print("Enemigo: ¡NO ENCONTRÉ EL GRUPO '", waypoints_grupo, "' EN EL MAPA!")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta

	if esta_atacando:
		move_and_slide()
		return

	verificar_linea_de_vision()

	if viendo_al_jugador:
		# --- LÓGICA DE PERSECUCIÓN (JUGADOR) ---
		var distancia = global_position.distance_to(jugador_detectado.global_position)
		
		if distancia < 1.5:
			velocity.x = 0
			velocity.z = 0
			atacar()
			
			# --- ARREGLO DEL GIRO DE 180 GRADOS ---
			look_at(jugador_detectado.global_position, Vector3.UP)
			rotation.x = 0
			rotation.z = 0
			# Rotamos 180 grados extra (PI radianes) para corregir el modelo invertido
			rotate_y(PI) 
			# --------------------------------------
			
		else:
			nav_agent.target_position = jugador_detectado.global_position
			
			var siguiente_pos = nav_agent.get_next_path_position()
			var direccion = global_position.direction_to(siguiente_pos)
			direccion.y = 0
			direccion = direccion.normalized()
			
			velocity.x = direccion.x * velocidad_correr
			velocity.z = direccion.z * velocidad_correr
			
			if direccion != Vector3.ZERO:
				var angulo = atan2(velocity.x, velocity.z)
				rotation.y = lerp_angle(rotation.y, angulo, 10 * delta)
				state_machine.travel(estado_caminar) 
	else:
		# --- LÓGICA DE PATRULLA (WAYPOINTS) --- 
		
		if puntos_destino.is_empty():
			state_machine.travel(estado_quieto)
			move_and_slide()
			return

		if nav_agent.is_navigation_finished():
			ir_al_siguiente_waypoint()
			state_machine.travel(estado_quieto)
			return

		var siguiente_pos = nav_agent.get_next_path_position()
		var direccion = global_position.direction_to(siguiente_pos)
		direccion.y = 0
		direccion = direccion.normalized()
		
		velocity.x = direccion.x * velocidad_caminar
		velocity.z = direccion.z * velocidad_caminar
		
		if direccion != Vector3.ZERO:
			var angulo = atan2(velocity.x, velocity.z)
			rotation.y = lerp_angle(rotation.y, angulo, 10 * delta)
			state_machine.travel(estado_caminar)
		else:
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
	
	if jugador_detectado and jugador_detectado.has_method("recibir_dano"):
		jugador_detectado.recibir_dano(puntos_dano)
	elif jugador_detectado == null:
		var jugadores = get_tree().get_nodes_in_group("Jugador")
		if jugadores.size() > 0:
			if global_position.distance_to(jugadores[0].global_position) < 2.5:
				if jugadores[0].has_method("recibir_dano"):
					jugadores[0].recibir_dano(puntos_dano)
	
	await get_tree().create_timer(1.0).timeout 
	esta_atacando = false

# Esta función es clave para inicializar la detección
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		jugador_detectado = body
		print("¡Te veo! Entraste en radar.")
