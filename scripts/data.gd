extends Node
## Data (autoload): allt innehåll – repliker, bråk, prov och chattar.
## Lätt att redigera för elever: lägg till fler rader i listorna!

const STUDENT_NAMES := ["Elin", "Noah", "Ali", "Saga", "Viktor", "Alex", "Mira", "Leo", "Hugo", "Maja",
	"Omar", "Ebba", "Liam", "Alva", "Isak", "Wilma", "Sam", "Nora", "Adam", "Selma",
	"Yusuf", "Freja", "Elias", "Amina", "Theo", "Linnea"]
const EXTRA_RASTVAKT_NAMES := ["Robin", "Jonna", "Ahmed", "Tove", "Mattias", "Fatima"]

# ---------------- BRÅK ----------------
# rooms: rum där bråket helst uppstår (index i SchoolMap.rooms). good: bästa replikerna.
const SCEN := [
	{"lines": [[0, "Du är ful!"], [1, "Va?! Själv är du ful!"], [0, "Ingen vill ens sitta bredvid dig."], [1, "Håll tyst, annars...!"], [0, "Annars vad då? Kom igen!"]],
	 "loop": [[0, "Backa!"], [1, "Rör mig inte!"], [0, "Du började!"], [1, "Sluta knuffas!"]],
	 "good": ["looks", "notok", "feel", "rule"], "rooms": []},
	{"lines": [[0, "Har du köpt de där kläderna på soptippen?"], [1, "Sluta! De är nya!"], [0, "Haha, alla skrattar åt dig."], [1, "Säg det en gång till då!"], [0, "Ska du göra nåt, eller?"]],
	 "loop": [[1, "Flytta dig!"], [0, "Knuffas inte!"], [1, "Du är så taskig!"], [0, "Gå härifrån!"]],
	 "good": ["clothes", "notok", "askv", "respect"], "rooms": [4, 5]},
	{"lines": [[0, "Det var ditt fel att vi förlorade, du är så dålig!"], [1, "Det var du som missade passningen!"], [0, "Du är värdelös på allt."], [1, "Kom hit och säg det!"], [0, "Jag är här. Vad tänker du göra?"]],
	 "loop": [[0, "Backa!"], [1, "Sluta trycka på mig!"], [0, "Du är löjlig!"], [1, "Lägg av!"]],
	 "good": ["team", "talk", "calm", "separate"], "rooms": [6, 3]},
	{"lines": [[0, "Flytta på dig, det här är min plats."], [1, "Jag satt här först!"], [0, "Ingen vill ha dig här. Stick!"], [1, "Tvinga mig då!"], [0, "Gärna!"]],
	 "loop": [[0, "Flytta på dig!"], [1, "Sluta dra i min stol!"], [0, "Min plats!"], [1, "Släpp!"]],
	 "good": ["share", "talk", "calm", "rule"], "rooms": [2]},
	{"lines": [[0, "Alla vet att du ljög om mig!"], [1, "Jag har inte sagt nåt!"], [0, "Skvallerbytta! Du är så falsk."], [1, "Sluta skrika på mig!"], [0, "Jag skriker om jag vill!"]],
	 "loop": [[1, "Gå bort!"], [0, "Knuffa inte!"], [1, "Lögnare!"], [0, "Själv!"]],
	 "good": ["rumor", "talk", "calm", "separate"], "rooms": []},
	{"lines": [[0, "Du får inte vara med oss. Ingen gillar dig."], [1, "Varför är du så elak?"], [0, "För att du är konstig. Gå härifrån!"], [1, "Det är du som är konstig!"], [0, "Vill du bråka, eller?"]],
	 "loop": [[0, "Stick!"], [1, "Sluta knuffas!"], [0, "Gå då!"], [1, "Lämna mig ifred!"]],
	 "good": ["join", "askv", "rule", "feel"], "rooms": [6]},
	{"lines": [[0, "Ge mig din mobil, jag ska bara kolla."], [1, "Nej! Ge tillbaka den!"], [0, "Fånga den då, haha!"], [1, "Ge hit den NU!"], [0, "Kom och ta den då!"]],
	 "loop": [[1, "Ge tillbaka!"], [0, "Nej!"], [1, "Den är min!"], [0, "Ta den då!"]],
	 "good": ["giveback", "notok", "rule", "calm"], "rooms": []},
	{"lines": [[0, "Varför pratar du så konstigt?"], [1, "Jag pratar inte konstigt!"], [0, "Jo, alla härmar dig bakom din rygg."], [1, "Du är bara elak!"], [0, "Gråt inte nu då!"]],
	 "loop": [[0, "Backa!"], [1, "Lämna mig ifred!"], [0, "Gör det själv!"], [1, "Sluta!"]],
	 "good": ["respect", "notok", "feel", "askv"], "rooms": [2, 4, 5]},
]

