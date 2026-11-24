extends CanvasLayer
## Startsidan: skapa din karaktär (namn och utseende) innan spelet börjar.

signal start_pressed(pname: String, look: Dictionary)

const CharScript := preload("res://scripts/character.gd")

var root: Control
var name_in: LineEdit
var preview: Node2D
var sel := {"skin": 1, "style": 0, "hair": 1, "shirt": 0, "pants": 0, "acc": 0}
var rows := {}


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GS.make_theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("0d0003")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(980, 0)
	cc.add_child(v)
	var title := Label.new()
	title.text = "ANTI MOBBAR SPEL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_shadow_color", GS.RED)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "SE BRÅKET  ·  SÄG IFRÅN  ·  GÅ EMELLAN  ·  KOM I TID"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("ff5a6e"))
	v.add_child(sub)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	# förhandsvisning
	var pv_panel := PanelContainer.new()
	pv_panel.custom_minimum_size = Vector2(300, 330)
	h.add_child(pv_panel)
	var pv_area := Control.new()
	pv_area.custom_minimum_size = Vector2(270, 300)
	pv_panel.add_child(pv_area)
	pv_area.draw.connect(func():
		pv_area.draw_circle(Vector2(135, 135), 105, Color(0.78, 0.06, 0.18, 0.2))
	)
	preview = CharScript.new()
	preview.position = Vector2(135, 200)
	preview.size_f = 4.2
	preview.role = "player"
	pv_area.add_child(preview)
	# formulär
	var form := PanelContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(form)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 6)
	form.add_child(fv)
	fv.add_child(_head("Namn"))
	name_in = LineEdit.new()
	name_in.placeholder_text = "Skriv ditt namn..."
	name_in.max_length = 14
	name_in.text_submitted.connect(func(_t): _start())
	fv.add_child(name_in)
	fv.add_child(_head("Hudfärg"))
	fv.add_child(_swatches("skin", GS.SKINS))
	fv.add_child(_head("Frisyr"))
	fv.add_child(_buttons("style", GS.STYLE_NAMES))
	fv.add_child(_head("Hårfärg / kepsfärg"))
	fv.add_child(_swatches("hair", GS.HAIRS))
	fv.add_child(_head("Tröja"))
	fv.add_child(_swatches("shirt", GS.SHIRTS))
	fv.add_child(_head("Byxor"))
	fv.add_child(_swatches("pants", GS.PANTS))
	fv.add_child(_head("Detalj"))
	fv.add_child(_buttons("acc", GS.ACC_NAMES))
	# regler och start
	var rp := PanelContainer.new()
	v.add_child(rp)
	var rv := VBoxContainer.new()
	rp.add_child(rv)
	rv.add_child(_head("Olweus fyra regler mot mobbning"))
	var rules := Label.new()
	rules.text = "1. Vi ska inte mobba andra.\n2. Vi ska försöka hjälpa elever som blir utsatta för mobbning.\n3. Vi ska vara med elever som lätt blir ensamma.\n4. Om vi vet att någon blir mobbad ska vi berätta det för en vuxen i skolan och för en vuxen hemma."
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(940, 0)
	rv.add_child(rules)
	var info := Label.new()
	info.text = "Du går i klass 7A. Kom i tid till lektionerna, skaffa kompisar och stoppa bråk på rasterna. Varje stoppat bråk ger 10 coins som du kan använda i butiken.\nWASD/pilar = gå  ·  E = prata/ingripa  ·  B = butik  ·  F = mobil  ·  H = hjälp"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(940, 0)
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color("bbbbbb"))
	rv.add_child(info)
	var start := Button.new()
	start.text = "STARTA SPELET"
	start.add_theme_font_size_override("font_size", 28)
	start.custom_minimum_size = Vector2(0, 64)
	start.pressed.connect(_start)
	v.add_child(start)
	var credit := Label.new()
	credit.text = "Skapad av DorkTeach"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_color_override("font_color", Color("777777"))
	v.add_child(credit)
	_update_preview()


func _head(t: String) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("ff3b52"))
	return l


func _swatches(key: String, cols: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	rows[key] = h
	for i in cols.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.pressed.connect(_pick.bind(key, i))
		h.add_child(b)
	_style_row(key)
	return h


func _buttons(key: String, names: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	rows[key] = h
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_pick.bind(key, i))
		h.add_child(b)
	_style_row(key)
	return h


func _style_row(key: String) -> void:
	var h: HBoxContainer = rows[key]
	var cols: Array = []
	match key:
		"skin": cols = GS.SKINS
		"hair": cols = GS.HAIRS
		"shirt": cols = GS.SHIRTS
		"pants": cols = GS.PANTS
	for i in h.get_child_count():
		var b: Button = h.get_child(i)
		var on: bool = sel[key] == i
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(19 if not cols.is_empty() else 8)
		sb.set_border_width_all(3)
		sb.border_color = Color.WHITE if on else Color("333333")
		sb.bg_color = cols[i] if not cols.is_empty() else (GS.RED if on else Color("1a1a1d"))
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)


func _pick(key: String, i: int) -> void:
	sel[key] = i
	_style_row(key)
	_update_preview()


func _look() -> Dictionary:
	return {"skin": GS.SKINS[sel["skin"]], "style": GS.STYLES[sel["style"]], "hair": GS.HAIRS[sel["hair"]],
		"shirt": GS.SHIRTS[sel["shirt"]], "pants": GS.PANTS[sel["pants"]], "acc": GS.ACCS[sel["acc"]], "beard": false}


func _update_preview() -> void:
	preview.look = _look()
	preview.queue_redraw()


func _process(delta: float) -> void:
	if root.visible:
		preview.facing = sin(GS.t * 0.8) * 0.8
		preview.tick_base(delta)


func _start() -> void:
	var nm := name_in.text.strip_edges()
	if nm == "":
		nm = "Spelaren"
	GS.register_look(sel["skin"], sel["style"], sel["hair"], sel["shirt"])
	root.visible = false
	start_pressed.emit(nm, _look())
	queue_free()
