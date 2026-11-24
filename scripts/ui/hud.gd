extends CanvasLayer
## HUD: betyg, omdöme och hälsa uppe till höger, klocka och karta uppe
## till vänster, rum + uppdrag i mitten, pilar till bråk och knappar.

var root: Control
var grade_l: Label
var omd_l: Label
var health_bar: ProgressBar
var health_l: Label
var coins_l: Label
var abs_l: Label
var stop_l: Label
var clock_l: Label
var period_l: Label
var room_l: Label
var obj_l: Label
var toasts: VBoxContainer
var hint_panel: PanelContainer
var hint_l: Label
var badge: Label
var phone_btn: Button
var arrows: Control
var minimap: Control
var mm_tex: ImageTexture
var touch_ui: Control
var joy_center := Vector2.ZERO
var joy_id := -1
var joy_vec := Vector2.ZERO


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = GS.make_theme()
	root.visible = false
	add_child(root)
	arrows = Control.new()
	arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrows.draw.connect(_draw_arrows)
	root.add_child(arrows)
	_build_stats()
	_build_clock()
	_build_center()
	_build_buttons()
	_build_touch()
	GS.stats_changed.connect(_refresh)
	GS.toast_requested.connect(_toast)


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _label(text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


# ---------- uppe till höger: betyg, omdöme, hälsa ----------
func _build_stats() -> void:
	var pc := PanelContainer.new()
	_place(pc, 1, 0, 1, 0, -270, 10, -10, 10)
	pc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(_label("BETYG", 15, Color("ff5a6e")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	grade_l = _label("C", 34, GS.GOLD)
	row.add_child(grade_l)
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	r2.add_child(_label("OMDÖME", 15, Color("ff5a6e")))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(sp2)
	omd_l = _label("Godtagbart", 17)
	r2.add_child(omd_l)
	var r3 := HBoxContainer.new()
	v.add_child(r3)
	r3.add_child(_label("HÄLSA", 15, Color("ff5a6e")))
	var sp3 := Control.new()
	sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3.add_child(sp3)
	health_l = _label("100", 17)
	r3.add_child(health_l)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(240, 14)
	health_bar.show_percentage = false
	health_bar.max_value = 100
	v.add_child(health_bar)
	var sep := HSeparator.new()
	v.add_child(sep)
	var r4 := HBoxContainer.new()
	v.add_child(r4)
	var coin := Control.new()
	coin.custom_minimum_size = Vector2(30, 30)
	coin.draw.connect(func():
		coin.draw_circle(Vector2(15, 15), 14, Color("7a5200"))
		coin.draw_circle(Vector2(15, 15), 12, Color("ffcc33"))
		coin.draw_string(ThemeDB.fallback_font, Vector2(0, 22), "C", HORIZONTAL_ALIGNMENT_CENTER, 30, 18, Color("7a5200"))
	)
	r4.add_child(coin)
	coins_l = _label("0 coins", 24, GS.GOLD)
	r4.add_child(coins_l)
	abs_l = _label("Olovlig frånvaro: 0/5", 14, Color("dddddd"))
	v.add_child(abs_l)
	stop_l = _label("Stoppade bråk: 0  ·  Kompisar: 0", 14, Color("dddddd"))
	v.add_child(stop_l)


# ---------- uppe till vänster: klocka och karta ----------
func _build_clock() -> void:
	var pc := PanelContainer.new()
	_place(pc, 0, 0, 0, 0, 10, 10, 210, 10)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	clock_l = _label("Måndag 08:00", 20, Color.WHITE)
	v.add_child(clock_l)
	period_l = _label("Morgon", 14, Color("ff8a98"))
	v.add_child(period_l)
	minimap = Control.new()
	minimap.custom_minimum_size = Vector2(180, 92)
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap.draw.connect(_draw_minimap)
	v.add_child(minimap)


func _make_minimap() -> void:
	var m = GS.map
	var img := Image.create(m.COLS, m.ROWS, false, Image.FORMAT_RGBA8)
	for y in m.ROWS:
		for x in m.COLS:
			var i: int = y * m.COLS + x
			var col := Color("050505")
			if m.grid[i] == 2:
				col = Color("5a5a60")
			elif m.grid[i] == 1:
				var f: int = m.ftype[i]
				if f == m.F_GRASS:
					col = Color("2f6b2a")
				elif f == m.F_CORR or f == m.F_DOOR:
					col = Color("2c2c32")
				else:
					col = Color("46464e")
			img.set_pixel(x, y, col)
	mm_tex = ImageTexture.create_from_image(img)


func _draw_minimap() -> void:
	if mm_tex == null or GS.player == null:
		return
	var s := 2.0
	minimap.draw_texture_rect(mm_tex, Rect2(0, 0, 180, 92), false)
	var k := s / 40.0
	for c in GS.cm.conflicts:
		if c.state == "active" or c.state == "body":
			minimap.draw_circle(c.pos * k, 4, GS.RED if fmod(GS.t, 0.5) < 0.25 else Color.WHITE)
	for ad in GS.main.adults:
		minimap.draw_rect(Rect2(ad.position * k - Vector2(1.5, 1.5), Vector2(3, 3)), GS.VEST if ad.role == "rastvakt" else Color.WHITE)
	minimap.draw_circle(GS.player.position * k, 3.2, GS.GOLD)


# ---------- mitten: rum, uppdrag, meddelanden, tips ----------
func _build_center() -> void:
	var v := VBoxContainer.new()
	_place(v, 0.5, 0, 0.5, 0, -300, 10, 300, 10)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)
	var rp := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = GS.RED
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	rp.add_theme_stylebox_override("panel", sb)
	rp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rp)
	room_l = _label("KORRIDOREN", 15)
	rp.add_child(room_l)
	var op := PanelContainer.new()
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0, 0, 0, 0.8)
	sb2.set_corner_radius_all(8)
	sb2.set_content_margin_all(6)
	op.add_theme_stylebox_override("panel", sb2)
	op.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(op)
	obj_l = _label("", 14)
	op.add_child(obj_l)
	toasts = VBoxContainer.new()
	toasts.add_theme_constant_override("separation", 6)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(toasts)
	hint_panel = PanelContainer.new()
	_place(hint_panel, 0.5, 1, 0.5, 1, -200, -64, 200, -20)
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_panel)
	hint_l = _label("", 17, Color.WHITE)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_l)
	hint_panel.visible = false


