class_name Character
extends Node2D
## Bas för alla figurer (spelaren, elever, lärare, rastvärdar, rektor).
## Ritar figuren med _draw() så att inga bildfiler behövs.

var display_name := ""
var role := "student"          # student, player, teacher, rastvakt, rektor, staff
var title := ""
var look: Dictionary = {}
var anger := 0.0
var anger_t := 0.0
var sad := 0.0
var happy := 0.0
var raise_amt := 0.0
var raise_t := 0.0
var off_x := 0.0
var off_xb := 0.0
var lunge_t := 0.0
var lunge_dir := 0.0
var recoil_t := 0.0
var recoil_dir := 0.0
var facing := 1.0
var walk_t := 0.0
var moving := false
var sitting := false
var holding_phone := false
var bubble_text := ""
var bubble_t := 0.0
var bubble_max := 1.0
var bubble_kind := "n"
var bubble_off := 0.0
var path: Array[Vector2] = []
var speed := 70.0
var size_f := 1.0
var seed_f := 0.0


func _init() -> void:
	seed_f = randf() * 10.0


func say(text: String, dur: float = 2.6, kind: String = "n") -> void:
	bubble_text = text
	bubble_t = dur
	bubble_max = dur
	bubble_kind = kind


func go_to(p: Vector2) -> void:
	path = GS.map.find_path(position, p)


func follow_path(delta: float, spd: float) -> bool:
	if path.is_empty():
		return true
	var target: Vector2 = path[0]
	var d := position.distance_to(target)
	var step := spd * delta
	moving = true
	if d <= step:
		position = target
		path.remove_at(0)
		return path.is_empty()
	var dir := (target - position) / d
	position += dir * step
	if absf(dir.x) > 0.2:
		facing = signf(dir.x)
	return false


func tick_base(delta: float) -> void:
	walk_t += delta
	if bubble_t > 0.0:
		bubble_t -= delta
		if bubble_t <= 0.0:
			bubble_text = ""
	anger = lerpf(anger, anger_t, minf(1.0, delta * 3.0))
	raise_amt = lerpf(raise_amt, raise_t, minf(1.0, delta * 5.0))
	if sad > 0.0:
		sad -= delta
	if happy > 0.0:
		happy -= delta
	var l := 0.0
	if lunge_t > 0.0:
		lunge_t -= delta
		l += lunge_dir * 12.0 * sin(clampf(1.0 - lunge_t / 0.4, 0.0, 1.0) * PI)
	if recoil_t > 0.0:
		recoil_t -= delta
		l += recoil_dir * 9.0 * sin(clampf(1.0 - recoil_t / 0.4, 0.0, 1.0) * PI)
	off_x = lerpf(off_x, off_xb + l, minf(1.0, delta * 12.0))
	queue_redraw()


# ---------------- ritning ----------------
func _rrect(r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) / 2.0)
	var pts := PackedVector2Array()
	var corners := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var starts := [-PI / 2.0, 0.0, PI / 2.0, PI]
	for i in 4:
		for k in 5:
			var a: float = starts[i] + k * (PI / 2.0) / 4.0
			var c: Vector2 = corners[i]
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, col)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _limb(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col, 6.0)
	draw_circle(a, 3.0, col)
	draw_circle(b, 3.0, col)


func _cap(hy: float, col: Color, r: float = 12.7) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(Vector2(cos(a) * r, hy - 1.0 + sin(a) * r))
	pts.append(Vector2(r, hy + 1.0))
	for i in range(1, 6):
		var u := i / 6.0
		pts.append(Vector2(lerpf(r, -r, u), hy + 1.0 - sin(u * PI) * 6.0))
	pts.append(Vector2(-r, hy + 1.0))
	draw_colored_polygon(pts, col)


func _anger_mark(c: Vector2) -> void:
	var col := Color("ff2a2a")
	for q in 4:
		var a := q * PI / 2.0
		var o := c + Vector2(cos(a + PI / 4.0), sin(a + PI / 4.0)) * 5.0
		draw_arc(o, 3.5, a + PI * 0.75, a + PI * 1.75, 6, col, 2.0)


