extends Node
## Skapar och styr bråk mellan elever. Bråk uppstår bara på raster och lunch,
## och mer sällan än tidigare (35–60 sekunder mellan varje bråk, ca 3 per skoldag).

class Conflict:
	var a
	var b
	var scen: Dictionary
	var pos := Vector2.ZERO
	var room := -1
	var state := "gather"     # gather, active, body, resolved, failed
	var gt := 0.0
	var time := 0.0
	var li := 0
	var lj := 0
	var line_t := 0.0
	var esc := 0
	var bonus := 0
	var min_esc := 0
	var cool := 0.0
	var dismissed := false
	var body_p := 0.0
	var push := 0.0
	var shove_t := 1.0
	var flip := false
	var options: Array = []
	var end_t := 0.0
	var dead := false
	var helper = null
	var helper_kind := ""
	var player_credit := false
	var auto_t := 0.0
	var cam_alerted := false

var conflicts: Array = []
var break_active := false
var spawn_t := 30.0
var timers: Array = []


func after(sec: float, f: Callable) -> void:
	timers.append([sec, f])


func _process(delta: float) -> void:
	if not GS.started:
		return
	var rdt := delta / maxf(Engine.time_scale, 0.001)
	for i in range(timers.size() - 1, -1, -1):
		if i >= timers.size():
			continue
		timers[i][0] -= delta
		if timers[i][0] <= 0.0:
			var f: Callable = timers[i][1]
			timers.remove_at(i)
			f.call()
	for c in conflicts:
		_update(c, delta, rdt)
	conflicts = conflicts.filter(func(c): return not c.dead)
	if break_active:
		spawn_t -= delta
		if spawn_t <= 0.0:
			if conflicts.is_empty():
				spawn()
			spawn_t = randf_range(35.0, 60.0) * (1.4 if GS.upgrades["posters"] else 1.0)
	_check_wheel()


func active_conflict():
	for c in conflicts:
		if c.state == "active" or c.state == "body":
			return c
	return null


# ---------------- skapa bråk ----------------
func spawn() -> bool:
	var free: Array = GS.main.students.filter(func(n): return (n.state == "idle" or n.state == "walk") and n.activity == "wander" and n.cool <= 0.0 and n.rule_break == "")
	if free.size() < 2 or GS.player == null:
		return false
	var scen: Dictionary = Data.SCEN.pick_random()
	var m = GS.map
	var allowed := [m.ROOM_CH, m.ROOM_CV, m.ROOM_MAT, m.ROOM_YARD, m.ROOM_YARD, m.ROOM_GYM]
	var spot := Vector2i(-1, -1)
	for i in 120:
		var prefs: Array = scen["rooms"]
		var ri: int = prefs.pick_random() if (not prefs.is_empty() and randf() < 0.6) else allowed.pick_random()
		if m.has_camera(ri) and randf() < 0.6:
			continue
		var p: Vector2 = m.random_point(ri)
		var t: Vector2i = m.tile_of(p)
		if not (m.walkable(t.x - 1, t.y) and m.walkable(t.x + 1, t.y) and m.walkable(t.x, t.y - 1) and m.walkable(t.x, t.y + 1)):
			continue
		if p.distance_to(GS.player.position) < 320.0:
			continue
		if m.pitch.grow(40).has_point(p):
			continue
		spot = t
		break
	if spot.x < 0:
		return false
	var center := Vector2(spot.x * 40 + 20, spot.y * 40 + 20)
	free.sort_custom(func(p, q): return p.position.distance_to(center) < q.position.distance_to(center))
	var c := Conflict.new()
	c.a = free[0]
	c.b = free[1]
	c.scen = scen
	c.pos = center
	c.room = m.room_at(center)
	c.options = _build_options(scen)
	for n in [c.a, c.b]:
		n.conflict = c
		n.bubble_text = ""
		n.bubble_t = 0.0
		n.activity = "conflict"
	c.a.walk_to(center + Vector2(-28, 0), "conflict", true)
	c.b.walk_to(center + Vector2(28, 0), "conflict", true)
	c.a.bubble_off = -34.0
	c.b.bubble_off = 34.0
	conflicts.append(c)
	return true


func _build_options(scen: Dictionary) -> Array:
	var others: Array = []
	for id in scen["good"]:
		others.append(id)
	for id in ["sluta", "stopp", "lagg", "hallaa"]:
		others.append(id)
	var gen: Array = Data.GENERIC.duplicate()
	gen.shuffle()
	for id in gen:
		if not others.has(id):
			others.append(id)
	var bad: Array = Data.BAD.duplicate()
	bad.shuffle()
	others += bad.slice(0, 5)
	others.shuffle()
	var page0: Array = ["fetch_adult", "friend_help"] + others.slice(0, 10)
	page0.shuffle()
	return page0 + others.slice(10)


