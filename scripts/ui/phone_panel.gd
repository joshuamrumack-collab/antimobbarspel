extends CanvasLayer
## Mobilen: ibland blir någon mobbad i en gruppchatt. Spelaren kan
## ingripa i chatten eller berätta för en vuxen.

var root: Control
var panel: PanelContainer
var title_l: Label
var log_box: VBoxContainer
var scroll: ScrollContainer
var choice_box: VBoxContainer
var is_open := false
var inc: Dictionary = {}
var need_adult := false
var unread := 0


func _ready() -> void:
	layer = 15
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = GS.make_theme()
	add_child(root)
	panel = PanelContainer.new()
	panel.anchor_left = 0
	panel.anchor_right = 0
	panel.anchor_top = 0
	panel.anchor_bottom = 1
	panel.offset_left = 10
	panel.offset_right = 356
	panel.offset_top = 196
	panel.offset_bottom = -12
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title_l = Label.new()
	title_l.text = "Mobilen"
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)
	var x := Button.new()
	x.text = "X"
	x.pressed.connect(toggle)
	head.add_child(x)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	log_box = VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.add_theme_constant_override("separation", 6)
	scroll.add_child(log_box)
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 5)
	v.add_child(choice_box)
	_sys("Inga nya meddelanden.")
	panel.visible = false


func inc_active() -> bool:
	return not inc.is_empty() and inc["state"] == "active"


func toggle() -> void:
	if not GS.started or GS.modal_count > 0 or GS.ui_block:
		return
	if not is_open and GS.sched.in_lesson_for_player():
		GS.sched.disturb("Lägg undan mobilen, %s! Vi har lektion." % GS.player_name)
		return
	is_open = not is_open
	panel.visible = is_open
	if is_open:
		unread = 0
		GS.hud.set_badge(0)
		_scroll_down()


func _scroll_down() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _msg(who: String, text: String, kind: String) -> void:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(7)
	sb.bg_color = GS.RED if kind == "me" else Color("232327")
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_END if kind == "me" else Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	pc.add_child(v)
	var nl := Label.new()
	nl.text = who + (" (du)" if kind == "me" else "")
	nl.add_theme_font_size_override("font_size", 12)
	nl.add_theme_color_override("font_color", {"bully": Color("ff8a98"), "victim": Color("8ac6ff"), "me": Color("ffd5da")}.get(kind, Color("aaaaaa")))
	v.add_child(nl)
	var tl := Label.new()
	tl.text = text
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(230, 0)
	tl.add_theme_font_size_override("font_size", 14)
	v.add_child(tl)
	log_box.add_child(pc)
	_notify()


func _sys(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("999999"))
	log_box.add_child(l)
	_notify()


func _notify() -> void:
	if is_open:
		_scroll_down()
	elif GS.started and GS.hud != null:
		unread += 1
		GS.hud.set_badge(unread)


func start_incident() -> void:
	var s: Dictionary = Data.DSCEN.pick_random()
	var extra: Array = Data.STUDENT_NAMES.filter(func(n): return n != s["a"] and n != s["v"])
	extra.shuffle()
	var good := ["write", "rule", "support", "private", "report", "shot"]
	var bad := ["like", "share", "mean"]
	bad.shuffle()
	var opts: Array = good + bad.slice(0, 2)
	opts.shuffle()
	inc = {"s": s, "names": [s["a"], s["v"], extra[0], extra[1]], "idx": 0, "t": 0.6, "state": "active", "time": 0.0, "opts": opts, "cool": 0.0}
	need_adult = false
	for c in log_box.get_children():
		c.queue_free()
	title_l.text = String(s["group"])
	_sys("Nya meddelanden i " + String(s["group"]))
	GS.toast("Mobilen plingar! Något händer i gruppchatten %s. Öppna mobilen (F)." % s["group"], "warn", 5)
	_choices()


