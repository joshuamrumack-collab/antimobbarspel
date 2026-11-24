# Anti mobbar spel (Godot 4)

Ett Olweus-spel där du lär dig att **se bråket, säga ifrån och gå emellan** – och samtidigt sköta skolan: komma i tid, skaffa kompisar och klara proven.

**Spela i webbläsaren:** https://joshuamrumack-collab.github.io/antimobbarspel/

Skapad av DorkTeach. Byggd i Godot 4.3 (GDScript). All grafik ritas med kod, så inga bildfiler behövs.

---

## Så spelar du

| Tangent | Gör |
|---|---|
| WASD / piltangenter | Gå |
| E | Prata, ingripa, säga till |
| B | Butik |
| F | Mobilen |
| H | Hjälp |
| Esc | Stäng |
| Tab | Fler repliker i valhjulet |
| 1–0 | Välj i valhjulet |

På surfplatta finns en joystick nere till vänster och en E-knapp.

**Uppe till höger** ser du ditt **betyg** (F–A), ditt **omdöme** och din **hälsa**, och under dem coins och frånvaro.

### Skolschemat
- En skoldag: Svenska → rast → Matematik → rast → Idrott → lunch → SO (Olweus-prov) → rast → NO.
- Det ringer in 6 minuter före lektionen. Följ den **gula pilen** och sätt dig på **din plats**.
- **Kommer du för sent** måste du be om ursäkt. Du får **olovlig frånvaro**, och betyg, omdöme och hälsa sjunker.
- **3 olovliga frånvaron** → du skickas till **rektorn**. **5** → du blir **avstängd**.
- **Stör du lektionen** (går runt, pratar, tar fram mobilen) får du ett negativt omdöme.
- Kommer du i tid, skaffar kompisar och klarar proven får du ett **bra omdöme**.
- Under lektionerna kan elever **smyga med mobilen** eller **försöka skolka**. Gå dit och säg till (E).
- Ibland är det **prov**: ämnesprov eller **kunskapsprov om Olweus** (hur man ska agera).

### Rasterna
- **Bråk** uppstår ungefär 3 gånger per skoldag, aldrig tätt inpå varandra. Följ den **röda pilen**.
- När du kommer nära öppnas **valhjulet**: 12 repliker per sida och 3 sidor (Tab). Det finns också ett **textfält för egna meningar** – spelet bedömer om meningen lugnar eller trappar upp bråket.
- Räcker inte orden: **gå emellan** (ställ dig i cirkeln), **spring och hämta en vuxen** eller **be en kompis om hjälp**.
- **Fotboll** på skolgården. **Ensamma elever** (blå skylt) kan du bjuda in att vara med (Olweus regel 3).
- **Prata med elever** för att bli kompisar. Kompisar kan hjälpa dig att stoppa bråk.
- **Rastvakter** har gul reflexväst. Ibland tittar de i mobilen eller går och hämtar kaffe – säg till dem!
- **Mobilen**: ibland blir någon mobbad i en gruppchatt. Ingrip eller berätta för en vuxen.
- Ät **lunch** i matsalen för att få tillbaka hälsa.

### Butiken
Spendera coins (10 per stoppat bråk) på: fler rastvakter, övervakningskameror (larmar en vuxen och minskar bråk i rummet), Olweus-affischer, en kompisbänk och frukt.

### Olweus fyra regler
1. Vi ska inte mobba andra.
2. Vi ska försöka hjälpa elever som blir utsatta för mobbning.
3. Vi ska vara med elever som lätt blir ensamma.
4. Om vi vet att någon blir mobbad ska vi berätta det för en vuxen i skolan och för en vuxen hemma.

---

## Nodstruktur

```
Main (Node2D)                      scripts/main.gd           – skapar figurer, sköter E-interaktion
├── World (Node2D)
│   ├── SchoolMap (Node2D)         scripts/school_map.gd     – rum, dörrar, möbler, AStarGrid2D, ritning
│   ├── Actors (Node2D, y-sort)    – skapas i kod:
│   │   ├── Player                 scripts/player.gd         (extends Character)
│   │   │   └── Camera2D
│   │   ├── 20 × Elev              scripts/npc.gd            (extends Character)
│   │   ├── Lärare, rastvakter, expedition, rektor (npc.gd)
│   │   └── Ball                   scripts/ball.gd
│   └── Overlay (Node2D, z 100)    scripts/overlay.gd        – pratbubblor, namnskyltar, bråkringar, kameror
├── ConflictManager (Node)         scripts/conflict_manager.gd – skapar och styr bråk
├── Schedule (Node)                scripts/schedule.gd       – schema, frånvaro, rektor, prov, regelbrott
├── HUD (CanvasLayer 5)            scripts/ui/hud.gd         – betyg/omdöme/hälsa, klocka, karta, pilar
├── ChoiceWheel (CanvasLayer 10)   scripts/ui/choice_wheel.gd – valhjulet + egen mening
├── PhonePanel (CanvasLayer 15)    scripts/ui/phone_panel.gd – gruppchatten
├── DialogPanel (CanvasLayer 20)   scripts/ui/dialog_panel.gd
├── QuizPanel (CanvasLayer 21)     scripts/ui/quiz_panel.gd
├── ShopPanel (CanvasLayer 22)     scripts/ui/shop_panel.gd
├── HelpPanel (CanvasLayer 23)     scripts/ui/help_panel.gd
└── StartScreen (CanvasLayer 30)   scripts/ui/start_screen.gd – skapa din karaktär

Autoloads:
  GS    scripts/gs.gd    – spelarens värden (betyg, omdöme, hälsa, coins, frånvaro), tema, unika utseenden
  Data  scripts/data.gd  – ALLT innehåll: repliker, bråk, prov, chattar
```

`scripts/character.gd` är basklassen för alla figurer och ritar dem. Alla elever och vuxna får ett **unikt utseende** (ingen har samma kombination av hudfärg, frisyr, hårfärg och tröja). Rastvakter ritas alltid med **gul reflexväst**.

## Ändra spelet (för elever)

Det mesta innehållet finns i **`scripts/data.gd`**:
- `SCEN` – bråken (vad eleverna säger) och vilka repliker som fungerar bäst
- `OPT` – replikerna i valhjulet (`"good"`, `"mid"` eller `"bad"` med en förklaring)
- `GOOD_KW` / `BAD_WORDS` – ord som gör egna meningar bättre eller sämre
- `OLWEUS_Q` och `SUBJECT_Q` – frågorna på proven
- `DSCEN` – mobbning i gruppchatten

Schemat finns i `periods` i `scripts/schedule.gd`.

## Bygga webbversionen

1. Öppna projektet i Godot 4.3.
2. *Project → Export → Web* (presetet finns redan, "thread support" är avstängt så att det fungerar på GitHub Pages).
3. Exportera till `build/web/index.html` och lägg filerna på grenen `gh-pages`.

Testa utan grafik: `godot --headless --fixed-fps 60 res://tests/Test.tscn`
