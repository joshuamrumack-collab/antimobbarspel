extends CanvasLayer
## Prov: Olweus-kunskapsprov och ämnesprov. Visar en fråga i taget.

var root: Control
var title_l: Label
var q_l: Label
var info_l: Label
var ans_box: VBoxContainer
var next_btn: Button
var questions: Array = []
var qi := 0
var score := 0
var done_cb: Callable
var correct_idx := 0
var answered := false


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GS.make_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	cc.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	title_l = Label.new()
	title_l.add_theme_font_size_override("font_size", 24)
	title_l.add_theme_color_override("font_color", Color("ff3b52"))
	v.add_child(title_l)
	q_l = Label.new()
	q_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_l.custom_minimum_size = Vector2(610, 0)
	q_l.add_theme_font_size_override("font_size", 20)
	v.add_child(q_l)
	ans_box = VBoxContainer.new()
	ans_box.add_theme_constant_override("separation", 8)
	v.add_child(ans_box)
	info_l = Label.new()
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_l.custom_minimum_size = Vector2(610, 0)
	v.add_child(info_l)
	next_btn = Button.new()
	next_btn.text = "Nästa fråga"
	next_btn.pressed.connect(_next)
	v.add_child(next_btn)
	root.visible = false


func run(title: String, intro: String, qs: Array, on_done: Callable) -> void:
	if qs.is_empty():
		return
	questions = qs
	qi = 0
	score = 0
	done_cb = on_done
	title_l.text = title
	GS.push_modal()
	root.visible = true
	info_l.text = intro
	_show()


func _show() -> void:
	answered = false
	var q: Dictionary = questions[qi]
	q_l.text = "Fråga %d av %d: %s" % [qi + 1, questions.size(), q["q"]]
	for c in ans_box.get_children():
		c.queue_free()
	var order := range(q["a"].size())
	order.shuffle()
	for k in order.size():
		var idx: int = order[k]
		if idx == int(q["c"]):
			correct_idx = k
		var b := Button.new()
		b.text = q["a"][idx]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_answer.bind(k))
		ans_box.add_child(b)
	next_btn.visible = false
	if qi > 0:
		info_l.text = ""


func _answer(k: int) -> void:
	if answered:
		return
	answered = true
	var q: Dictionary = questions[qi]
	var buttons := ans_box.get_children()
	for i in buttons.size():
		var b: Button = buttons[i]
		b.disabled = true
		if i == correct_idx:
			b.text = "RÄTT: " + b.text
	if k == correct_idx:
		score += 1
		info_l.text = "Rätt! " + String(q.get("why", ""))
		info_l.add_theme_color_override("font_color", GS.GOLD)
	else:
		info_l.text = "Fel. " + String(q.get("why", "Det rätta svaret är markerat."))
		info_l.add_theme_color_override("font_color", Color("ff8a98"))
	next_btn.text = "Nästa fråga" if qi + 1 < questions.size() else "Lämna in provet"
	next_btn.visible = true


func _next() -> void:
	qi += 1
	if qi < questions.size():
		_show()
		return
	root.visible = false
	info_l.text = ""
	GS.pop_modal()
	if done_cb.is_valid():
		done_cb.call(score, questions.size())
