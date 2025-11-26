extends CharacterBody3D

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


@onready var arbo_animacion = $AnimationTree
@onready var maquina_estados = arbol_animacion.get("parameters/playback")


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direccion = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	match estado_actual:
		
		# ESTADO q0: PARADO
		Estados.PARADO:
			reproducir_anim("Idle")
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
			reproducir_anim("Run")
			
			# Lógica de movimiento
			if direccion:
				velocity.x = direccion.x * VELOCIDAD
				velocity.z = direccion.z * VELOCIDAD
				look_at(position + direccion, Vector3.UP)
			
			# Transiciones desde q1
			if Input.is_action_just_pressed("ui_accept") and is_on_floor(): # Entrada: jump
				cambiar_estado(Estados.SALTANDO)
			elif Input.is_action_pressed("ui_text_completion_query"): # Entrada: crouch
				cambiar_estado(Estados.AGACHADO)
			elif direccion == Vector3.ZERO: # Entrada: stop_walk
				cambiar_estado(Estados.PARADO)

		# ESTADO q2: SALTANDO
		Estados.SALTANDO:
			reproducir_anim("Jump")
			if direccion:
				velocity.x = direccion.x * VELOCIDAD
				velocity.z = direccion.z * VELOCIDAD
			
			# Transición desde q2
			if is_on_floor() and velocity.y <= 0:
				cambiar_estado(Estados.PARADO)

		# ESTADO q3: AGACHADO
		Estados.AGACHADO:
			reproducir_anim("ui_text_completion_query")
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


func reproducir_anim(nombre_animacion):
	if animador:
		if animador.current_animation != nombre_animacion:
			animador.play(nombre_animacion)
