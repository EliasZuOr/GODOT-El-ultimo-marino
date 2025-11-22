extends Area3D

@export var goldToGive : int = 1
var rotateSpeed : float = 5.0

func _process(delta: float) -> void:
	rotate_y(rotateSpeed * delta)

func _on_Coin_body_entered(body: Node) -> void:
	if body.is_in_group("Jugador"):
		body.give_gold(goldToGive)
		queue_free()
