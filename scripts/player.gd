extends Character
## Spelaren. Styrs med WASD/piltangenter eller touch-joysticken.

var seat_pos := Vector2.ZERO
var joy := Vector2.ZERO


func _ready() -> void:
	role = "player"
	speed = 175.0


func _process(delta: float) -> void:
	moving = false
	if not GS.ui_block:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if joy.length() > 0.15:
			v = joy
		if v.length() > 0.05:
			if v.length() > 1.0:
				v = v.normalized()
			sitting = false
			move(v * speed * delta)
			moving = true
			if absf(v.x) > 0.1:
				facing = signf(v.x)
	tick_base(delta)


func move(d: Vector2) -> void:
	if not blocked(position + Vector2(d.x, 0)):
		position.x += d.x
	if not blocked(position + Vector2(0, d.y)):
		position.y += d.y


func blocked(p: Vector2, r: float = 11.0) -> bool:
	for o in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		if not GS.map.walkable_pos(p + o):
			return true
	return false


func teleport(p: Vector2) -> void:
	position = p
	sitting = false
	path.clear()