func _build_buttons() -> void:
	var h := HBoxContainer.new()
	_place(h, 1, 1, 1, 1, -330, -66, -12, -12)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 8)
	root.add_child(h)
	var shop := Button.new()
	shop.text = "Butik (B)"
	shop.pressed.connect(func(): GS.shop.open())
	h.add_child(shop)
	phone_btn = Button.new()
	phone_btn.text = "Mobil (F)"
	phone_btn.pressed.connect(func(): GS.phone.toggle())
	h.add_child(phone_btn)
	badge = _label("", 13, Color.WHITE)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = GS.RED
	bsb.border_color = Color.WHITE
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(10)
	bsb.content_margin_left = 6
	bsb.content_margin_right = 6
	badge.add_theme_stylebox_override("normal", bsb)
	badge.position = Vector2(-6, -12)
	badge.visible = false
	phone_btn.add_child(badge)
	var help := Button.new()
	help.text = "Hjälp (H)"
	help.pressed.connect(func(): GS.help.open())
	h.add_child(help)


func _build_touch() -> void:
	touch_ui = Control.new()
	touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_ui.visible = DisplayServer.is_touchscreen_available()
	root.add_child(touch_ui)
	var pad := Control.new()
	_place(pad, 0, 1, 0, 1, 20, -230, 230, -20)
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	pad.gui_input.connect(_joy_input.bind(pad))
	pad.draw.connect(func():
		pad.draw_circle(Vector2(105, 105), 80, Color(1, 1, 1, 0.12))
		pad.draw_arc(Vector2(105, 105), 80, 0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
		pad.draw_circle(Vector2(105, 105) + joy_vec * 60.0, 30, Color(0.78, 0.06, 0.18, 0.8))
	)
	touch_ui.add_child(pad)
	var eb := Button.new()
	eb.text = "  E  "
	eb.add_theme_font_size_override("font_size", 30)
	_place(eb, 1, 1, 1, 1, -150, -190, -40, -90)
	eb.pressed.connect(func(): GS.main.interact())
	touch_ui.add_child(eb)


func _joy_input(ev, pad: Control) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			joy_id = ev.index
			_joy_set(ev.position)
		elif ev.index == joy_id:
			joy_id = -1
			joy_vec = Vector2.ZERO
	elif ev is InputEventScreenDrag and ev.index == joy_id:
		_joy_set(ev.position)
	elif ev is InputEventMouseButton:
		if ev.pressed:
			_joy_set(ev.position)
		else:
			joy_vec = Vector2.ZERO
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_joy_set(ev.position)
	if GS.player != null:
		GS.player.joy = joy_vec
	pad.queue_redraw()


func _joy_set(p: Vector2) -> void:
	joy_vec = ((p - Vector2(105, 105)) / 80.0).limit_length(1.0)


# ---------- uppdatering ----------
func show_hud() -> void:
	root.visible = true
	_make_minimap()
	_refresh()


func set_hint(t: String) -> void:
	if hint_l == null:
		return
	hint_panel.visible = t != ""
	hint_l.text = t


func set_badge(n: int) -> void:
	badge.visible = n > 0
	badge.text = str(n)


func _refresh() -> void:
	grade_l.text = GS.grade_letter()
	omd_l.text = GS.omdome_text()
	health_l.text = str(int(GS.health))
	health_bar.value = GS.health
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(6)
	fill.bg_color = Color("2ecc71") if GS.health > 60 else (Color("f0a500") if GS.health > 30 else GS.RED)
	health_bar.add_theme_stylebox_override("fill", fill)
	coins_l.text = "%d coins" % GS.coins
	abs_l.text = "Olovlig frånvaro: %d/5" % GS.absence
	abs_l.add_theme_color_override("font_color", GS.RED if GS.absence >= 3 else Color("dddddd"))
	stop_l.text = "Stoppade bråk: %d  ·  Kompisar: %d" % [GS.stopped, GS.friend_count()]


func _process(_delta: float) -> void:
	if not root.visible or not GS.started:
		return
	clock_l.text = GS.sched.clock_text()
	period_l.text = GS.sched.period_text()
	room_l.text = GS.map.room_name(GS.map.room_at(GS.player.position)).to_upper()
	obj_l.text = _objective()
	root.visible = true
	arrows.queue_redraw()
	minimap.queue_redraw()
	var wheel_open: bool = GS.wheel.is_open()
	toasts.visible = not wheel_open
	room_l.get_parent().visible = not wheel_open
	obj_l.get_parent().visible = not wheel_open


func _objective() -> String:
	var task: Dictionary = GS.main.player_task
	if task.get("type", "") == "fetch":
		return "Spring till %s och hämta hjälp (vit pil)" % task["adult"].display_name
	if GS.phone.need_adult:
		return "Berätta för en vuxen om mobbningen i chatten"
	for c in GS.cm.conflicts:
		if c.state == "body":
			return "Gå emellan! Ställ dig i cirkeln mellan dem"
	if GS.sched.current_type() == "lesson":
		if GS.sched.needs_class_arrow():
			return "Du ska vara på lektion: %s – skynda dig (gul pil)!" % GS.sched.current()["name"]
		var rb = GS.sched.L.get("rb")
		if rb != null:
			return "%s bryter mot reglerna – gå dit och säg till" % rb.display_name
		return "Lektion: %s – sitt på din plats" % GS.sched.current()["name"]
	if GS.sched.bell:
		return "Det har ringt in – gå till lektionen (gul pil)"
	if GS.cm.active_conflict() != null:
		return "Ett bråk pågår – följ den röda pilen!"
	if GS.phone.inc_active():
		return "Någon blir mobbad i chatten – öppna mobilen (F)"
	if GS.sched.is_lunch():
		return "Lunch! Ät i matsalen och bjud in någon som är ensam"
	return "Rast: skaffa kompisar, spela fotboll och håll utkik"


func _draw_arrows() -> void:
	if not GS.started or GS.player == null:
		return
	var ct := arrows.get_viewport().get_canvas_transform()
	for c in GS.cm.conflicts:
		if c.state == "active" or c.state == "body":
			_edge_arrow(ct * c.pos, GS.RED.lightened(0.1), "!")
	var task: Dictionary = GS.main.player_task
	if task.get("type", "") == "fetch":
		_edge_arrow(ct * task["adult"].position, Color.WHITE, "V")
	if GS.phone.need_adult:
		var ad = GS.cm.nearest_adult(GS.player.position, false)
		if ad != null:
			_edge_arrow(ct * ad.position, Color.WHITE, "V")
	if GS.sched.needs_class_arrow():
		_edge_arrow(ct * GS.sched.class_target(), GS.GOLD, "L")
	var rb = GS.sched.L.get("rb") if GS.sched.L is Dictionary else null
	if rb != null:
		_edge_arrow(ct * rb.position, GS.GOLD, "!")


func _edge_arrow(sp: Vector2, col: Color, label: String) -> void:
	var vs := arrows.size
	var m := 46.0
	var inner := Rect2(Vector2(m, m + 70), vs - Vector2(m * 2, m * 2 + 150))
	if inner.has_point(sp):
		return
	var center := vs / 2.0
	var ang := (sp - center).angle()
	var e := Vector2(clampf(sp.x, m, vs.x - m), clampf(sp.y, 290.0, vs.y - m - 70))
	var pulse := 1.0 + sin(GS.t * 8.0) * 0.08
	var dir := Vector2.from_angle(ang)
	var nrm := dir.orthogonal()
	var tip := e + dir * 30.0 * pulse
	arrows.draw_colored_polygon(PackedVector2Array([tip, e + dir * 8.0 + nrm * 14.0, e + dir * 8.0 - nrm * 14.0]), col)
	arrows.draw_circle(e, 17.0 * pulse, Color.BLACK)
	arrows.draw_arc(e, 17.0 * pulse, 0, TAU, 24, col, 3.0)
	arrows.draw_string(ThemeDB.fallback_font, e + Vector2(-17, 6), label, HORIZONTAL_ALIGNMENT_CENTER, 34, 16, col)


func _toast(text: String, kind: String, secs: float) -> void:
	if toasts == null:
		return
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.04, 0.95) if kind != "bad" else Color(0.16, 0.0, 0.03, 0.95)
	sb.border_color = {"good": GS.GOLD, "bad": GS.RED, "warn": Color("ff5a6e")}.get(kind, Color("888888"))
	sb.border_width_left = 6
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(9)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", GS.GOLD if kind == "good" else Color.WHITE)
	pc.add_child(l)
	toasts.add_child(pc)
	while toasts.get_child_count() > 3:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	var tm := Timer.new()
	tm.wait_time = secs
	tm.one_shot = true
	tm.autostart = true
	tm.timeout.connect(pc.queue_free)
	pc.add_child(tm)
