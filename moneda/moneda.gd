extends Area3D

# Configuración
@export var modelo: Node3D 
@export var velocidad_rotacion: float = 2.0
@onready var sonido: AudioStreamPlayer3D = $AudioStreamPlayer
@onready var colision: CollisionShape3D = $CollisionShape3D

var recogido: bool = false

func _process(delta):
	# Hacemos que gire constantemente para llamar la atención
	rotate_y(velocidad_rotacion * delta)

func _on_body_entered(body):
	# Evitamos recogerlo dos veces si el jugador entra muy rápido
	if recogido: return
	
	if body.is_in_group("Jugador"):
		recogido = true
		
		# 1. Avisamos al jugador que recogió algo
		if body.has_method("recolectar_item"):
			body.recolectar_item()
		
		# 2. Feedback Visual y Sonoro
		reproducir_efecto_recogida()

func reproducir_efecto_recogida():
	# Ocultamos el objeto visualmente
	modelo.visible = false
	
	# Desactivamos la colisión para que no se pueda tocar de nuevo
	colision.set_deferred("disabled", true)
	
	# Reproducimos el sonido si existe
	if sonido.stream:
		sonido.play()
		# Esperamos a que termine el sonido antes de borrar el objeto
		await sonido.finished
	
	# Borramos el objeto de la memoria
	queue_free()