# ---------------- uppdatering ----------------
func _update(c: Conflict, dt: float, rdt: float) -> void:
	var a = c.a
	var b = c.b
	c.cool = maxf(0.0, c.cool - rdt)
	if c.state == "gather":
		c.gt += dt
		if a.state == "conflict" and b.state == "conflict":
			c.state = "active"
			c.line_t = 0.4
			GS.toast("Det har blivit bråk i %s! Följ den röda pilen." % GS.map.room_name(c.room), "warn", 4)
		elif c.gt > 40.0:
			_end(c)
		return
	if c.state == "active" or c.state == "body":
		c.time += dt
		c.line_t -= dt
		a.facing = 1.0
		b.facing = -1.0
		if c.line_t <= 0.0:
			_next_line(c)
			c.line_t = 2.7
		a.raise_t = 1.0 if c.esc >= 2 else 0.0
		b.raise_t = 0.8 if c.esc >= 2 else 0.0
		if c.esc >= 3:
			c.shove_t -= dt
			if c.shove_t <= 0.0:
				_shove(c)
				c.shove_t = 1.5
		if c.state == "body":
			if GS.player.position.distance_to(c.pos) < 24.0:
				c.body_p += rdt
			else:
				c.body_p = maxf(0.0, c.body_p - rdt * 0.6)
			c.push = c.body_p / 1.3 * 0.6
			if c.body_p >= 1.3:
				resolve(c, "body")
		_auto_help(c, dt)
		if c.time > 75.0 and (c.state == "active" or c.state == "body"):
			_fail(c)
	var lean := 5.0 if ((c.state == "active" or c.state == "body") and c.esc >= 2) else 0.0
	var base := lean - c.push * 26.0
	a.off_xb = base
	b.off_xb = -base
	if c.state == "resolved" or c.state == "failed":
		c.end_t -= dt
		if c.end_t <= 0.0:
			_end(c)


func _next_line(c: Conflict) -> void:
	var s := c.scen
	var line: Array
	if c.li < s["lines"].size():
		line = s["lines"][c.li]
		c.li += 1
	else:
		line = s["loop"][c.lj % s["loop"].size()]
		c.lj += 1
	c.esc = mini(3, maxi(c.min_esc, int(c.li / 1.5) + c.bonus))
	var sp = c.b if line[0] == 1 else c.a
	var ls = c.a if line[0] == 1 else c.b
	sp.say(line[1], 2.5, "mean")
	ls.anger_t = minf(1.0, ls.anger_t + 0.3)
	sp.anger_t = maxf(sp.anger_t, 0.2 + c.esc * 0.22)


func _shove(c: Conflict) -> void:
	var att = c.b if c.flip else c.a
	c.flip = not c.flip
	var dir := 1.0 if att == c.a else -1.0
	var vic = c.b if att == c.a else c.a
	att.lunge_t = 0.4
	att.lunge_dir = dir
	after(0.15, _recoil.bind(vic, dir))
	GS.overlay.puff(c.pos + Vector2(dir * 6.0, -8))
	GS.overlay.float_text(c.pos + Vector2(0, -62), "KNUFF!", Color("ff3b52"))


func _auto_help(c: Conflict, dt: float) -> void:
	if c.helper != null:
		return
	c.auto_t += dt
	if GS.map.has_camera(c.room) and c.auto_t > 6.0 and not c.cam_alerted:
		c.cam_alerted = true
		var ad = nearest_adult(c.pos, true)
		if ad != null:
			dispatch(ad, c, false)
			GS.toast("Övervakningskameran i %s larmade %s!" % [GS.map.room_name(c.room), ad.display_name], "info", 4)
		return
	if c.auto_t > 18.0:
		var ad2 = nearest_adult(c.pos, true, 320.0)
		if ad2 != null:
			dispatch(ad2, c, false)


# ---------------- vuxna och kompisar ----------------
func nearest_adult(p: Vector2, need_duty: bool, maxd: float = 1.0e9):
	var best = null
	var bd := maxd
	for ad in GS.main.adults:
		if ad.is_static or ad.rule_break != "" or ad.state == "respond":
			continue
		if need_duty and not ad.on_duty:
			continue
		var d: float = ad.position.distance_to(p)
		if d < bd:
			bd = d
			best = ad
	return best


func nearest_friend(p: Vector2):
	var best = null
	var bd := 1.0e9
	for n in GS.main.students:
		if not n.is_friend or n.conflict != null or n.state == "respond" or n.activity == "lesson":
			continue
		var d: float = n.position.distance_to(p)
		if d < bd:
			bd = d
			best = n
	return best