func _draw() -> void:
	if look.is_empty():
		return
	var t: float = GS.t
	draw_set_transform(Vector2(off_x, 0), 0.0, Vector2(size_f, size_f))
	var skin: Color = look["skin"]
	var face := skin.lerp(Color("e8312a"), clampf(anger, 0.0, 1.0) * 0.75)
	var ph := walk_t * 11.0
	var bob := -absf(sin(ph)) * 2.5 if moving else sin(t * 2.0 + seed_f) * 0.6
	if sitting:
		bob += 3.0
	_ellipse(Vector2(0, 17), 13, 4.5, Color(0, 0, 0, 0.38))
	var pants: Color = look["pants"]
	if not sitting:
		var l1 := sin(ph) * 2.5 if moving else 0.0
		_rrect(Rect2(-8, 5 + l1, 7, 10), 3, pants)
		_rrect(Rect2(1, 5 - l1, 7, 10), 3, pants)
		_rrect(Rect2(-9, 13 + l1, 9, 4.5), 2, Color("0d0d0d"))
		_rrect(Rect2(0, 13 - l1, 9, 4.5), 2, Color("0d0d0d"))
	var shirt: Color = look["shirt"]
	var wave := sin(t * 14.0 + seed_f) * 3.0 * raise_amt if raise_amt > 0.05 else 0.0
	var swing := sin(ph) * 3.0 if moving else 0.0
	var ay := -2.0 + bob - raise_amt * 20.0
	if not holding_phone:
		var hl := Vector2(-15, ay + 7 + swing + wave)
		var hr := Vector2(15, ay + 7 - swing - wave)
		_limb(Vector2(-10, -5 + bob), hl, shirt)
		_limb(Vector2(10, -5 + bob), hr, shirt)
		draw_circle(hl, 3.6, face)
		draw_circle(hr, 3.6, face)
	# kropp
	_rrect(Rect2(-11, -9 + bob, 22, 17), 7, shirt.darkened(0.25))
	_rrect(Rect2(-10, -8.5 + bob, 20, 15.5), 6, shirt)
	match role:
		"rastvakt":
			_rrect(Rect2(-10.5, -9 + bob, 21, 16), 6, GS.VEST)
			draw_rect(Rect2(-10.5, -4 + bob, 21, 2.6), Color(0.86, 0.86, 0.86))
			draw_rect(Rect2(-10.5, 1.5 + bob, 21, 2.6), Color(0.86, 0.86, 0.86))
			draw_rect(Rect2(-1.5, -9 + bob, 3, 16), Color(0.86, 0.86, 0.86))
		"teacher", "staff":
			draw_line(Vector2(-5, -9 + bob), Vector2(0, 0 + bob), GS.RED, 2.0)
			draw_line(Vector2(5, -9 + bob), Vector2(0, 0 + bob), GS.RED, 2.0)
			draw_rect(Rect2(-3, 0 + bob, 6, 5), Color.WHITE)
		"rektor":
			draw_colored_polygon(PackedVector2Array([Vector2(-2, -8 + bob), Vector2(2, -8 + bob), Vector2(3, 3 + bob), Vector2(0, 6 + bob), Vector2(-3, 3 + bob)]), GS.RED)
		"player":
			draw_rect(Rect2(-6, -3 + bob, 12, 2), Color(1, 1, 1, 0.85))
	if holding_phone:
		draw_rect(Rect2(-5, -6 + bob, 10, 13), Color("111111"))
		draw_rect(Rect2(-4, -5 + bob, 8, 10), Color("7fd3ff"))
		draw_circle(Vector2(-6, 2 + bob), 3.4, face)
		draw_circle(Vector2(6, 2 + bob), 3.4, face)
	# huvud
	var hy := -21.0 + bob
	var fx := facing * 2.2
	var hair: Color = look["hair"]
	var style: String = look["style"]
	if style == "lang":
		_rrect(Rect2(-13.5, hy - 6, 27, 25), 9, hair)
	elif style == "bob":
		_rrect(Rect2(-14, hy - 6, 28, 17), 7, hair)
	draw_circle(Vector2(0, hy), 12, face)
	draw_arc(Vector2(0, hy), 12, 0, TAU, 24, Color(0, 0, 0, 0.3), 1.2)
	match style:
		"kort", "lang", "bob":
			_cap(hy, hair)
		"tofs":
			_cap(hy, hair)
			draw_circle(Vector2(0, hy - 15), 6.5, hair)
			draw_rect(Rect2(-3, hy - 11, 6, 3), GS.RED)
		"lockigt":
			var a := PI * 0.95
			while a <= PI * 2.06:
				draw_circle(Vector2(cos(a) * 11.0, hy - 1.0 + sin(a) * 11.0), 5.3, hair)
				a += PI / 6.0
		"keps":
			var pts := PackedVector2Array()
			for i in 13:
				var a2 := PI + PI * i / 12.0
				pts.append(Vector2(cos(a2) * 13.0, hy - 2.0 + sin(a2) * 13.0))
			draw_colored_polygon(pts, hair)
			_ellipse(Vector2(fx * 2.0, hy - 3), 15, 4, hair.darkened(0.35))
			draw_circle(Vector2(0, hy - 9), 2, Color.WHITE)
		"rakad":
			_cap(hy, Color(hair.r, hair.g, hair.b, 0.45), 12.3)
	if look.get("beard", false):
		var bp := PackedVector2Array()
		for i in 11:
			var a3 := PI * 0.05 + PI * 0.9 * i / 10.0
			bp.append(Vector2(cos(a3) * 12.0, hy + 1.0 + sin(a3) * 12.0))
		bp.append(Vector2(-5, hy + 6))
		bp.append(Vector2(5, hy + 6))
		draw_colored_polygon(bp, hair)
	# ansikte
	var ey := hy + 1.0
	if holding_phone:
		ey += 2.0
	var blink := fmod(t + seed_f, 4.2) < 0.12
	if blink:
		draw_rect(Rect2(-6 + fx, ey, 4, 1.4), Color("111111"))
		draw_rect(Rect2(2 + fx, ey, 4, 1.4), Color("111111"))
	else:
		draw_circle(Vector2(-4 + fx, ey), 1.9, Color("111111"))
		draw_circle(Vector2(4 + fx, ey), 1.9, Color("111111"))
	var ang := anger > 0.3
	var is_sad := sad > 0.0
	var ink := Color("111111")
	if ang:
		draw_line(Vector2(-8 + fx, hy - 5), Vector2(-2 + fx, hy - 2.5), ink, 1.8)
		draw_line(Vector2(8 + fx, hy - 5), Vector2(2 + fx, hy - 2.5), ink, 1.8)
	elif is_sad:
		draw_line(Vector2(-8 + fx, hy - 2.5), Vector2(-2 + fx, hy - 5), ink, 1.8)
		draw_line(Vector2(8 + fx, hy - 2.5), Vector2(2 + fx, hy - 5), ink, 1.8)
	if ang and bubble_text != "":
		_ellipse(Vector2(fx, hy + 6), 3.6, 2.8, Color("3a0000"))
	elif ang or is_sad:
		draw_arc(Vector2(fx, hy + 9), 3.8, PI * 1.15, PI * 1.85, 8, ink, 1.8)
	else:
		draw_arc(Vector2(fx, hy + 3.5), 3.8 + (1.0 if happy > 0.0 else 0.0), PI * 0.2, PI * 0.8, 8, ink, 1.8)
	match look.get("acc", ""):
		"glasogon":
			draw_arc(Vector2(-4 + fx, ey), 3.4, 0, TAU, 12, ink, 1.3)
			draw_arc(Vector2(4 + fx, ey), 3.4, 0, TAU, 12, ink, 1.3)
			draw_line(Vector2(-0.6 + fx, ey), Vector2(0.6 + fx, ey), ink, 1.3)
		"pannband":
			draw_rect(Rect2(-12, hy - 8, 24, 3), Color.WHITE)
		"frakner":
			for p in [Vector2(-7, 4), Vector2(-5, 5.5), Vector2(-8, 6), Vector2(7, 4), Vector2(5, 5.5), Vector2(8, 6)]:
				draw_circle(Vector2(p.x + fx, hy + p.y), 0.9, Color("8a5428"))
		"orhangen":
			draw_circle(Vector2(-12, hy + 3), 1.8, GS.GOLD)
			draw_circle(Vector2(12, hy + 3), 1.8, GS.GOLD)
	if is_sad:
		var ty := hy + 4.0 + fmod(t * 18.0 + seed_f * 5.0, 9.0)
		draw_circle(Vector2(-5 + fx, ty), 1.8, Color("5cb8ff"))
	if anger > 0.62:
		_anger_mark(Vector2(12, hy - 12 + sin(t * 10.0) * 1.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
