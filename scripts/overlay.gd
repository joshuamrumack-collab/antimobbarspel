extends Node2D
## Ritas ovanpå alla figurer: pratbubblor, namnskyltar, markeringar
## för bråk, kameror och små effekter (moln, "+10 coins").

var parts: Array = []


func puff(p: Vector2) -> void:
	for i in 5:
		parts.append({"p": p, "v": Vector2(randf_range(-60, 60), randf_range(-60, -10)), "t": 0.5, "max": 0.5, "r": randf_range(4, 8), "kind": "puff"})


func float_text(p: Vector2, text: String, col: Color) -> void:
	parts.append({"p": p, "v": Vector2(0, -35), "t": 1.6, "max": 1.6, "text": text, "col": col, "kind": "text"})


func _process(delta: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var q: Dictionary = parts[i]
		q["t"] -= delta
		q["p"] += q["v"] * delta
		if q["t"] <= 0.0:
			parts.remove_at(i)
	queue_redraw()


func _wrap(font: Font, text: String, size: int, max_w: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for w in text.split(" "):
		var t := w if cur == "" else cur + " " + w
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = t
	if cur != "":
		lines.append(cur)
	return lines


func _pill(font: Font, text: String, center: Vector2, bg: Color, fg: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
	draw_rect(Rect2(center.x - w / 2.0, center.y, w, 16), bg)
	draw_string(font, Vector2(center.x - w / 2.0, center.y + 12), text, HORIZONTAL_ALIGNMENT_CENTER, w, 11, fg)


func _draw() -> void:
	if not GS.started or GS.player == null:
		return
	var font := ThemeDB.fallback_font
	var t: float = GS.t
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	view = view.grow(120)
	# kameror
	for nm in GS.upgrades["cameras"]:
		for cp in GS.map.cam_spots.get(nm, []):
			var cpos: Vector2 = cp
			draw_rect(Rect2(cpos.x - 9, cpos.y - 6, 18, 12), Color("222222"))
			draw_rect(Rect2(cpos.x + 6, cpos.y - 3, 6, 6), Color("444444"))
			if fmod(t, 1.0) < 0.5:
				draw_circle(cpos + Vector2(-5, -2), 2.5, Color("ff2a2a"))
	# bråk
	for c in GS.cm.conflicts:
		if c.state == "active" or c.state == "body":
			var p := 0.5 + sin(t * 6.0) * 0.5
			_ring(c.pos + Vector2(0, 14), 64 + p * 6, 24 + p * 3, Color(0.78, 0.06, 0.18, 0.5 + p * 0.5), 3.0)
			if c.state == "body":
				draw_arc(c.pos + Vector2(0, 6), 22, 0, TAU, 24, Color.WHITE, 2.5)
				if c.body_p > 0.0:
					draw_arc(c.pos + Vector2(0, 6), 26, -PI / 2, -PI / 2 + TAU * c.body_p / 1.3, 24, GS.GOLD, 5.0)
				_outlined(font, "GÅ EMELLAN!", c.pos + Vector2(0, 50), 14, Color.WHITE)
	# spelarens bänk när det är lektion
	if GS.sched.needs_class_arrow() or (GS.sched.current_type() == "lesson" and not GS.player.sitting and GS.sched.current().get("room", 0) == 0):
		var sp: Vector2 = GS.player.seat_pos
		_ring(sp + Vector2(0, 14), 20 + sin(t * 5.0) * 3, 9, GS.GOLD, 2.5)
		_outlined(font, "DIN PLATS", sp + Vector2(0, -46), 12, GS.GOLD)
	# uppdrag: hämta vuxen
	var task: Dictionary = GS.main.player_task
	if task.get("type", "") == "fetch":
		var ad = task["adult"]
		_ring(ad.position + Vector2(0, 16), 28 + sin(t * 6.0) * 4, 11, Color.WHITE, 3.0)
	if GS.phone.need_adult:
		for ad in GS.main.adults:
			if not ad.is_static and view.has_point(ad.position):
				_ring(ad.position + Vector2(0, 16), 26, 10, Color(1, 1, 1, 0.6), 2.0)
	# interaktionsmarkering
	var it = GS.main.hint_target
	if it != null and it is Node2D:
		_ring(it.position + Vector2(0, 16), 22, 9, Color(1, 1, 1, 0.8), 2.0)
	# namnskyltar och markeringar
	for n in GS.main.actors.get_children():
		if not (n is Character) or not view.has_point(n.position):
			continue
		var ch: Character = n
		var y0 := ch.position.y + 22.0 * ch.size_f
		match ch.role:
			"player":
				_pill(font, ch.display_name, Vector2(ch.position.x, y0), GS.RED, Color.WHITE)
			"rastvakt":
				_pill(font, "Rastvakt " + ch.display_name, Vector2(ch.position.x, y0 + 2), GS.VEST, Color.BLACK)
			"teacher", "staff", "rektor":
				_pill(font, "%s %s" % [ch.title, ch.display_name], Vector2(ch.position.x, y0 + 2), Color.WHITE, Color.BLACK)
			"student":
				var npc = ch
				if npc.conflict != null and npc.conflict.state != "gather":
					_pill(font, ch.display_name, Vector2(ch.position.x + ch.off_x, y0), Color(0, 0, 0, 0.75), Color("dddddd"))
				elif npc.is_friend:
					_pill(font, ch.display_name + " (kompis)", Vector2(ch.position.x, y0), Color("1f7a3a"), Color.WHITE)
				elif npc.state == "lonely":
					_pill(font, ch.display_name + " är ensam", Vector2(ch.position.x, y0), Color("2b4fa0"), Color.WHITE)
				if npc.rule_break != "":
					_outlined(font, "!", ch.position + Vector2(0, -50 + sin(t * 8.0) * 3), 26, GS.GOLD)
		if ch.role == "rastvakt" and n.rule_break != "":
			_outlined(font, "!", ch.position + Vector2(0, -56 + sin(t * 8.0) * 3), 26, GS.GOLD)
	# effekter
	for q in parts:
		var a: float = clampf(q["t"] / q["max"], 0.0, 1.0)
		if q["kind"] == "puff":
			draw_circle(q["p"], q["r"] * (1.5 - a * 0.5), Color(0.87, 0.87, 0.87, a))
		else:
			var col: Color = q["col"]
			col.a = a
			_outlined(font, q["text"], q["p"], 20, col)
	# pratbubblor (sist så att de hamnar överst)
	for n in GS.main.actors.get_children():
		if n is Character and n.bubble_text != "" and view.has_point(n.position):
			_bubble(font, n)


func _ring(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w)


func _outlined(font: Font, text: String, center: Vector2, size: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 4.0
	var pos := Vector2(center.x - w / 2.0, center.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 5, Color(0, 0, 0, col.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _bubble(font: Font, c: Character) -> void:
	var a := minf(1.0, minf(c.bubble_t * 3.0, (c.bubble_max - c.bubble_t) * 8.0))
	a = clampf(a, 0.0, 1.0)
	var lines := _wrap(font, c.bubble_text, 13, 150.0)
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	w += 18.0
	var h := lines.size() * 16.0 + 10.0
	var x := c.position.x + c.off_x
	var bx := x + c.bubble_off - w / 2.0
	var by := c.position.y - 46.0 * c.size_f - h - (6.0 if c.size_f > 1.0 else 0.0)
	var kind := c.bubble_kind
	var bg := GS.RED if kind == "me" else Color.WHITE
	var border := GS.RED if kind == "mean" else (GS.GOLD if kind == "good" else (Color.WHITE if kind == "me" else Color("222222")))
	bg.a = a
	border.a = a
	var bw := 3.0 if kind == "mean" else 2.0
	draw_rect(Rect2(bx - bw, by - bw, w + bw * 2, h + bw * 2), border)
	draw_rect(Rect2(bx, by, w, h), bg)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 7, by + h), Vector2(x, by + h + 10), Vector2(x + 7, by + h)]), border)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 4, by + h - 1), Vector2(x, by + h + 5), Vector2(x + 4, by + h - 1)]), bg)
	var fg := Color.WHITE if kind == "me" else Color("111111")
	fg.a = a
	for i in lines.size():
		draw_string(font, Vector2(bx, by + 18 + i * 16), lines[i], HORIZONTAL_ALIGNMENT_CENTER, w, 13, fg)
