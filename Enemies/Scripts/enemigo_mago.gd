extends CharacterBody3D

# --- CONFIGURACIÓN ---
@export var velocidad_caminar: float = 2.0
@export var waypoints_grupo: String = "RutaEnemigo3" 
@export var escena_proyectil: PackedScene 
@export var tiempo_entre_disparos: float = 2.0

# --- ¡NUEVO! AHORA EL MAGO TIENE DAÑO PROPIO ---
@export var puntos_dano: int = 1 
# -----------------------------------------------

# --- ANIMACIONES ---
@export var anim_tree: AnimationTree
@export var estado_quieto: String = "Quieto"
@export var estado_caminar: String = "Caminar" 
@export var estado_atacar: String = "AtaqueMagico" 

# --- REFERENCIAS ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var punto_disparo: Marker3D = $PuntoDisparo 
var state_machine 

var puntos_destino: Array[Node3D] = []
var indice_actual: int = 0
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- ESTADOS LÓGICOS ---
var viendo_al_jugador: bool = false
var jugador_detectado: Node3D = null
var puede_disparar: bool = true
var temporizador_ataque: float = 0.0

func _ready():
	if not anim_tree:
		push_error("ERROR: ¡Falta asignar el AnimationTree!")
		set_physics_process(false)
		return
	state_machine = anim_tree.get("parameters/playback")

	if not has_node("PuntoDisparo"):
		punto_disparo = Marker3D.new()
		add_child(punto_disparo)
		punto_disparo.position = Vector3(0, 1.5, 0.5) 
		
	await get_tree().physics_frame
	configurar_ruta()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta

	verificar_vision() 

	if viendo_al_jugador:
		velocity.x = 0
		velocity.z = 0
		look_at(jugador_detectado.global_position, Vector3.UP)
		rotation.x = 0 
		rotation.z = 0
		
		if puede_disparar:
			atacar_a_distancia()
		else:
			temporizador_ataque -= delta
			if temporizador_ataque <= 0:
				puede_disparar = true
				
		state_machine.travel(estado_quieto) 
	else:
		comportamiento_patrulla(delta)

	move_and_slide()

func atacar_a_distancia():
	if not escena_proyectil:
		print("ERROR: Asigna el Proyectil.tscn en el Inspector")
		return
		
	puede_disparar = false
	temporizador_ataque = tiempo_entre_disparos
	state_machine.travel(estado_atacar)
	
	# --- CORRECCIÓN DEL ERROR ---
	# Ya no preguntamos si es String, confiamos en que es PackedScene
	var nuevo_proyectil = escena_proyectil.instantiate()
	
	# El mago le dice al proyectil: "Toma mi fuerza"
	if "dano" in nuevo_proyectil:
		nuevo_proyectil.dano = puntos_dano

	get_tree().root.add_child(nuevo_proyectil) 
	nuevo_proyectil.global_position = punto_disparo.global_position
	nuevo_proyectil.global_rotation = punto_disparo.global_rotation

# ... (El resto de funciones siguen igual) ...

func comportamiento_patrulla(delta):
	if puntos_destino.is_empty(): return
	if nav_agent.is_navigation_finished():
		ir_al_siguiente_waypoint()
		state_machine.travel(estado_quieto)
		return
	var siguiente = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(siguiente)
	dir.y = 0
	velocity.x = dir.x * velocidad_caminar
	velocity.z = dir.z * velocidad_caminar
	if dir != Vector3.ZERO:
		var angulo = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, angulo, 10 * delta)
		state_machine.travel(estado_caminar)

func configurar_ruta():
	var nodos = get_tree().get_nodes_in_group(waypoints_grupo)
	if nodos.size() > 0:
		for n in nodos: if n is Node3D: puntos_destino.append(n)
		actualizar_destino()

func actualizar_destino():
	if puntos_destino.size() > 0: nav_agent.target_position = puntos_destino[indice_actual].global_position

func ir_al_siguiente_waypoint():
	indice_actual = wrapi(indice_actual + 1, 0, puntos_destino.size())
	actualizar_destino()

func verificar_vision():
	if jugador_detectado == null:
		viendo_al_jugador = false
		return
	var espacio = get_world_3d().direct_space_state
	var origen = global_position + Vector3(0, 1.5, 0) 
	var destino = jugador_detectado.global_position + Vector3(0, 1.5, 0)
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

func _on_area_vision_body_entered(body):
	if body.is_in_group("Jugador"): jugador_detectado = body

func _on_area_vision_body_exited(body):
	if body == jugador_detectado:
		jugador_detectado = null
		viendo_al_jugador = false
