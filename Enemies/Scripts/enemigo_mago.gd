extends CharacterBody3D

# --- CONFIGURACIÓN ---
@export var velocidad_caminar: float = 2.0
@export var waypoints_grupo: String = "RutaEnemigo3" 
@export var escena_proyectil:PackedScene 
@export var tiempo_entre_disparos: float = 2.0

# --- ANIMACIONES (AnimationTree) ---
@export var anim_tree: AnimationTree
@export var estado_quieto: String = "Quieto" # Idle
@export var estado_caminar: String = "Caminar" # Walk
@export var estado_atacar: String = "Ataque" # Attack

# --- REFERENCIAS ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var punto_disparo: Marker3D = $PuntoDisparo # 
@onready var state_machine = anim_tree.get("parameters/playback")

var puntos_destino: Array[Node3D] = []
var indice_actual: int = 0
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- ESTADOS LÓGICOS ---
var viendo_al_jugador: bool = false
var jugador_detectado: Node3D = null
var puede_disparar: bool = true
var temporizador_ataque: float = 0.0

func _ready():
	# Crear el Marker3D si no existe 
	if not has_node("PuntoDisparo"):
		punto_disparo = Marker3D.new()
		add_child(punto_disparo)
		punto_disparo.position = Vector3(0, 1.5, 0.5) # Altura del pecho/bastón
		
	await get_tree().physics_frame
	configurar_ruta()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta

	verificar_vision() # Llamamos a la función completa aquí

	# --- LÓGICA DE COMBATE A DISTANCIA ---
	if viendo_al_jugador:
		# 1. MODO COMBATE: No nos movemos, solo rotamos
		velocity.x = 0
		velocity.z = 0
		
		# Mirar al jugador
		look_at(jugador_detectado.global_position, Vector3.UP)
		rotation.x = 0 # No rotar en X para no inclinarse raro
		rotation.z = 0
		
		# Disparar con temporizador
		if puede_disparar:
			atacar_a_distancia()
		else:
			# Contar tiempo para recargar
			temporizador_ataque -= delta
			if temporizador_ataque <= 0:
				puede_disparar = true
				
		state_machine.travel(estado_quieto) # Se queda quieto mientras dispara
		
	else:
		# 2. MODO PATRULLA (Igual que antes)
		comportamiento_patrulla(delta)

	move_and_slide()

func atacar_a_distancia():
	if not escena_proyectil:
		print("¡Falta asignar el Proyectil.tscn en el Inspector!")
		return
		
	puede_disparar = false
	temporizador_ataque = tiempo_entre_disparos
	
	state_machine.travel(estado_atacar)
	
	# Instanciar el proyectil
	var nuevo_proyectil = escena_proyectil.instantiate()
	get_tree().root.add_child(nuevo_proyectil) # Añadirlo al mundo, no al mago
	
	# Colocarlo en la mano/bastón del mago
	nuevo_proyectil.global_position = punto_disparo.global_position
	nuevo_proyectil.global_rotation = punto_disparo.global_rotation

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

# --- LÓGICA DE VISIÓN (RAYCAST) ---
func verificar_vision():
	# 1. Si nadie ha entrado en el Area3D, ni nos molestamos en calcular rayos
	if jugador_detectado == null:
		viendo_al_jugador = false
		return

	# 2. Preparar el RayCast (Línea invisible desde ojos del mago hasta ojos del jugador)
	var espacio = get_world_3d().direct_space_state
	var origen = global_position + Vector3(0, 1.5, 0) # Altura de ojos
	var destino = jugador_detectado.global_position + Vector3(0, 1.5, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origen, destino)
	query.exclude = [self.get_rid()] # ¡Importante! Ignorarse a sí mismo
	
	# 3. Lanzar el rayo
	var resultado = espacio.intersect_ray(query)
	
	if resultado:
		if resultado.collider == jugador_detectado:
			viendo_al_jugador = true
		else:
			# Hay una pared en medio
			viendo_al_jugador = false
			# Si perdemos de vista al jugador, volvemos a patrullar el último punto conocido
			if nav_agent.target_position != puntos_destino[indice_actual].global_position:
				nav_agent.target_position = puntos_destino[indice_actual].global_position
	else:
		viendo_al_jugador = false

# --- SEÑALES DEL AREA DE VISION ---
func _on_area_vision_body_entered(body):
	if body.is_in_group("Jugador"):
		jugador_detectado = body
		print("Mago: Alguien entró en mi zona...")

func _on_area_vision_body_exited(body):
	if body == jugador_detectado:
		jugador_detectado = null
		viendo_al_jugador = false
		print("Mago: Objetivo perdido.")
