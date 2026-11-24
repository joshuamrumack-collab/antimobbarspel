extends CanvasLayer
## Dialogruta med knappar. Pausar spelet medan den visas.
## GS.dialog.ask("Rubrik", "Text", ["Val 1", "Val 2"], func(i): ...)

var root: Control
var box: PanelContainer
var title_l: Label
var text_l: Label
var btns: VBoxContainer
var cb: Callable
var queue: Array = []
var showing := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GS.make_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	box = PanelContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	cc.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	title_l = Label.new()
	title_l.add_theme_font_size_override("font_size", 24)
	title_l.add_theme_color_override("font_color", Color("ff3b52"))
	v.add_child(title_l)
	text_l = Label.new()
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.custom_minimum_size = Vector2(530, 0)
	v.add_child(text_l)
	btns = VBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)
	root.visible = false


func ask(title: String, text: String, options: Array, callback: Callable = Callable()) -> void:
	if showing:
		queue.append([title, text, options, callback])
		return
	showing = true
	GS.push_modal()
	title_l.text = title
	text_l.text = text
	cb = callback
	for c in btns.get_children():
		c.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.pressed.connect(_pick.bind(i))
		btns.add_child(b)
	root.visible = true


func _pick(i: int) -> void:
	root.visible = false
	showing = false
	var f := cb
	cb = Callable()
	GS.pop_modal()
	if f.is_valid():
		f.call(i)
	if not showing and not queue.is_empty():
		var q: Array = queue.pop_front()
		ask(q[0], q[1], q[2], q[3])
