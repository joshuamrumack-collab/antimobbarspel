extends Node
## Skolschemat: lektioner, raster, lunch, sen ankomst, frånvaro, rektorn,
## prov och elever/rastvärdar som bryter mot regler.

const MIN_PER_SEC := 0.6667        # 1 spelminut = 1,5 sekunder
const DAYS := ["Måndag", "Tisdag", "Onsdag", "Torsdag", "Fredag"]
const LATE_GRACE := 4.0            # minuter innan man räknas som sen
const BELL_BEFORE := 6.0           # det ringer in så här många minuter innan lektionen
const ABSENCE_REKTOR := 3
const ABSENCE_SUSPEND := 5

var periods := [
	{"name": "Morgon (fritt)", "type": "break", "s": 0, "e": 10},
	{"name": "Svenska", "type": "lesson", "s": 10, "e": 50, "room": 0, "subj": "svenska"},
	{"name": "Rast", "type": "break", "s": 50, "e": 75},
	{"name": "Matematik", "type": "lesson", "s": 75, "e": 115, "room": 0, "subj": "matte"},
	{"name": "Rast", "type": "break", "s": 115, "e": 140},
	{"name": "Idrott", "type": "lesson", "s": 140, "e": 180, "room": 3, "subj": ""},
	{"name": "Lunch", "type": "lunch", "s": 180, "e": 220},
	{"name": "SO – Olweus", "type": "lesson", "s": 220, "e": 260, "room": 0, "subj": "olweus"},
	{"name": "Rast", "type": "break", "s": 260, "e": 285},
	{"name": "NO", "type": "lesson", "s": 285, "e": 325, "room": 0, "subj": "no"},
]
var minute := 0.0
var pidx := -1
var running := false
var bell := false
var L := {}
var ate := false
var phone_minute := 60.0
var phone_done := false
var health_handled := false


func _process(delta: float) -> void:
	if not running or not GS.started:
		return
	minute += delta * MIN_PER_SEC
	var day_end: float = periods[-1]["e"]
	if minute >= day_end:
		running = false
		_lesson_end_if_needed()
		_end_day(false)
		return
	var idx := _period_index()
	if idx != pidx:
		_enter(idx)
	var p: Dictionary = periods[pidx]
	if p["type"] != "lesson" and not bell and pidx + 1 < periods.size() and periods[pidx + 1]["type"] == "lesson" and float(p["e"]) - minute <= BELL_BEFORE:
		bell = true
		_ring(periods[pidx + 1])
	if p["type"] == "lesson":
		_lesson_tick(delta, p)
	if not phone_done and minute >= phone_minute and p["type"] != "lesson":
		phone_done = true
		GS.phone.start_incident()


func _period_index() -> int:
	for i in periods.size():
		if minute >= float(periods[i]["s"]) and minute < float(periods[i]["e"]):
			return i
	return periods.size() - 1


func current() -> Dictionary:
	if pidx < 0:
		return periods[0]
	return periods[pidx]


func current_type() -> String:
	return current()["type"]


func is_lunch() -> bool:
	return current_type() == "lunch"


func clock_text() -> String:
	var total := 480 + int(minute)
	return "%s  %02d:%02d" % [DAYS[GS.day % 5], total / 60, total % 60]


func period_text() -> String:
	var p := current()
	return "%s  (%d min kvar)" % [p["name"], maxi(0, int(ceil(float(p["e"]) - minute)))]


# ---------------- perioder ----------------
func _enter(idx: int) -> void:
	_lesson_end_if_needed()
	pidx = idx
	bell = false
	var p: Dictionary = periods[idx]
	if p["type"] == "lesson":
		_start_lesson(p)
	else:
		_start_break(p["type"] == "lunch")


func _ring(next: Dictionary) -> void:
	var room_name: String = GS.map.room_name(next["room"])
	GS.toast("RRRING! Det ringer in! Lektionen %s börjar om %d minuter i %s. Följ den gula pilen." % [next["name"], int(BELL_BEFORE), room_name], "warn", 6)
	for n in GS.main.students:
		if n.conflict == null:
			_send_to_lesson(n, next)


func _send_to_lesson(n, p: Dictionary) -> void:
	if n.activity == "lesson" or n.activity == "gym":
		return
	n.lonely_reset()
	n.rule_break = ""
	n.holding_phone = false
	n.respond_c = null
	var room: int = p["room"]
	if n.klass == "7A" and room == GS.map.ROOM_GYM:
		n.activity = "gym"
		n.walk_to(GS.map.random_point(GS.map.ROOM_GYM), "idle", true)
	else:
		n.activity = "lesson"
		n.walk_to(n.seat, "seat", true)