func dispatch(ad, c: Conflict, credit: bool) -> void:
	if c.dead or c.state == "resolved" or c.state == "failed":
		return
	c.helper = ad
	c.helper_kind = "adult"
	c.player_credit = c.player_credit or credit
	ad.respond_c = c
	ad.go_to(c.pos + Vector2(0, 34))
	ad.state = "respond"
	ad.say("Jag kommer!", 2.0)


func friend_help(n, c: Conflict) -> void:
	c.helper = n
	c.helper_kind = "friend"
	c.player_credit = true
	n.respond_c = c
	n.go_to(c.pos + Vector2(0, 34))
	n.state = "respond"
	n.say("Jag hjälper dig!", 2.0)


func helper_arrived(h) -> void:
	var c = h.respond_c
	h.respond_c = null
	h.state = "idle"
	h.idle_t = 3.0
	if c == null or c.dead or not (c.state == "active" or c.state == "body" or c.state == "gather"):
		return
	if c.helper_kind == "friend" and h.role == "student":
		if randf() < 0.85:
			h.say("Kom igen, sluta nu. Det är inte värt det!", 3.0, "good")
			resolve(c, "friend")
		else:
			h.say("De lyssnar inte på mig...", 2.6)
			c.helper = null
			GS.toast("Din kompis lyckades inte. Gå emellan eller hämta en vuxen!", "warn", 4)
		return
	h.say("Nu slutar ni. Vi pratar om det här tillsammans.", 3.0, "good")
	resolve(c, "adult")


# ---------------- spelarens val ----------------
func choose(c: Conflict, id: String) -> void:
	if c.dead or c.state != "active":
		return
	if id == "fetch_adult":
		_fetch(c)
		return
	if id == "friend_help":
		var f = nearest_friend(c.pos)
		if f == null:
			GS.toast("Du har inga kompisar som kan hjälpa till än. Prata med elever på rasterna för att bli kompisar!", "warn", 5)
			c.cool = 1.0
			return
		GS.player.say("%s, kan du hjälpa mig?" % f.display_name, 2.4, "me")
		friend_help(f, c)
		c.cool = 999.0
		return
	var o: Dictionary = Data.OPT[id]
	GS.player.say(o["t"], 2.4, "me")
	c.options.erase(id)
	if o["k"] == "bad":
		_bad(c, o["why"])
		return
	var ch := 0.85 if c.scen["good"].has(id) else (0.5 if o["k"] == "mid" else 0.45)
	_attempt(c, ch - c.esc * 0.1, "words")


func custom(c: Conflict, text: String) -> void:
	if c.dead or c.state != "active":
		return
	text = text.strip_edges()
	if text.length() > 80:
		text = text.substr(0, 80)
	GS.player.say(text, 3.0, "me")
	var r: Dictionary = Data.judge(text)
	if r["bad"]:
		_bad(c, "Din mening innehöll elaka eller hetsande ord. Det gör bråket värre – var lugn och tydlig.")
		return
	var sc: int = r["score"]
	if sc == 0:
		GS.toast("Bra att du försöker! Tips: säg tydligt ifrån, till exempel 'Sluta, det där är inte okej'.", "info", 5)
	else:
		GS.toast("Bra formulerat!", "good", 2.5)
	_attempt(c, 0.3 + 0.17 * mini(sc, 3) - c.esc * 0.08, "custom")


func _bad(c: Conflict, why: String) -> void:
	c.bonus += 1
	c.cool = 2.2
	GS.change(0, -2, 0)
	GS.toast("Tänk efter: " + why, "bad", 6)
	after(0.6, _bad_react.bind(c))


func _attempt(c: Conflict, ch: float, how: String) -> void:
	c.cool = 999.0
	after(0.8, _attempt_result.bind(c, ch, how))


func _fetch(c: Conflict) -> void:
	var ad = nearest_adult(GS.player.position, false)
	if ad == null:
		GS.toast("Det finns ingen ledig vuxen just nu. Försök själv!", "warn", 3)
		c.cool = 1.0
		return
	GS.player.say("Jag hämtar en vuxen!", 2.0, "me")
	GS.main.player_task = {"type": "fetch", "c": c, "adult": ad}
	c.cool = 999.0
	c.time = maxf(0.0, c.time - 25.0)
	GS.toast("Spring till %s (%s) – följ den vita pilen!" % [ad.display_name, ad.title.to_lower()], "warn", 5)