# k: "mid" = okej men inte bäst, "good" = bra, "bad" = gör det värre
const OPT := {
	"sluta": {"t": "Sluta!", "k": "mid"},
	"stopp": {"t": "Stopp! Nu räcker det.", "k": "mid"},
	"lagg": {"t": "Lägg av, båda två!", "k": "mid"},
	"hallaa": {"t": "Hallå! Vad håller ni på med?", "k": "mid"},
	"notok": {"t": "Det där är inte okej.", "k": "good"},
	"calm": {"t": "Ta det lugnt, båda två.", "k": "good"},
	"askv": {"t": "Hur är det? Kom med mig.", "k": "good"},
	"rule": {"t": "Här mobbar vi inte varandra.", "k": "good"},
	"separate": {"t": "Gå åt varsitt håll nu.", "k": "good"},
	"talk": {"t": "Vad har hänt? Prata i stället.", "k": "good"},
	"friend": {"t": "Låt min kompis vara!", "k": "good"},
	"breathe": {"t": "Andas djupt. Ingen vinner på bråk.", "k": "good"},
	"respect": {"t": "Vi behandlar alla med respekt här.", "k": "good"},
	"olweus": {"t": "Olweus regel 1: vi mobbar inte!", "k": "good"},
	"feel": {"t": "Hur tror du att hen känner sig nu?", "k": "good"},
	"sorry": {"t": "Kan ni säga förlåt till varandra?", "k": "good"},
	"stopnow": {"t": "Jag vill att ni slutar nu. Direkt.", "k": "good"},
	"together": {"t": "Vi löser det här tillsammans.", "k": "good"},
	"notfunny": {"t": "Det där är inte roligt för någon.", "k": "good"},
	"walk": {"t": "Kom, vi går härifrån.", "k": "good"},
	"see": {"t": "Jag ser vad som händer. Sluta.", "k": "good"},
	"cool": {"t": "Kyl ner er. Det är inte värt det.", "k": "good"},
	"disagree": {"t": "Ni kan tycka olika utan att vara elaka.", "k": "good"},
	"team": {"t": "Alla gör misstag. Ni är ett lag!", "k": "good"},
	"share": {"t": "Det finns plats för alla här.", "k": "good"},
	"rumor": {"t": "Prata med varandra, inte om varandra.", "k": "good"},
	"join": {"t": "Kom, du får vara med mig!", "k": "good"},
	"giveback": {"t": "Ge tillbaka mobilen nu.", "k": "good"},
	"looks": {"t": "Alla ser olika ut, och det är bra.", "k": "good"},
	"clothes": {"t": "Folk får ha på sig vad de vill.", "k": "good"},
	"laugh": {"t": "Haha, kör hårdare!", "k": "bad", "why": "Att skratta och heja på gör bråket värre. Den som skrattar med blir en del av mobbningen."},
	"film": {"t": "Filma och lägg upp det", "k": "bad", "why": "Att filma och sprida gör det mycket värre för den som blir utsatt."},
	"ignore": {"t": "Gå förbi och låtsas inget", "k": "bad", "why": "Om ingen ingriper fortsätter det. Olweus regel 2: vi ska försöka hjälpa den som blir utsatt."},
	"insult": {"t": "Ni är båda töntar!", "k": "bad", "why": "Elaka ord tillbaka gör bara alla argare. Var lugn och tydlig."},
	"cheer": {"t": "Slåss! Slåss!", "k": "bad", "why": "Att hetsa på gör det farligare för alla."},
	"pushback": {"t": "Knuffa tillbaka", "k": "bad", "why": "Att själv börja knuffas gör bara bråket större. Gå emellan lugnt i stället."},
	"threat": {"t": "Akta er, annars...!", "k": "bad", "why": "Hot skapar mer rädsla och ilska. Säg ifrån utan att hota."},
	"side": {"t": "Jag håller med, hen är töntig.", "k": "bad", "why": "Att ta mobbarens parti gör det värre för den utsatta."},
	"spread": {"t": "Berätta det här för hela skolan", "k": "bad", "why": "Att sprida rykten är också mobbning."},
}
const GENERIC := ["notok", "calm", "askv", "rule", "separate", "talk", "friend", "breathe", "respect", "olweus",
	"feel", "sorry", "stopnow", "together", "notfunny", "walk", "see", "cool", "disagree"]
