extends CanvasLayer

func _ready():
	# Nos aseguramos de que el menú empiece oculto y el juego corriendo
	visible = false

func _unhandled_input(event):
	# Detecta si se presiona la tecla ESC (ui_cancel es ESC por defecto en Godot)
	if event.is_action_pressed("ui_cancel"):
		cambiar_pausa()

func cambiar_pausa():
	# Invertimos el estado actual de la pausa
	var nuevo_estado = not get_tree().paused
	get_tree().paused = nuevo_estado
	
	# Hacemos visible u oculto el menú completo (es mejor que solo el ColorRect)
	visible = nuevo_estado

func _on_seguir_pressed() -> void:
	# Quitamos la pausa explícitamente
	get_tree().paused = false
	visible = false

func _on_salir_pressed() -> void:
	get_tree().quit()