func _process(delta: float) -> void:
	if inc.is_empty() or not GS.started:
		return
	if GS.sched.current_type() == "lesson":
		return
	inc["cool"] = maxf(0.0, inc["cool"] - delta)
	if inc["state"] == "active":
		inc["time"] += delta
		inc["t"] -= delta
		if inc["t"] <= 0.0:
			var msgs: Array = inc["s"]["msgs"]
			if inc["idx"] < msgs.size():
				var m: Array = msgs[inc["idx"]]
				inc["idx"] += 1
				var who: int = m[0]
				_msg(inc["names"][who], m[1], "bully" if who == 0 else ("victim" if who == 1 else "other"))
				inc["t"] = 3.2
			else:
				inc["t"] = 7.0
				_msg(inc["names"][[0, 2, 3].pick_random()], ["hahaha", "lol", "haha sant", "hon/han tar allt så personligt"].pick_random(), "other")
		if inc["time"] > 110.0:
			_fail()


func _choices() -> void:
	for c in choice_box.get_children():
		c.queue_free()
	if inc.is_empty():
		return
	if inc["state"] == "need_adult":
		var l := Label.new()
		l.text = "Gå till en vuxen och berätta (E)."
		l.add_theme_color_override("font_color", GS.GOLD)
		choice_box.add_child(l)
		return
	if inc["state"] != "active":
		return
	var v: String = inc["s"]["v"]
	for id in inc["opts"]:
		var b := Button.new()
		b.text = String(Data.DOPT[id]["t"]).replace("{v}", v)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_choose.bind(id))
		choice_box.add_child(b)


func _choose(id: String) -> void:
	if inc.is_empty() or inc["state"] != "active" or inc["cool"] > 0.0:
		return
	var o: Dictionary = Data.DOPT[id]
	var v: String = inc["s"]["v"]
	inc["opts"].erase(id)
	if o.has("bad"):
		if o.has("sys"):
			_sys(o["sys"])
		if o.has("msg"):
			_msg(GS.player_name, o["msg"], "me")
		_msg(inc["names"][0], ["haha ja", "se, alla tycker som jag", "hahaha"].pick_random(), "bully")
		_msg(v, "...", "victim")
		inc["cool"] = 1.5
		GS.change(0, -3, 0)
		GS.toast("Tänk efter: " + String(o["bad"]), "bad", 6)
		_choices()
		return
	if o.get("adult", false):
		_sys("Du tog en skärmdump.")
		_need_adult()
		return
	if o.get("priv", false):
		_sys("Privat till %s: Är du okej?" % v)
		_sys("Privat från %s: nej... tack för att du frågar." % v)
	if o.has("sys"):
		_sys(o["sys"])
	if o.has("msg"):
		_msg(GS.player_name, String(o["msg"]).replace("{v}", v), "me")
	if randf() < float(o["ch"]):
		_msg(inc["names"][0], "ok sorry... det var dumt. jag tar bort det", "bully")
		_sys("Ett meddelande togs bort.")
		_msg(v, "tack %s!" % GS.player_name, "victim")
		_success("Snyggt! Du stoppade mobbningen i chatten. +10 coins")
	else:
		_msg(inc["names"][0], ["lägg dig inte i", "bry dig inte", "vem frågade dig?"].pick_random(), "bully")
		GS.toast("Orden räckte inte. Berätta för en vuxen – gå fram till en lärare eller rastvakt och tryck E.", "warn", 6)
		_need_adult()


func _need_adult() -> void:
	inc["state"] = "need_adult"
	need_adult = true
	_choices()


func tell_adult(ad) -> void:
	if not need_adult:
		return
	GS.player.say("Någon blir mobbad i gruppchatten. Här är en skärmdump.", 3.0, "me")
	ad.say("Tack för att du berättade! Jag tar hand om det i dag.", 3.2, "good")
	_sys("En vuxen har fått veta. Mobbningen i chatten stoppades.")
	_msg(inc["s"]["v"], "tack för att du berättade för en vuxen", "victim")
	_success("Rätt gjort! Olweus regel 4: berätta för en vuxen. +10 coins")


func _success(msg: String) -> void:
	inc["state"] = "done"
	need_adult = false
	GS.add_coins(10)
	GS.stopped += 1
	GS.change(0, 3, 0)
	GS.toast(msg, "good", 5)
	_choices()
	inc = {}


func _fail() -> void:
	_sys("%s lämnade gruppen." % inc["s"]["v"])
	GS.missed += 1
	GS.stats_changed.emit()
	GS.toast("Ingen sa ifrån i chatten. %s lämnade gruppen. Öppna mobilen när den plingar!" % inc["s"]["v"], "bad", 5)
	inc = {}
	need_adult = false
	_choices()