const BAD := ["laugh", "film", "ignore", "insult", "cheer", "pushback", "threat", "side", "spread"]

const SUCC_A := ["Okej, okej... förlåt.", "Förlåt. Det var dumt sagt.", "Okej, vi lägger ner det.", "Du har rätt. Sorry."]
const SUCC_B := ["Tack, {n}!", "Tack för att du brydde dig!", "Skönt att någon sa ifrån.", "Tack {n}, du är schysst!"]
const BODY_A := ["Okej, okej! Vi slutar.", "Okej... vi går härifrån.", "Hm. Okej. Förlåt."]
const FAIL := ["Lägg dig inte i!", "Det här har inte med dig att göra!", "Stick, vi är inte klara!", "Bry dig inte!"]
const BADREACT := ["Haha, ja!", "Se, hen håller med mig!", "Mer publik!", "Ja, kolla nu!"]
const AMB := ["Vad har vi på nästa lektion?", "Jag är så hungrig!", "Har du gjort läxan?", "Ska vi spela fotboll på rasten?",
	"Jag gillar din tröja!", "Hej {n}!", "Vilken bra dag!", "Vill du vara med oss sen?", "Snart lunch!"]
const FRIEND_TALK := ["Hej {n}! Kul att du kom fram.", "Vad gillar du att göra på fritiden?", "Haha, du är rolig!", "Vi kan hänga på rasten!", "Jag gillar att prata med dig."]
const LONELY := ["...", "Ingen vill vara med mig.", "Jag står bara här."]
const RB_ADULT := {"phone": "Ska bara kolla en sak i mobilen...", "coffee": "Jag hämtar lite kaffe, det går nog bra.", "chat": "Har du sett gårdagens match?"}

# Ord som gör egna meningar bättre eller sämre
const GOOD_KW := ["sluta", "stopp", "lägg av", "lugn", "andas", "prata", "inte okej", "vuxen", "lärare", "rastvakt",
	"förlåt", "hjälp", "kompis", "respekt", "schysst", "snäll", "tillsammans", "vara med", "mobba", "olweus",
	"känn", "oense", "lös", "varsitt", "ifred", "alla", "lyssna", "elak", "räcker"]
const BAD_WORDS := ["idiot", "dum", "dumma", "tönt", "töntar", "ful", "fula", "slå", "slåss", "spöa", "knuffa", "haha",
	"filma", "hata", "hatar", "käften", "jävla", "fan", "helvete", "skit", "loser", "äcklig", "tjock", "värdelös", "patetisk", "kör"]


## Bedömer en egen mening. Svarar {"score": antal bra ord, "bad": true om elaka/hetsande ord}.
func judge(text: String) -> Dictionary:
	var low := text.to_lower()
	var re := RegEx.new()
	re.compile("[a-zåäöéü]+")
	var bad := false
	for m in re.search_all(low):
		if BAD_WORDS.has(m.get_string()):
			bad = true
	var score := 0
	for kw in GOOD_KW:
		if low.find(kw) != -1:
			score += 1
	return {"score": score, "bad": bad}


