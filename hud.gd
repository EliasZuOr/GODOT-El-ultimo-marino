extends CanvasLayer

# --- REFERENCIAS A LOS TEXTOS (LABELS) ---
@onready var label_vidas: Label = $Control/LabelVidas
@onready var label_tiempo: Label = $Control/LabelTiempo
@onready var label_items: Label = $Control/LabelItems

# --- CONFIGURACIÓN DE ESCENAS ---
@export_file("*.tscn") var ruta_menu: String = "res://main.tscn"

# --- VARIABLES INTERNAS ---
var tiempo_transcurrido: float = 0.0
var juego_activo: bool = true

func _ready():
	var jugador = get_tree().get_first_node_in_group("Jugador")
	
	if jugador:
		jugador.vida_cambiada.connect(actualizar_vidas)
		jugador.item_recolectado.connect(actualizar_items)
		jugador.jugador_muerto.connect(game_over)
		
		if not jugador.juego_ganado.is_connected(victoria):
			jugador.juego_ganado.connect(victoria)
		
		actualizar_vidas(jugador.vida_actual)
		actualizar_items(0)
	else:
		print("HUD ERROR: No encontré al nodo Jugador.")

func _process(delta):
	if juego_activo:
		tiempo_transcurrido += delta
		actualizar_reloj()

func actualizar_reloj():
	var minutos = int(tiempo_transcurrido / 60)
	var segundos = int(tiempo_transcurrido) % 60
	label_tiempo.text = "Tiempo: %02d:%02d" % [minutos, segundos]

func actualizar_vidas(cantidad: int):
	label_vidas.text = "Vidas: " + str(cantidad)
	if cantidad <= 1:
		label_vidas.modulate = Color.RED
	else:
		label_vidas.modulate = Color.WHITE

func actualizar_items(cantidad: int):
	label_items.text = "Coleccionables: " + str(cantidad) + " / 10"

# --- LÓGICA DE FIN DE JUEGO ---

func game_over():
	juego_activo = false
	label_tiempo.text = "¡HAS MUERTO!" # Mensaje más claro
	label_tiempo.modulate = Color.RED
	label_tiempo.uppercase = true 
	
	# CAMBIO: Al morir, reiniciamos el nivel
	reiniciar_nivel()

func victoria():
	juego_activo = false
	label_tiempo.text = "¡VICTORIA!\nESCAPASTE DEL LABERINTO"
	label_tiempo.modulate = Color.GREEN
	label_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# CAMBIO: Al ganar, vamos al menú
	regresar_al_menu()

# --- FUNCIONES DE NAVEGACIÓN ---

func reiniciar_nivel():
	print("HUD: Reiniciando nivel en 4 segundos...")
	
	# Esperamos un poco para ver la animación de muerte del jugador
	await get_tree().create_timer(4.0).timeout
	
	# Recargamos la escena actual (Vuelve a empezar el laberinto)
	get_tree().reload_current_scene()

func regresar_al_menu():
	print("HUD: Regresando al menú en 5 segundos...")
	
	await get_tree().create_timer(5.0).timeout
	
	# Liberamos el mouse para poder usar el menú
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if ruta_menu and ResourceLoader.exists(ruta_menu):
		get_tree().change_scene_to_file(ruta_menu)
	else:
		# Si no hay menú, reiniciamos como fallback
		get_tree().reload_current_scene()