func _start_lesson(p: Dictionary) -> void:
	GS.cm.break_active = false
	GS.cm.end_all()
	GS.ball.visible = false
	for n in GS.main.students:
		_send_to_lesson(n, p)
		# elever som är långt borta (utanför skärmen) hamnar direkt på sin plats
		if n.state == "walk" and n.position.distance_to(GS.player.position) > 800.0:
			if n.then_state == "seat":
				n.path.clear()
				n.position = n.seat
				n.state = "seat"
			elif n.activity == "gym":
				n.path.clear()
				n.position = GS.map.random_point(GS.map.ROOM_GYM)
				n.state = "idle"
	for ad in GS.main.adults:
		ad.go_lesson(p)
	L = {"p": p, "arrived": false, "seated_t": 0.0, "disturb_t": 0.0, "out_t": 0.0, "warned_out": false,
		"left": false, "test": false, "rb": null, "rb_t": 0.0, "rb_spawn": randf_range(12.0, 26.0), "rb_done": false}
	GS.main.player_task = {}


func _start_break(lunch: bool) -> void:
	GS.cm.break_active = true
	GS.cm.spawn_t = maxf(GS.cm.spawn_t, randf_range(12.0, 25.0))
	GS.ball.visible = true
	GS.ball.reset()
	GS.player.sitting = false
	L = {}
	var studs: Array = GS.main.students.duplicate()
	studs.shuffle()
	var foot := 0
	for n in studs:
		n.lonely_reset()
		n.talked = false
		n.rule_break = ""
		n.holding_phone = false
		if n.conflict != null:
			continue
		if lunch and randf() < 0.6:
			n.activity = "lunch"
			n.walk_to(GS.map.lunch_spots.pick_random() + Vector2(randf_range(-6, 6), 0), "eat")
		elif foot < 8 and randf() < 0.45:
			n.activity = "football"
			n.team = foot % 2
			foot += 1
			n.walk_to(GS.map.pitch.get_center() + Vector2(randf_range(-150, 150), randf_range(-100, 100)), "football")
		else:
			n.activity = "wander"
			n.state = "idle"
			n.idle_t = randf_range(0.2, 2.0)
	# ensamma elever (Olweus regel 3)
	var wanderers: Array = studs.filter(func(n): return n.activity == "wander" and not n.is_friend)
	wanderers.shuffle()
	var lonely_n := 1 if randf() < 0.5 else 2
	for i in mini(lonely_n, wanderers.size()):
		var n = wanderers[i]
		n.activity = "lonely"
		var spot: Vector2
		if GS.upgrades["bench"]:
			spot = GS.map.bench_spot + Vector2(-40 + i * 80, 0)
		else:
			spot = GS.map.random_point([GS.map.ROOM_YARD, GS.map.ROOM_CH, GS.map.ROOM_MAT].pick_random())
		n.walk_to(spot, "lonely")
	for ad in GS.main.adults:
		ad.go_break()
	# ibland bryter en rastvakt mot reglerna
	if randf() < 0.45:
		var rv: Array = GS.main.adults.filter(func(a): return a.role == "rastvakt")
		if not rv.is_empty():
			rv.pick_random().start_rule_break()


# ---------------- lektioner ----------------
func in_lesson_for_player() -> bool:
	return current_type() == "lesson" and not L.is_empty() and L["arrived"] and GS.map.room_at(GS.player.position) == int(L["p"]["room"])


func needs_class_arrow() -> bool:
	var p := current()
	if p["type"] == "lesson":
		if L.is_empty():
			return false
		return not L["arrived"] or GS.map.room_at(GS.player.position) != int(p["room"])
	return bell


func class_target() -> Vector2:
	var p := current()
	if p["type"] != "lesson" and pidx + 1 < periods.size():
		p = periods[pidx + 1]
	if p.get("room", 0) == GS.map.ROOM_GYM:
		return GS.map.teacher_spot[GS.map.ROOM_GYM]
	return GS.player.seat_pos


func lesson_teacher(p: Dictionary):
	for ad in GS.main.adults:
		if ad.lesson_room == int(p.get("room", -1)) and ad.role == "teacher" and ad.state == "teach":
			return ad
	for ad in GS.main.adults:
		if ad.lesson_room == int(p.get("room", -1)) and ad.role == "teacher":
			return ad
	return null


