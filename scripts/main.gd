extends Node2D
## Huvudscenen: skapar spelaren, eleverna och de vuxna, och sköter
## vad som händer när spelaren trycker E (prata, ingripa, säga till...).

const NpcScript := preload("res://scripts/npc.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BallScript := preload("res://scripts/ball.gd")

@onready var map: Node2D = $World/SchoolMap
@onready var actors: Node2D = $World/Actors
@onready var overlay: Node2D = $World/Overlay

var students: Array = []
var adults: Array = []
var rektor = null
var player = null
var camera: Camera2D
var hint_target = null
var hint_kind := ""
var player_task: Dictionary = {}


func _ready() -> void:
	GS.main = self
	GS.map = map
	GS.overlay = overlay
	GS.cm = $ConflictManager
	GS.sched = $Schedule
	GS.hud = $HUD
	GS.wheel = $ChoiceWheel
	GS.dialog = $DialogPanel
	GS.quiz = $QuizPanel
	GS.shop = $ShopPanel
	GS.phone = $PhonePanel
	GS.help = $HelpPanel
	$StartScreen.start_pressed.connect(_on_start)
	get_tree().paused = true


func _on_start(pname: String, look: Dictionary) -> void:
	GS.player_name = pname
	player = PlayerScript.new()
	player.display_name = pname
	player.look = look
	actors.add_child(player)
	GS.player = player
	player.position = map.random_point(map.ROOM_YARD)
	player.seat_pos = map.seats[0][7]
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map.WW
	camera.limit_bottom = map.WH
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	player.add_child(camera)
	camera.make_current()
	_spawn_people()
	var ball = BallScript.new()
	actors.add_child(ball)
	GS.ball = ball
	ball.reset()
	GS.started = true
	get_tree().paused = false
	GS.hud.show_hud()
	GS.sched.begin_day()
	GS.toast("Välkommen %s! Du går i klass 7A. Gå till lektionerna i tid, skaffa kompisar och stoppa bråk på rasterna." % pname, "warn", 7)


func _spawn_people() -> void:
	var names: Array = Data.STUDENT_NAMES.duplicate()
	names.shuffle()
	var seats7: Array = map.seats[0].duplicate()
	seats7.remove_at(7)
	var seats8: Array = map.seats[1].duplicate()
	seats7.shuffle()
	seats8.shuffle()
	for i in 20:
		var n = NpcScript.new()
		n.display_name = names[i]
		n.role = "student"
		n.look = GS.make_look(false)
		n.klass = "7A" if i < 10 else "8B"
		n.seat = seats7[i] if i < 10 else seats8[i - 10]
		n.position = map.random_point(map.ROOM_YARD)
		n.speed = randf_range(62.0, 78.0)
		n.idle_t = randf_range(0.0, 3.0)
		actors.add_child(n)
		students.append(n)
	_add_adult("Anna", "teacher", "Lärare", [map.ROOM_CH], map.ROOM_7A)
	_add_adult("Erik", "teacher", "Lärare", [map.ROOM_CV], map.ROOM_8B)
	_add_adult("Sara", "teacher", "Idrottslärare", [map.ROOM_GYM, map.ROOM_YARD], map.ROOM_GYM)
	_add_adult("Johan", "teacher", "Lärare", [map.ROOM_CH, map.ROOM_CV], -1)
	_add_adult("Kim", "rastvakt", "Rastvakt", [map.ROOM_YARD], -1)
	_add_adult("Leila", "rastvakt", "Rastvakt", [map.ROOM_MAT, map.ROOM_CH], -1)
	var maria = _add_adult("Maria", "staff", "Expedition", [], -1)
	maria.is_static = true
	maria.position = map.exp_spot
	maria.state = "static"
	rektor = _add_adult("Birgitta", "rektor", "Rektor", [], -1)
	rektor.is_static = true
	rektor.position = map.rektor_spot
	rektor.state = "static"


func _add_adult(nm: String, role: String, title: String, zone: Array, lesson_room: int):
	var a = NpcScript.new()
	a.display_name = nm
	a.role = role
	a.title = title
	a.look = GS.make_look(true)
	a.zone = zone
	a.lesson_room = lesson_room
	a.size_f = 1.15
	a.speed = 80.0
	a.position = map.random_point(zone[0]) if not zone.is_empty() else map.exp_spot
	actors.add_child(a)
	adults.append(a)
	return a


func spawn_rastvakt() -> void:
	var zones := [[map.ROOM_YARD], [map.ROOM_CV, map.ROOM_CH], [map.ROOM_MAT], [map.ROOM_GYM, map.ROOM_YARD]]
	var i: int = GS.upgrades["rastvakter"]
	var nm: String = Data.EXTRA_RASTVAKT_NAMES[i % Data.EXTRA_RASTVAKT_NAMES.size()]
	var a = _add_adult(nm, "rastvakt", "Rastvakt", zones[i % zones.size()], -1)
	a.position = map.random_point(a.zone[0])
	GS.upgrades["rastvakter"] = i + 1
	a.say("Hej! Jag är ny rastvakt här.", 3.0)


# ---------------- varje bildruta ----------------
func _process(_delta: float) -> void:
	if not GS.started or player == null:
		return
	_separate()
	_find_interaction()
	if player_task.get("type", "") == "fetch":
		var c = player_task["c"]
		var ad = player_task["adult"]
		if c.dead or c.state == "resolved" or c.state == "failed":
			player_task = {}
		elif player.position.distance_to(ad.position) < 70.0:
			player.say("Det är bråk! Kom snabbt!", 2.4, "me")
			GS.cm.dispatch(ad, c, true)
			player_task = {}
			GS.toast("%s är på väg till bråket!" % ad.display_name, "good", 3)


func _separate() -> void:
	for n in actors.get_children():
		if n == player or not (n is Character):
			continue
		if n.get("conflict") != null:
			continue
		var d: Vector2 = player.position - n.position
		var l := d.length()
		var r: float = 22.0 * n.size_f
		if l < r and l > 0.01:
			player.move(d / l * (r - l))


func _find_interaction() -> void:
	hint_target = null
	hint_kind = ""
	if GS.ui_block or GS.modal_count > 0:
		GS.hud.set_hint("")
		return
	var p: Vector2 = player.position
	var txt := ""
	# 1. bråk i närheten
	for c in GS.cm.conflicts:
		if c.state == "active" and p.distance_to(c.pos) < 150.0:
			hint_target = c.a
			hint_kind = "wheel"
			txt = "Ingrip i bråket (valhjulet)"
			break
	# 2. närmaste figur
	if hint_kind == "":
		var best = null
		var bd := 62.0
		for n in actors.get_children():
			if n == player or not (n is Character):
				continue
			var d: float = p.distance_to(n.position)
			if d < bd:
				bd = d
				best = n
		if best != null:
			var active = GS.cm.active_conflict()
			if best.is_adult():
				if GS.phone.need_adult:
					hint_kind = "tell_phone"
					txt = "Berätta för %s om mobbningen i chatten" % best.display_name
				elif best.rule_break != "":
					hint_kind = "rb_adult"
					txt = "Säg till rastvakten %s" % best.display_name
				elif active != null and not best.is_static and active.helper == null:
					hint_kind = "tell_conflict"
					txt = "Be %s stoppa bråket" % best.display_name
				else:
					hint_kind = "adult_talk"
					txt = "Prata med %s" % best.display_name
			else:
				if best.rule_break != "":
					hint_kind = "rb_student"
					txt = "Säg till %s" % best.display_name
				elif best.conflict != null:
					pass
				elif best.state == "lonely":
					hint_kind = "lonely"
					txt = "Bjud in %s att vara med" % best.display_name
				else:
					hint_kind = "talk"
					txt = "Prata med %s" % best.display_name
			if hint_kind != "":
				hint_target = best
	# 3. lunch
	if hint_kind == "" and GS.sched.is_lunch() and p.distance_to(map.counter_spot) < 70.0:
		hint_kind = "eat"
		txt = "Ät lunch"
	GS.hud.set_hint(("[E]  " + txt) if txt != "" else "")


func _unhandled_input(event: InputEvent) -> void:
	if not GS.started or GS.modal_count > 0:
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("shop"):
		GS.shop.open()
	elif event.is_action_pressed("phone"):
		GS.phone.toggle()
	elif event.is_action_pressed("help"):
		GS.help.open()


func interact() -> void:
	if GS.ui_block or GS.modal_count > 0:
		return
	var n = hint_target
	match hint_kind:
		"wheel":
			for c in GS.cm.conflicts:
				if c.state == "active" and player.position.distance_to(c.pos) < 150.0:
					c.dismissed = false
					c.cool = 0.0
					GS.wheel.open_for(c)
					return
		"tell_phone":
			GS.phone.tell_adult(n)
		"rb_adult":
			player.say("Ursäkta! Du behöver hålla uppsikt – det kan bli bråk.", 2.8, "me")
			n.say("Oj, du har rätt. Tack för att du sa till!", 3.0, "good")
			n.fix_rule_break()
			GS.change(0, 3, 0)
			GS.add_coins(5)
			GS.toast("Även vuxna behöver påminnas ibland. +5 coins", "good", 4)
		"tell_conflict":
			var c = GS.cm.active_conflict()
			if c != null:
				player.say("Det är bråk! Kan du hjälpa till?", 2.4, "me")
				GS.cm.dispatch(n, c, true)
				player_task = {}
		"adult_talk":
			_adult_talk(n)
		"rb_student":
			GS.sched.correct_student(n)
		"lonely":
			_invite(n)
		"talk":
			_talk(n)
		"eat":
			GS.sched.eat()


func _adult_talk(n) -> void:
	var lines := {
		"rastvakt": ["Hej %s! Säg till om du ser något bråk.", "Jag håller koll på rasten. Kom till mig om något händer."],
		"teacher": ["Hej %s! Kom i tid till lektionerna, så går det bra.", "Kom ihåg Olweus regler: säg ifrån och berätta för en vuxen."],
		"staff": ["Hej %s! Här på expeditionen kan du alltid få hjälp.", "Behöver du något, %s?"],
		"rektor": ["Hej %s. Vad bra att du kom förbi.", "Jag hoppas att du trivs i skolan, %s."],
	}
	var arr: Array = lines.get(n.role, ["Hej %s!"])
	var s: String = arr.pick_random()
	n.say(s % GS.player_name if s.find("%s") != -1 else s, 3.0)


func _talk(n) -> void:
	if GS.sched.in_lesson_for_player():
		GS.sched.disturb("Ingen pratstund mitt i lektionen, %s!" % GS.player_name)
		return
	var opts: Array = ["Hej! Hur är det?", "Vill du spela fotboll?"]
	var active = GS.cm.active_conflict()
	if n.is_friend and active != null:
		opts.append("Kan du hjälpa mig att stoppa bråket?")
	opts.append("Hejdå!")
	var head: String = n.display_name + (" (din kompis)" if n.is_friend else "") + " – klass " + n.klass
	var greet: String = "%s: Hej %s! Vad vill du?" % [n.display_name, GS.player_name]
	if not n.is_friend:
		greet += "\n\nKompispoäng: %d av 3" % n.friend_pts
	GS.dialog.ask(head, greet, opts, func(i: int): _talk_pick(n, String(opts[i])))


func _talk_pick(n, opt: String) -> void:
	match opt:
		"Hej! Hur är det?":
			player.say("Hej! Hur är det?", 2.2, "me")
			if n.talked:
				n.say("Vi pratade ju nyss!", 2.2)
				return
			n.talked = true
			n.friend_pts += 2 if GS.upgrades["bench"] and randf() < 0.3 else 1
			n.say(String(Data.FRIEND_TALK.pick_random()).replace("{n}", GS.player_name), 2.8)
			n.happy = 3.0
			if n.friend_pts >= 3 and not n.is_friend:
				n.is_friend = true
				GS.change(0, 3, 3)
				GS.stats_changed.emit()
				GS.toast("%s är nu din kompis! Kompisar kan hjälpa dig att stoppa bråk (finns i valhjulet)." % n.display_name, "good", 5)
			else:
				GS.toast("Ni pratade en stund. Prata igen på nästa rast för att bli kompisar.", "info", 3)
		"Vill du spela fotboll?":
			player.say("Vill du spela fotboll?", 2.2, "me")
			if GS.sched.current_type() == "lesson":
				n.say("Nu? Vi har ju lektion!", 2.4)
			else:
				n.say("Ja, kul!", 2.0, "good")
				n.activity = "football"
				n.team = randi() % 2
				n.walk_to(map.pitch.get_center() + Vector2(randf_range(-120, 120), randf_range(-80, 80)), "football")
		"Kan du hjälpa mig att stoppa bråket?":
			var c = GS.cm.active_conflict()
			if c != null:
				player.say("Kan du hjälpa mig att stoppa bråket?", 2.2, "me")
				GS.cm.friend_help(n, c)
		_:
			n.say("Hejdå!", 1.6)


func _invite(n) -> void:
	GS.dialog.ask("%s är ensam" % n.display_name, "%s står ensam och ser ledsen ut. Vad vill du säga?" % n.display_name,
		["Vill du vara med och spela fotboll?", "Vill du hänga med mig?", "Hejdå"], func(i: int):
			if i == 2:
				return
			player.say("Vill du vara med och spela fotboll?" if i == 0 else "Vill du hänga med mig?", 2.4, "me")
			n.say("Ja! Gärna! Tack för att du frågade.", 2.8, "good")
			n.sad = 0.0
			n.happy = 6.0
			n.friend_pts += 2
			if n.friend_pts >= 3 and not n.is_friend:
				n.is_friend = true
				GS.toast("%s är nu din kompis!" % n.display_name, "good", 4)
			if i == 0:
				n.activity = "football"
				n.team = randi() % 2
				n.walk_to(map.pitch.get_center(), "football")
			else:
				n.activity = "follow"
				n.state = "follow"
			GS.change(0, 4, 2)
			GS.add_coins(5)
			GS.toast("Olweus regel 3: Vi ska vara med elever som lätt blir ensamma. +5 coins", "good", 5)
	)