# ---------------- PROV ----------------
# a: svar, c: index för rätt svar, why: förklaring
const OLWEUS_Q := [
	{"q": "Du ser att någon blir utfryst på rasten. Vad gör du?", "a": ["Frågar om hen vill vara med dig", "Låtsas att du inte ser", "Skrattar med de andra", "Väntar och ser om det går över"], "c": 0, "why": "Olweus regel 3: Vi ska vara med elever som lätt blir ensamma."},
	{"q": "Någon skickar en elak bild om en klasskamrat i gruppchatten. Vad är bäst?", "a": ["Gillar bilden", "Delar den vidare", "Säger ifrån och berättar för en vuxen", "Lämnar chatten utan att säga något"], "c": 2, "why": "Säg ifrån och berätta för en vuxen – mobbning på nätet är också mobbning."},
	{"q": "Vad säger Olweus regel 1?", "a": ["Vi ska inte mobba andra", "Vi ska alltid vinna", "Vi ska inte prata på lektionen", "Vi ska äta upp all mat"], "c": 0, "why": "Regel 1: Vi ska inte mobba andra."},
	{"q": "Vad säger Olweus regel 4?", "a": ["Om vi vet att någon blir mobbad ska vi berätta för en vuxen i skolan och hemma", "Vi ska lösa allt själva", "Vi ska aldrig prata med vuxna", "Vi ska skvallra på alla"], "c": 0, "why": "Regel 4: Berätta för en vuxen i skolan och en vuxen hemma."},
	{"q": "Två elever börjar knuffas i korridoren. Vad gör du först?", "a": ["Hejar på", "Säger tydligt ifrån och hämtar en vuxen om det inte hjälper", "Filmar", "Går därifrån och glömmer det"], "c": 1, "why": "Säg ifrån tydligt. Räcker inte det – hämta en vuxen."},
	{"q": "Vad är mobbning?", "a": ["När någon upprepade gånger blir illa behandlad och har svårt att försvara sig", "Ett bråk en gång mellan två som är lika starka", "När man tycker olika", "När man förlorar i fotboll"], "c": 0, "why": "Mobbning är upprepat, och den utsatta har svårt att försvara sig."},
	{"q": "En kompis säger 'Det var bara på skämt' efter att ha varit elak. Stämmer det?", "a": ["Ja, skämt är alltid okej", "Det är den som blir utsatt som avgör om det är kränkande", "Bara om alla skrattade", "Ja, om man säger förlåt sen"], "c": 1, "why": "Det är den som blir utsatt som avgör om något är kränkande."},
	{"q": "Varför är det viktigt att inte bara titta på när någon mobbas?", "a": ["Åskådare som inte gör något kan få mobbaren att fortsätta", "Det är tråkigt att titta", "Man kan få skäll", "Det spelar ingen roll"], "c": 0, "why": "Mobbaren vill ofta ha publik. Säg ifrån eller hämta hjälp."},
	{"q": "Någon i klassen sitter alltid ensam i matsalen. Vad kan du göra?", "a": ["Fråga om hen vill sitta med dig", "Ta hens plats", "Prata om hen bakom ryggen", "Inget, hen vill nog vara ensam"], "c": 0, "why": "Regel 3: Vi ska vara med elever som lätt blir ensamma."},
	{"q": "Du har själv varit elak mot någon. Vad är bäst att göra?", "a": ["Be om förlåtelse och ändra ditt beteende", "Skylla på någon annan", "Fortsätta så ingen märker", "Låtsas att inget hänt"], "c": 0, "why": "Alla kan göra fel. Be om förlåtelse och gör bättre."},
	{"q": "Vem kan du berätta för om du blir mobbad?", "a": ["En lärare, rastvakt eller annan vuxen i skolan – och en vuxen hemma", "Ingen", "Bara mobbaren", "Bara dina syskon"], "c": 0, "why": "Vuxna i skolan och hemma ska hjälpa dig."},
	{"q": "Någon tar en klasskamrats mössa och kastar runt den. Vad gör du?", "a": ["Säger 'Ge tillbaka den nu' och hämtar en vuxen om det fortsätter", "Fångar och kastar vidare", "Skrattar", "Filmar det"], "c": 0, "why": "Säg ifrån och hämta en vuxen om det inte slutar."},
	{"q": "Vad betyder det att vara en schysst kompis?", "a": ["Att säga ifrån, stötta den som är utsatt och inte vara elak", "Att alltid hålla med sina kompisar", "Att aldrig prata med vuxna", "Att bara vara med sina bästa vänner"], "c": 0, "why": "En schysst kompis säger ifrån och stöttar."},
	{"q": "Rastvakten tittar i sin mobil medan det är bråk. Vad gör du?", "a": ["Säger till rastvakten och berättar var bråket är", "Inget, det är hens jobb", "Skrattar åt rastvakten", "Börjar också bråka"], "c": 0, "why": "Även vuxna kan behöva en påminnelse. Berätta var det är bråk."},
	{"q": "En elev blir retad för sina kläder varje dag. Vad är det?", "a": ["Mobbning", "Ett skämt", "Normalt", "Elevens eget fel"], "c": 0, "why": "Det händer upprepat och sårar – det är mobbning."},
]

