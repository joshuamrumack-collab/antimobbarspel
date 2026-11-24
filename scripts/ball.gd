extends Node2D
## Fotbollen på skolgården.

var vel := Vector2.ZERO
var score := [0, 0]


func reset() -> void:
	position = GS.map.pitch.get_center()
	vel = Vector2.ZERO


func kick(v: Vector2) -> void:
	vel = v


func _process(delta: float) -> void:
	if not visible:
		return
	position += vel * delta
	vel = vel.move_toward(Vector2.ZERO, 170.0 * delta)
	var p: Rect2 = GS.map.pitch
	var cy := p.get_center().y
	if position.x < p.position.x:
		if absf(position.y - cy) < 60.0:
			_goal(1)
			return
		position.x = p.position.x
		vel.x = absf(vel.x) * 0.7
	if position.x > p.end.x:
		if absf(position.y - cy) < 60.0:
			_goal(0)
			return
		position.x = p.end.x
		vel.x = -absf(vel.x) * 0.7
	if position.y < p.position.y:
		position.y = p.position.y
		vel.y = absf(vel.y) * 0.7
	if position.y > p.end.y:
		position.y = p.end.y
		vel.y = -absf(vel.y) * 0.7
	var pl = GS.player
	if pl != null and position.distance_to(pl.position + Vector2(0, 8)) < 20.0 and vel.length() < 260.0:
		var dir: Vector2 = (position - pl.position - Vector2(0, 8)).normalized()
		if pl.moving:
			dir = (dir + Vector2(pl.facing, 0) * 0.3).normalized()
		vel = dir * 340.0
	queue_redraw()


func _goal(team: int) -> void:
	score[team] += 1
	GS.overlay.float_text(position + Vector2(0, -30), "MÅL!", Color.WHITE)
	if GS.player != null and GS.map.pitch.grow(120).has_point(GS.player.position):
		GS.toast("MÅL! Ställning %d – %d" % [score[0], score[1]], "info", 2.5)
		GS.change(0, 0, 2)
	reset()


func _draw() -> void:
	draw_circle(Vector2(0, 7), 6, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, 7, Color.WHITE)
	draw_arc(Vector2.ZERO, 7, 0, TAU, 16, Color("222222"), 1.2)
	draw_circle(Vector2(0, 0), 2.6, Color("222222"))
	for i in 5:
		var a := TAU * i / 5.0 + GS.t * vel.length() * 0.01
		draw_circle(Vector2(cos(a), sin(a)) * 5.2, 1.4, Color("222222"))