func _lesson_tick(delta: float, p: Dictionary) -> void:
	if L.is_empty():
		return
	var pl = GS.player
	var room: int = p["room"]
	var in_room: bool = GS.map.room_at(pl.position) == room
	if not L["arrived"]:
		if in_room:
			L["arrived"] = true
			if minute > float(p["s"]) + LATE_GRACE:
				_late_dialog(p)
			else:
				GS.change(0, 2, 0)
				GS.toast("Du kom i tid till %s. Bra! (+omdöme)" % p["name"], "good", 3)
		return
	if not in_room:
		pl.sitting = false
		L["out_t"] += delta
		if not L["warned_out"]:
			L["warned_out"] = true
			GS.toast("Du har lämnat lektionen! Gå tillbaka direkt.", "warn", 4)
		if L["out_t"] > 10.0 and not L["left"]:
			L["left"] = true
			add_absence("lämnade lektionen")
			GS.change(-3, -5, -4)
		return
	L["out_t"] = 0.0
	L["warned_out"] = false
	var seated := true
	if room != GS.map.ROOM_GYM:
		if pl.position.distance_to(pl.seat_pos) < 22.0 and not pl.moving:
			pl.position = pl.seat_pos
			pl.sitting = true
			pl.facing = 0.0
		seated = pl.sitting
	if seated:
		L["seated_t"] += delta
		L["disturb_t"] = 0.0
	elif L["rb"] == null:
		L["disturb_t"] += delta
		if L["disturb_t"] > 7.0:
			L["disturb_t"] = 0.0
			disturb("Sätt dig på din plats, %s! Du stör lektionen." % GS.player_name)
	if not L["test"] and L["seated_t"] > 6.0 and room != GS.map.ROOM_GYM:
		L["test"] = true
		_maybe_test(p)
	_rb_tick(delta, p)


func disturb(msg: String) -> void:
	var tch = lesson_teacher(current())
	if tch != null:
		tch.say(msg, 3.0, "mean")
	GS.change(-1, -6, 0)
	GS.toast("Negativt omdöme: du störde lektionen.", "bad", 4)


func _late_dialog(p: Dictionary) -> void:
	var tch = lesson_teacher(p)
	var tname: String = tch.display_name if tch != null else "Läraren"
	if tch != null:
		tch.say("Du är sen, %s." % GS.player_name, 3.0)
	var late_min := int(minute - float(p["s"]))
	GS.dialog.ask("Du kommer för sent!", "%s: Lektionen började för %d minuter sedan. Vad säger du?" % [tname, late_min],
		["Förlåt att jag är sen.", "Det var inte mitt fel!"], func(i: int):
			if i == 1:
				GS.change(0, -3, 0)
				GS.dialog.ask("Du kommer för sent!", "%s: Du behöver ändå be om ursäkt när du kommer sent." % tname,
					["Förlåt att jag är sen."], func(_j: int): _apologize())
			else:
				_apologize()
	)


func _apologize() -> void:
	GS.player.say("Förlåt att jag är sen.", 2.5, "me")
	GS.change(-3, -4, -6)
	add_absence("sen ankomst")


func add_absence(reason: String) -> void:
	GS.absence += 1
	GS.stats_changed.emit()
	GS.toast("Olovlig frånvaro registrerad (%s). Frånvaro: %d av %d." % [reason, GS.absence, ABSENCE_SUSPEND], "bad", 5)
	call_deferred("_check_absence")


func _check_absence() -> void:
	if GS.absence >= ABSENCE_SUSPEND:
		_suspend()
	elif GS.absence >= ABSENCE_REKTOR and GS.rektor_level == 0:
		GS.rektor_level = 1
		_to_rektor()


func _to_rektor() -> void:
	GS.player.teleport(GS.map.office_spot)
	var rk = GS.main.rektor
	if rk != null:
		rk.say("Välkommen in, %s." % GS.player_name, 3.0)
	GS.dialog.ask("Du har skickats till rektorn",
		"Rektor Birgitta: Hej %s. Du har %d olovliga frånvaron. Det är för mycket. Om frånvaron fortsätter kan du bli avstängd. Hur ska du göra framöver?" % [GS.player_name, GS.absence],
		["Jag lovar att komma i tid till lektionerna.", "Jag vet inte..."], func(i: int):
			if i == 0:
				GS.change(0, 2, 0)
				if rk != null:
					rk.say("Bra. Jag tror på dig!", 3.0, "good")
			else:
				GS.change(0, -2, -3)
				if rk != null:
					rk.say("Vi pratar med dina föräldrar.", 3.0)
			GS.toast("Skynda dig tillbaka till skolan och lektionerna!", "warn", 4)
	)