const SUBJECT_Q := {
	"matte": [
		{"q": "7 x 8 = ?", "a": ["56", "54", "64", "48"], "c": 0},
		{"q": "Vad är 25 % av 80?", "a": ["20", "25", "16", "40"], "c": 0},
		{"q": "144 / 12 = ?", "a": ["12", "14", "11", "10"], "c": 0},
		{"q": "0,5 + 0,25 = ?", "a": ["0,75", "0,30", "0,7", "1,0"], "c": 0},
		{"q": "Hur många minuter är 2,5 timmar?", "a": ["150", "125", "250", "90"], "c": 0},
		{"q": "Vilket tal är störst?", "a": ["0,9", "0,45", "0,099", "0,5"], "c": 0},
	],
	"svenska": [
		{"q": "Vilket ord är ett verb?", "a": ["springa", "hus", "snabb", "under"], "c": 0},
		{"q": "Vad är en synonym till 'glad'?", "a": ["lycklig", "ledsen", "arg", "trött"], "c": 0},
		{"q": "Vilken mening är rätt?", "a": ["Jag och min kompis gick hem.", "Mig och min kompis gick hem.", "Jag och mig gick hem.", "Mig gick hem."], "c": 0},
		{"q": "Vad är motsatsen till 'stor'?", "a": ["liten", "lång", "hög", "bred"], "c": 0},
		{"q": "Vilket ord är ett adjektiv?", "a": ["vacker", "springer", "bord", "och"], "c": 0},
	],
	"no": [
		{"q": "Vad behöver växter för fotosyntesen?", "a": ["Ljus, vatten och koldioxid", "Bara jord", "Salt", "Mörker"], "c": 0},
		{"q": "Vilken planet är närmast solen?", "a": ["Merkurius", "Mars", "Jorden", "Venus"], "c": 0},
		{"q": "Vid hur många grader fryser vatten?", "a": ["0 grader", "10 grader", "-10 grader", "100 grader"], "c": 0},
		{"q": "Vilket organ pumpar blodet i kroppen?", "a": ["Hjärtat", "Lungorna", "Magen", "Levern"], "c": 0},
	],
	"svenska_so": [],
}


func pick_questions(src: Array, n: int) -> Array:
	var arr := src.duplicate()
	arr.shuffle()
	return arr.slice(0, mini(n, arr.size()))


# ---------------- CHATT-MOBBNING (mobilen) ----------------
# vem: 0 = mobbaren, 1 = den utsatta, 2/3 = andra i gruppen
const DSCEN := [
	{"group": "Klass 8B", "a": "Viktor", "v": "Elin", "msgs": [[0, "Kolla Elins nya frisyr haha, ser ut som en mopp"], [2, "hahaha"], [1, "Sluta skriva om mig..."], [0, "Hon blev sur lol, ingen frågade dig"], [3, "lol"], [1, "Varför gör ni så här?"], [0, "För att du är så lätt att reta"]]},
	{"group": "Fotbollslaget", "a": "Alex", "v": "Noah", "msgs": [[0, "Noah ska inte få vara med på lördag, han är värdelös"], [2, "haha sant"], [1, "Jag har tränat varje dag..."], [0, "Ingen bryr sig. Lämna gruppen"], [3, "hejdå"], [1, "Det är inte schysst"], [0, "Hejdå förlorare"]]},
	{"group": "7A-gänget", "a": "Saga", "v": "Ali", "msgs": [[0, "Vem bjöd in Ali hit?"], [2, "inte jag haha"], [1, "Jag går ju också i klassen..."], [0, "Ingen vill ha dig här. Kicka honom någon"], [3, "kickar snart lol"], [1, "Snälla sluta"], [0, "Gråt inte nu"]]},
	{"group": "Klassresan", "a": "Ebba", "v": "Selma", "msgs": [[0, "Ingen vill dela rum med Selma va?"], [3, "nej tack"], [1, "Varför skriver ni så?"], [0, "För att hon är så konstig hahaha"], [2, "usch"], [1, "Det är inte sant..."], [0, "Hon tar allt så personligt"]]},
]
const DOPT := {
	"write": {"t": "Skriv: Sluta, det där är elakt.", "msg": "Sluta, det där är elakt.", "ch": 0.6},
	"rule": {"t": "Skriv: Vi mobbar inte i den här chatten.", "msg": "Vi mobbar inte i den här chatten.", "ch": 0.6},
	"support": {"t": "Skriv något snällt till {v}", "msg": "{v}, jag står på din sida!", "ch": 0.65},
	"private": {"t": "Skriv privat till {v}: Är du okej?", "priv": true, "ch": 0.7},
	"report": {"t": "Rapportera meddelandet", "sys": "Du rapporterade meddelandet.", "ch": 0.6},
	"shot": {"t": "Skärmdumpa och visa en vuxen", "adult": true},
	"like": {"t": "Gilla inlägget", "sys": "Du gillade inlägget.", "bad": "Att gilla elaka inlägg sprider mobbningen."},
	"share": {"t": "Dela vidare till fler", "sys": "Du delade inlägget vidare.", "bad": "Att dela vidare gör att ännu fler ser det. Det blir värre för den som är utsatt."},
	"mean": {"t": "Skriv något elakt tillbaka", "msg": "Du är själv patetisk", "bad": "Elaka ord tillbaka gör bara bråket större."},
}