# ---------------- slut på bråk ----------------
func resolve(c: Conflict, how: String) -> void:
	if c.state == "resolved" or c.state == "failed" or c.dead:
		return
	c.state = "resolved"
	c.end_t = 3.6
	c.push = 1.0 if how == "body" else 0.0
	for n in [c.a, c.b]:
		n.anger_t = 0.0
		n.raise_t = 0.0
	c.a.say(Data.BODY_A.pick_random() if how == "body" else Data.SUCC_A.pick_random(), 2.6, "good")
	after(1.1, _npc_say.bind(c.b, String(Data.SUCC_B.pick_random()).replace("{n}", GS.player_name), "good"))
	var rewarded: bool = how == "words" or how == "body" or how == "custom" or c.player_credit
	if rewarded:
		GS.add_coins(10)
		GS.stopped += 1
		GS.change(0, 3, 0)
		var how_txt := {"words": "med dina ord", "body": "genom att gå emellan", "custom": "med dina egna ord",
			"adult": "genom att hämta en vuxen", "friend": "med hjälp av din kompis"}
		GS.toast("Bra jobbat! Du stoppade bråket %s. +10 coins" % how_txt.get(how, ""), "good", 4)
	else:
		GS.toast("En vuxen stoppade bråket mellan %s och %s." % [c.a.display_name, c.b.display_name], "info", 3)
	if GS.wheel.target == c:
		GS.wheel.close()
	if GS.main.player_task.get("c") == c:
		GS.main.player_task = {}


func _fail(c: Conflict) -> void:
	c.state = "failed"
	c.end_t = 3.0
	c.b.sad = 10.0
	c.a.anger_t = 0.3
	c.b.anger_t = 0.0
	c.a.say("Hmpf. Vi tar det sen.", 2.4)
	after(1.0, _npc_say.bind(c.b, "...ingen hjälpte mig.", "n"))
	GS.missed += 1
	GS.stats_changed.emit()
	GS.toast("Ingen stoppade bråket mellan %s och %s. %s blev ledsen." % [c.a.display_name, c.b.display_name, c.b.display_name], "bad", 5)
	if GS.wheel.target == c:
		GS.wheel.close()


func _end(c: Conflict) -> void:
	c.dead = true
	for n in [c.a, c.b]:
		n.position.x += n.off_x
		n.off_x = 0.0
		n.off_xb = 0.0
		if not GS.map.walkable_pos(n.position):
			n.position = c.pos
		n.conflict = null
		n.anger_t = 0.0
		n.raise_t = 0.0
		n.bubble_off = 0.0
		n.cool = 40.0
		if n.activity == "conflict":
			n.activity = "wander"
		if n.state == "conflict" or n.state == "walk":
			n.state = "idle"
			n.idle_t = randf_range(1.0, 3.0)
			n.path.clear()
	if c.helper != null and c.helper.state == "respond":
		c.helper.state = "idle"
		c.helper.respond_c = null
	if GS.wheel.target == c:
		GS.wheel.close()
	if GS.main.player_task.get("c") == c:
		GS.main.player_task = {}


## Avslutar alla bråk (t.ex. när det ringer in).
func end_all() -> void:
	var any := false
	for c in conflicts:
		if not c.dead:
			if c.state == "active" or c.state == "body":
				any = true
			_end(c)
	conflicts.clear()
	if any:
		GS.toast("Det ringde in – en lärare tog hand om bråket.", "info", 3)


func _check_wheel() -> void:
	if GS.wheel.is_open() or GS.modal_count > 0 or GS.player == null:
		return
	for c in conflicts:
		if c.state != "active":
			continue
		var d: float = GS.player.position.distance_to(c.pos)
		if c.dismissed:
			if d > 180.0:
				c.dismissed = false
			continue
		if c.cool > 0.0:
			continue
		if d < 110.0:
			GS.wheel.open_for(c)
			return


# ---------------- fördröjda händelser ----------------
func _recoil(vic, dir: float) -> void:
	if is_instance_valid(vic):
		vic.recoil_t = 0.4
		vic.recoil_dir = dir


func _npc_say(n, text: String, kind: String) -> void:
	if is_instance_valid(n):
		n.say(text, 2.6, kind)


func _bad_react(c: Conflict) -> void:
	if c.state == "active":
		c.a.say(Data.BADREACT.pick_random(), 2.2, "mean")
		c.b.sad = 4.0


func _attempt_result(c: Conflict, ch: float, how: String) -> void:
	if c.dead or c.state != "active":
		return
	if randf() < ch:
		resolve(c, how)
		return
	c.state = "body"
	c.min_esc = 2
	c.esc = maxi(c.esc, 2)
	c.a.say(Data.FAIL.pick_random(), 2.6, "mean")
	c.line_t = 2.8
	GS.toast("Orden räckte inte! Gå emellan – ställ dig i cirkeln mellan %s och %s. Eller spring och hämta en vuxen." % [c.a.display_name, c.b.display_name], "warn", 5)