func _suspend() -> void:
	GS.cm.end_all()
	GS.dialog.ask("AVSTÄNGD",
		"Rektor Birgitta: Du har %d olovliga frånvaron trots varningen. Du blir avstängd resten av dagen. Vi kontaktar dina föräldrar. I morgon får du en ny chans." % GS.absence,
		["Okej... Jag ska skärpa mig."], func(_i: int):
			GS.absence = 0
			GS.rektor_level = 0
			GS.change(-10, -15, -10)
			running = false
			_end_day(true)
	)


func _lesson_end_if_needed() -> void:
	if pidx < 0 or L.is_empty():
		return
	var p: Dictionary = periods[pidx]
	if p["type"] != "lesson":
		return
	if not L["arrived"]:
		add_absence("skolk – du kom aldrig till %s" % p["name"])
		GS.change(-6, -8, -8)
	var rb = L["rb"]
	if rb != null:
		rb.rule_break = ""
		rb.holding_phone = false
	GS.player.sitting = false
	L = {}


func _maybe_test(p: Dictionary) -> void:
	var subj: String = p["subj"]
	if subj == "olweus":
		GS.quiz.run("Kunskapsprov: Olweus", "Hur ska man agera? Välj det bästa svaret.", Data.pick_questions(Data.OLWEUS_Q, 5), _test_done)
	elif randf() < 0.2:
		GS.quiz.run("Överraskningsprov om Olweus!", "Läraren delar ut ett kort prov om hur man ska agera.", Data.pick_questions(Data.OLWEUS_Q, 3), _test_done)
	elif randf() < 0.5 and Data.SUBJECT_Q.has(subj) and not Data.SUBJECT_Q[subj].is_empty():
		GS.quiz.run("Prov i %s" % p["name"], "Svara så gott du kan!", Data.pick_questions(Data.SUBJECT_Q[subj], 3), _test_done)


func _test_done(score: int, total: int) -> void:
	var r := float(score) / maxf(1.0, float(total))
	if r >= 0.8:
		GS.change(6, 3, 0)
		GS.add_coins(10)
		GS.toast("Toppen! %d av %d rätt. Betyget och omdömet går upp. +10 coins" % [score, total], "good", 5)
	elif r >= 0.5:
		GS.change(2, 1, 0)
		GS.toast("Godkänt: %d av %d rätt." % [score, total], "info", 4)
	else:
		GS.change(-4, 0, 0)
		GS.toast("%d av %d rätt. Plugga lite mer till nästa gång!" % [score, total], "bad", 4)


# ---------------- elever som bryter mot regler ----------------
func _rb_tick(delta: float, p: Dictionary) -> void:
	if L["rb_done"]:
		return
	var rb = L["rb"]
	if rb == null:
		if L["seated_t"] > L["rb_spawn"] or (p["room"] == GS.map.ROOM_GYM and L["out_t"] == 0.0 and minute > float(p["s"]) + 12.0):
			L["rb_done"] = randf() > 0.65
			if L["rb_done"]:
				return
			_spawn_rb(p)
		return
	L["rb_t"] += delta
	if rb.rule_break == "phone" and L["rb_t"] > 25.0:
		var tch = lesson_teacher(p)
		if tch != null:
			tch.say("%s, lägg undan mobilen!" % rb.display_name, 3.0)
		rb.rule_break = ""
		rb.holding_phone = false
		L["rb"] = null
		L["rb_done"] = true


func _spawn_rb(p: Dictionary) -> void:
	var room: int = p["room"]
	var cands: Array = GS.main.students.filter(func(n): return n.klass == "7A" and (n.state == "seat" or (room == GS.map.ROOM_GYM and n.activity == "gym")))
	if cands.is_empty():
		L["rb_done"] = true
		return
	var n = cands.pick_random()
	if room != GS.map.ROOM_GYM and randf() < 0.55:
		n.rule_break = "phone"
		n.holding_phone = true
		n.say("*smyger med mobilen*", 3.0)
		GS.toast("%s smyger med mobilen under lektionen. Gå dit och säg till (E)." % n.display_name, "warn", 5)
	else:
		n.rule_break = "skolk"
		n.activity = "skolk"
		n.walk_to(GS.map.class_door[room], "skolk_out")
		n.say("Jag drar härifrån...", 2.5)
		GS.toast("%s försöker skolka! Hinn ifatt och säg till (E)." % n.display_name, "warn", 5)
	L["rb"] = n
	L["rb_t"] = 0.0


