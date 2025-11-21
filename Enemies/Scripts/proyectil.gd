extends Area3D

@export var velocidad: float = 10.0
@export var dano: int = 1
var direccion: Vector3 = Vector3.FORWARD

func _ready():
	# Se autodestruye a los 3 segundos para no llenar el juego de basura
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	# Moverse hacia adelante en su propia dirección local
	position += transform.basis.z * velocidad * delta

# Conecta la señal "body_entered" del Area3D a esta función
func _on_body_entered(body):
	# Si choca con el jugador
	if body.is_in_group("Jugador"):
		# Si el jugador tiene un método para recibir daño, úsalo
		if body.has_method("recibir_dano"):
			body.recibir_dano(dano)
		print("Proyectil: Quemé al jugador")
		queue_free() # Desaparecer
	
	# Si choca con el escenario (paredes), desaparece
	# Asumiendo que el escenario es StaticBody3D o CSGBox3D
	elif body is StaticBody3D or body is CSGShape3D:
		queue_free()
