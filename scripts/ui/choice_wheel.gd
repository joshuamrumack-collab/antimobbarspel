extends CanvasLayer
## Valhjulet (som GTA:s vapenhjul men med repliker). 12 val per sida,
## flera sidor med repliker, plus ett textfält för egna meningar.

const PER_PAGE := 12

var root: Control
var line: LineEdit
var target = null
var hover := 0
var page := 0
var anim := 0.0
var geo := {}
var page_btn: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = GS.make_theme()
	add_child(root)
	root.draw.connect(_draw_wheel)
	root.gui_input.connect(_on_gui)
	# nederkant: egen mening
	var bar := PanelContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1
	bar.anchor_bottom = 1
	bar.offset_left = -360
	bar.offset_right = 360
	bar.offset_top = -78
	bar.offset_bottom = -12
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)
	line = LineEdit.new()
	line.placeholder_text = "Skriv en egen mening för att stoppa bråket..."
	line.max_length = 80
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.text_submitted.connect(func(_t): _say())
	h.add_child(line)
	var say_btn := Button.new()
	say_btn.text = "Säg det!"
	say_btn.pressed.connect(_say)
	h.add_child(say_btn)
	# överkant: fler repliker och stäng
	var top := HBoxContainer.new()
	top.anchor_left = 1
	top.anchor_right = 1
	top.offset_left = -420
	top.offset_right = -14
	top.offset_top = 14
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	page_btn = Button.new()
	page_btn.text = "Fler repliker (Tab)"
	page_btn.pressed.connect(_next_page)
	top.add_child(page_btn)
	var close_btn := Button.new()
	close_btn.text = "Stäng (Esc)"
	close_btn.pressed.connect(func(): close(true))
	top.add_child(close_btn)
	visible = false


func is_open() -> bool:
	return visible


func open_for(c) -> void:
	target = c
	page = 0
	hover = 0
	anim = 0.0
	visible = true
	GS.ui_block = true
	Engine.time_scale = 0.12
	line.text = ""
	_update_page_btn()
	root.queue_redraw()


func close(dismiss: bool = false) -> void:
	if not visible:
		return
	if target != null and dismiss:
		target.dismissed = true
	target = null
	visible = false
	GS.ui_block = false
	Engine.time_scale = 1.0
	line.release_focus()


func _opts() -> Array:
	if target == null:
		return []
	return target.options.slice(page * PER_PAGE, page * PER_PAGE + PER_PAGE)


func _pages() -> int:
	if target == null:
		return 1
	return maxi(1, int(ceil(target.options.size() / float(PER_PAGE))))


func _next_page() -> void:
	page = (page + 1) % _pages()
	hover = 0
	_update_page_btn()
	root.queue_redraw()


func _update_page_btn() -> void:
	page_btn.text = "Fler repliker (Tab)  %d/%d" % [page + 1, _pages()]


func opt_text(id: String) -> String:
	if id == "fetch_adult":
		return "Spring och hämta en vuxen"
	if id == "friend_help":
		var f = GS.cm.nearest_friend(target.pos) if target != null else null
		return "Be kompisen %s hjälpa till" % f.display_name if f != null else "Be en kompis om hjälp"
	return Data.OPT[id]["t"]


func _choose(i: int) -> void:
	var opts := _opts()
	if i < 0 or i >= opts.size() or target == null:
		return
	var c = target
	var id: String = opts[i]
	close()
	GS.cm.choose(c, id)


func _say() -> void:
	if target == null:
		return
	var txt := line.text.strip_edges()
	if txt.length() < 3:
		GS.toast("Skriv en hel mening först!", "warn", 2.5)
		return
	var c = target
	close()
	GS.cm.custom(c, txt)


func _process(delta: float) -> void:
	if not visible:
		return
	anim = minf(1.0, anim + delta / maxf(Engine.time_scale, 0.01) * 6.0)
	if target != null and (target.dead or target.state != "active"):
		close()
		return
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or line.has_focus():
		return
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event
	if ke.pressed and not ke.echo:
		var n := _opts().size()
		var k: int = ke.physical_keycode
		if k == KEY_TAB:
			_next_page()
		elif k == KEY_ESCAPE:
			close(true)
		elif k in [KEY_LEFT, KEY_UP, KEY_A, KEY_W]:
			hover = (hover - 1 + n) % n
		elif k in [KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S]:
			hover = (hover + 1) % n
		elif k == KEY_ENTER or k == KEY_SPACE or k == KEY_KP_ENTER:
			_choose(hover)
		elif k >= KEY_1 and k <= KEY_9:
			_choose(k - KEY_1)
		elif k == KEY_0:
			_choose(9)
		else:
			return
		get_viewport().set_input_as_handled()
		root.queue_redraw()