func on_skolk_escaped(n) -> void:
	n.rule_break = ""
	n.activity = "wander"
	n.state = "idle"
	n.idle_t = 1.0
	if not L.is_empty() and L["rb"] == n:
		var tch = lesson_teacher(L["p"])
		if tch != null:
			tch.say("Var tog %s vägen?" % n.display_name, 3.0)
		L["rb"] = null
		L["rb_done"] = true
		GS.toast("%s skolkade. Nästa gång – hinn fram och säg till!" % n.display_name, "info", 4)


func correct_student(n) -> void:
	if n.rule_break == "phone":
		GS.player.say("Lägg undan mobilen, vi har lektion.", 2.6, "me")
		n.holding_phone = false
		n.say("Okej, okej. Förlåt.", 2.4)
	else:
		GS.player.say("Kom tillbaka, du missar ju lektionen!", 2.6, "me")
		n.say("Okej... du har rätt.", 2.4)
		n.activity = "gym" if current().get("room", 0) == GS.map.ROOM_GYM else "lesson"
		if n.activity == "lesson":
			n.walk_to(n.seat, "seat")
		else:
			n.state = "idle"
	n.rule_break = ""
	if not L.is_empty():
		L["rb"] = null
		L["rb_done"] = true
	GS.change(0, 4, 0)
	GS.add_coins(5)
	GS.toast("Bra att du sa till! +omdöme, +5 coins", "good", 4)


# ---------------- lunch, hälsa, dagar ----------------
func eat() -> void:
	if ate:
		GS.toast("Du har redan ätit lunch i dag.", "info", 3)
		return
	ate = true
	GS.player.say("Mums!", 2.0, "me")
	GS.player.happy = 3.0
	GS.change(0, 0, 25)
	GS.toast("Du åt lunch. +25 hälsa", "good", 3)


func health_out() -> void:
	if health_handled or not running:
		return
	health_handled = true
	GS.dialog.ask("Du mår inte bra", "Skolsköterskan: Du är helt slut och behöver vila. Du får gå hem resten av dagen. Ät lunch och sov ordentligt!",
		["Okej"], func(_i: int):
			GS.health = 70.0
			GS.stats_changed.emit()
			running = false
			_end_day(true)
	)


func _end_day(skip_summary: bool) -> void:
	running = false
	GS.cm.break_active = false
	GS.cm.end_all()
	var txt := "Stoppade bråk totalt: %d\nMissade bråk: %d\nKompisar: %d\nFrånvaro: %d av %d\nBetyg: %s\nOmdöme: %s\nHälsa: %d\nCoins: %d" % [
		GS.stopped, GS.missed, GS.friend_count(), GS.absence, ABSENCE_SUSPEND, GS.grade_letter(), GS.omdome_text(), int(GS.health), GS.coins]
	var title := "%s är slut!" % DAYS[GS.day % 5] if not skip_summary else "Dagen är slut"
	GS.dialog.ask(title, txt, ["Nästa skoldag"], func(_i: int): new_day(true))


func begin_day() -> void:
	new_day(false)


func new_day(next: bool) -> void:
	if next:
		GS.day += 1
		GS.change(0, 0, 15)
	minute = 0.0
	pidx = -1
	bell = false
	ate = false
	health_handled = false
	phone_done = false
	var breaks: Array = periods.filter(func(p): return p["type"] != "lesson")
	var bp: Dictionary = breaks.pick_random()
	phone_minute = randf_range(float(bp["s"]) + 2.0, float(bp["e"]) - 6.0)
	L = {}
	GS.player.teleport(GS.map.random_point(GS.map.ROOM_YARD))
	for n in GS.main.students:
		n.position = GS.map.random_point(GS.map.ROOM_YARD)
		n.path.clear()
		n.conflict = null
		n.activity = "wander"
		n.state = "idle"
	running = true
	GS.toast("%s – en ny skoldag börjar! Första lektionen: Svenska i Klassrum 7A kl. 08:10." % DAYS[GS.day % 5], "info", 5)
