extends CanvasLayer
## Butiken: spendera coins på rastvärdar, kameror och annat.

const ITEMS := [
	{"id": "rastvakt", "name": "Anställ en rastvakt", "desc": "En till vuxen i gul reflexväst som patrullerar och stoppar bråk.", "price": 40, "max": 4},
	{"id": "posters", "name": "Olweus-affischer", "desc": "Påminner alla om reglerna. Bråk uppstår mer sällan.", "price": 25, "once": true},
	{"id": "bench", "name": "Kompisbänk på skolgården", "desc": "Ensamma elever sätter sig där – lätta att hitta och bjuda in.", "price": 20, "once": true},
	{"id": "fruit", "name": "Frukt och vatten", "desc": "+15 hälsa.", "price": 5},
]
const CAMERA_PRICE := 30

var root: Control
var list: VBoxContainer
var coins_l: Label
var is_open := false


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GS.make_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(660, 0)
	cc.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "BUTIK – gör skolan tryggare"
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color("ff3b52"))
	head.add_child(t)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	coins_l = Label.new()
	coins_l.add_theme_font_size_override("font_size", 22)
	coins_l.add_theme_color_override("font_color", GS.GOLD)
	head.add_child(coins_l)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	v.add_child(list)
	var close := Button.new()
	close.text = "Stäng (Esc)"
	close.pressed.connect(close_shop)
	v.add_child(close)
	root.visible = false


func open() -> void:
	if is_open or GS.modal_count > 0 or GS.ui_block:
		return
	is_open = true
	GS.push_modal()
	_rebuild()
	root.visible = true


func close_shop() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	GS.pop_modal()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("cancel") or event.is_action_pressed("shop")):
		close_shop()
		get_viewport().set_input_as_handled()


func _row(title: String, desc: String, price: int, can: bool, btn_text: String, f: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := Label.new()
	tl.text = "%s  –  %d coins" % [title, price]
	tl.add_theme_color_override("font_color", GS.GOLD)
	v.add_child(tl)
	var dl := Label.new()
	dl.text = desc
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(440, 0)
	dl.add_theme_font_size_override("font_size", 14)
	dl.add_theme_color_override("font_color", Color("cccccc"))
	v.add_child(dl)
	h.add_child(v)
	var b := Button.new()
	b.text = btn_text
	b.disabled = not can
	b.custom_minimum_size = Vector2(120, 0)
	b.pressed.connect(f)
	h.add_child(b)
	list.add_child(h)


func _rebuild() -> void:
	coins_l.text = "%d coins" % GS.coins
	for c in list.get_children():
		c.queue_free()
	for it in ITEMS:
		var id: String = it["id"]
		var price: int = it["price"]
		var owned := false
		var label := "Köp"
		if it.get("once", false) and GS.upgrades.get(id, false):
			owned = true
			label = "Köpt"
		if id == "rastvakt":
			var have: int = GS.upgrades["rastvakter"]
			if have >= int(it["max"]):
				owned = true
				label = "Max"
			else:
				label = "Anställ (%d/%d)" % [have, it["max"]]
		_row(it["name"], it["desc"], price, not owned and GS.coins >= price, label, _buy.bind(id, price))
	for rn in GS.map.CAMERA_ROOMS:
		var has: bool = GS.upgrades["cameras"].has(rn)
		_row("Övervakningskamera: " + rn, "Larmar en vuxen direkt när det blir bråk här, och bråk uppstår mer sällan i rummet.",
			CAMERA_PRICE, not has and GS.coins >= CAMERA_PRICE, "Köpt" if has else "Köp", _buy.bind("cam:" + rn, CAMERA_PRICE))


func _buy(id: String, price: int) -> void:
	if not GS.spend(price):
		GS.toast("Du har inte tillräckligt med coins.", "bad", 3)
		return
	if id.begins_with("cam:"):
		var rn := id.substr(4)
		GS.upgrades["cameras"].append(rn)
		GS.toast("Kamera uppsatt i %s." % rn, "good", 3)
	else:
		match id:
			"rastvakt":
				GS.main.spawn_rastvakt()
				GS.toast("Ny rastvakt anställd!", "good", 3)
			"posters":
				GS.upgrades["posters"] = true
				GS.toast("Olweus-affischer uppsatta. Bråk blir mer sällsynta.", "good", 3)
			"bench":
				GS.upgrades["bench"] = true
				GS.map.queue_redraw()
				GS.toast("Kompisbänken står på skolgården.", "good", 3)
			"fruit":
				GS.change(0, 0, 15)
				GS.toast("Mums! +15 hälsa", "good", 3)
	_rebuild()