func _index_at(p: Vector2) -> int:
	if geo.is_empty():
		return -1
	var c: Vector2 = geo["c"]
	var d := p.distance_to(c)
	if d < geo["r"] * 0.8:
		return -2
	if d > geo["R"] + 40.0:
		return -1
	var a := fposmod((p - c).angle() - geo["start"], TAU)
	return int(a / geo["seg"]) % _opts().size()


func _on_gui(ev) -> void:
	if ev is InputEventMouseMotion:
		var i := _index_at(ev.position)
		if i >= 0:
			hover = i
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var i2 := _index_at(ev.position)
		if i2 == -2:
			close(true)
		elif i2 >= 0:
			_choose(i2)


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


func _draw_wheel() -> void:
	if target == null:
		return
	var font := ThemeDB.fallback_font
	var vs := root.size
	var an := 1.0 - pow(1.0 - anim, 3.0)
	root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6 * an))
	var opts := _opts()
	var n := opts.size()
	if n == 0:
		return
	var R := clampf(minf(vs.x * 0.36, (vs.y - 220.0) / 2.0), 150.0, 290.0) * (0.7 + 0.3 * an)
	var r := R * 0.36
	var c := Vector2(vs.x / 2.0, (vs.y - 90.0) / 2.0 + 30.0)
	var seg := TAU / n
	var start := -PI / 2.0 - seg / 2.0
	geo = {"c": c, "R": R, "r": r, "seg": seg, "start": start}
	root.draw_circle(c, R + 12, Color(0.78, 0.06, 0.18, 0.25 * an))
	for i in n:
		var a0 := start + i * seg
		var a1 := a0 + seg
		var hov := i == hover
		var ro := R + (8.0 if hov else 0.0)
		var pts := PackedVector2Array()
		for k in 13:
			var a := lerpf(a0, a1, k / 12.0)
			pts.append(c + Vector2.from_angle(a) * ro)
		for k in 13:
			var a := lerpf(a1, a0, k / 12.0)
			pts.append(c + Vector2.from_angle(a) * r)
		var id: String = opts[i]
		var special := id == "fetch_adult" or id == "friend_help"
		var fill := GS.RED if hov else (Color(0.16, 0.05, 0.07, 0.95) if special else Color(0.05, 0.05, 0.06, 0.94))
		root.draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		root.draw_polyline(pts, Color.WHITE if hov else GS.RED, 2.5)
		var am := a0 + seg / 2.0
		var tr := (R + r) / 2.0 + (4.0 if hov else 0.0)
		var tp := c + Vector2.from_angle(am) * tr
		var fs := 12 if R < 220.0 else 14
		var maxw := minf(R - r, seg * tr) * 0.92
		var lines := _wrap(font, opt_text(id), fs, maxw)
		var lh := fs + 3.0
		for j in lines.size():
			var y := tp.y + (j - (lines.size() - 1) / 2.0) * lh + fs * 0.35
			root.draw_string(font, Vector2(tp.x - maxw / 2.0, y), lines[j], HORIZONTAL_ALIGNMENT_CENTER, maxw, fs, GS.GOLD if special and not hov else Color.WHITE)
		if i < 10:
			var np := c + Vector2.from_angle(am) * (R - 12.0)
			root.draw_string(font, np + Vector2(-10, 5), str((i + 1) % 10), HORIZONTAL_ALIGNMENT_CENTER, 20, 11, Color.WHITE if hov else Color("ff5a6e"))
	root.draw_circle(c, r - 4.0, Color("050505"))
	root.draw_arc(c, r - 4.0, 0, TAU, 40, GS.RED, 3.0)
	var hl := _wrap(font, opt_text(opts[clampi(hover, 0, n - 1)]), 15, r * 1.5)
	for j in hl.size():
		root.draw_string(font, Vector2(c.x - r, c.y - 6 + (j - (hl.size() - 1) / 2.0) * 19), hl[j], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 15, Color.WHITE)
	root.draw_string(font, Vector2(c.x - r, c.y + r * 0.6), "klicka här = stäng", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 11, Color("999999"))
	var title := "INGRIP: %s & %s" % [target.a.display_name, target.b.display_name]
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 30.0
	var ty := c.y - R - 50.0
	root.draw_rect(Rect2(c.x - tw / 2.0, ty, tw, 34), GS.RED)
	root.draw_string(font, Vector2(c.x - tw / 2.0, ty + 24), title, HORIZONTAL_ALIGNMENT_CENTER, tw, 20, Color.WHITE)
