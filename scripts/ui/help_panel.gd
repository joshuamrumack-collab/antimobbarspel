extends CanvasLayer
## Hjälprutan med styrning och Olweus fyra regler.

const TEXT := """SÅ SPELAR DU
• Du går i klass 7A. Följ schemat uppe till vänster och kom i tid till lektionerna. Sätt dig på DIN PLATS (gul ring).
• Kommer du för sent måste du be om ursäkt och får olovlig frånvaro. 3 frånvaron = rektorn. 5 = avstängd.
• Stör du på lektionen (går runt, pratar, tar fram mobilen) får du sämre omdöme.
• Säg till elever som smyger med mobilen eller försöker skolka (gult !).
• På rasterna kan det bli bråk. Följ den röda pilen. Valhjulet öppnas när du kommer nära: välj en replik, bläddra med Tab eller skriv en egen mening.
• Fungerar inte orden: gå emellan, spring och hämta en vuxen eller be en kompis om hjälp.
• Prata med elever på rasterna för att bli kompisar. Bjud in elever som är ensamma (blå skylt).
• Rastvakter har gul reflexväst. Ibland glömmer de att hålla uppsikt – säg till dem!
• Varje stoppat bråk ger 10 coins. Använd dem i butiken (B).
• Ät lunch i matsalen för att få tillbaka hälsa.

STYRNING
WASD / piltangenter = gå   ·   E = prata / ingripa   ·   B = butik   ·   F = mobil   ·   H = hjälp   ·   Esc = stäng

OLWEUS FYRA REGLER
1. Vi ska inte mobba andra.
2. Vi ska försöka hjälpa elever som blir utsatta för mobbning.
3. Vi ska vara med elever som lätt blir ensamma.
4. Om vi vet att någon blir mobbad ska vi berätta det för en vuxen i skolan och för en vuxen hemma."""

var root: Control
var is_open := false


func _ready() -> void:
	layer = 23
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
	cc.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var l := Label.new()
	l.text = TEXT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	l.add_theme_font_size_override("font_size", 15)
	v.add_child(l)
	var b := Button.new()
	b.text = "Fortsätt spela"
	b.pressed.connect(close)
	v.add_child(b)
	root.visible = false


func open() -> void:
	if is_open or GS.modal_count > 0 or GS.ui_block:
		return
	is_open = true
	GS.push_modal()
	root.visible = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	GS.pop_modal()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("cancel") or event.is_action_pressed("help")):
		close()
		get_viewport().set_input_as_handled()
