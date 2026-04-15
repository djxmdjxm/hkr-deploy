# KIKA UI Design Vision

*Erstellt: 2026-04-15 — Grundlage: Frühstücksgespräch Annemarie + Christopher*
*Farben verifiziert: hamburg.de CSS-Analyse 2026-04-15*

---

## Zielgruppe

Mitarbeiter der 15 Landeskrebsregister — nicht zwingend technikaffin.
Das System muss ohne Schulung verständlich sein.

**Leitfrage für jede Design-Entscheidung:**
> „Würde ein Register-Sachbearbeiter ohne IT-Kenntnisse das sofort verstehen?"

---

## Stil: „Trusted Government Tool"

Nicht steril-bürokratisch, nicht verspielt.
Orientierung: modernes Behörden-Portal im Hamburg Corporate Design.
„Ein Tick schicker als hamburg.de" — gleiche Farben, mehr Luft, wärmere Ecken.

---

## Farben — Hamburg Corporate Design

Exakte Werte aus hamburg.de CSS-Analyse:

| Token | Hex | Verwendung |
|-------|-----|-----------|
| Primary Navy | `#003063` | Header, Stepper aktiv, Buttons |
| Deep Navy | `#002853` | Hover-Zustand, dunkle Akzente |
| Interactive Blue | `#0B70C8` | Links, sekundäre Buttons |
| Hamburg Rot | `#E10019` | Fehler-Zustand — sparsam |
| Background | `#F2F5F7` | Seitenhintergrund |
| Surface | `#FFFFFF` | Cards, Modals, Upload-Zone |
| Text primary | `#000000` | Fließtext |
| Text secondary | `#505050` | Metadaten, Labels |
| Text on Navy | `#FFFFFF` | Text auf blauem Hintergrund |
| Border | `#D8D8D8` | Trennlinien, Card-Rahmen |

**Unterschied zu hamburg.de:**
- Cards: `border-radius: 8px` + leichter `box-shadow` (hamburg.de: 0px, flach)
- Mehr Weißraum zwischen Elementen
- Tiefe durch Schatten, nicht durch Farbe

---

## Typografie

- **Lato** (wie hamburg.de) — Weights 300/400/600/700
- Fallback: `Arial, Helvetica, sans-serif`
- Großzügige Schriftgrößen — kein Kleingedrucktes
- Alle Texte ohne Fachbegriffs-Kenntnisse lesbar

---

## Kernseiten & UI-Elemente

### 1. Willkommensseite / Prozess-Übersicht

Prominent oben: ein **horizontaler Stepper** mit den 4 Prozessschritten:

```
[ 1. Upload ] → [ 2. Validierung ] → [ 3. Import ] → [ 4. Analyse ]
```

- Aktueller Schritt: Navy (#003063), aktiv hervorgehoben
- Künftige Schritte: ausgegraut (#D8D8D8)
- Fehler-Zustand: Rot (#E10019)
- Nutzer sieht auf einen Blick: wo bin ich, was kommt als nächstes

Darunter: kurze Erklärung des Gesamtzwecks in 2–3 Sätzen.

---

### 2. Upload-Bereich

- **Große Drag-and-Drop-Zone** (nicht ein kleines `<input type="file">`)
- Beschriftung: „XML-Datei hier ablegen oder klicken"
- **Schema-Versions-Auswahl** als Dropdown (z.B. `oBDS 3.0.4_RKI` als Standard)
- Dateiname + Größe wird nach Auswahl sofort angezeigt

---

### 3. Upload-Fortschritt

Während des Uploads (1 MB-Chunks, bereits im Backend implementiert):

- Sauberer **Fortschrittsbalken** in Navy (#003063)
- Prozentangabe + MB-Zähler: „4,2 MB von 18,7 MB hochgeladen"
- Kein Spinner ohne Information — der Nutzer sieht immer was passiert

---

### 4. Validierungsergebnis

Nach dem Upload: sofortige Rückmeldung ob die XML-Datei schema-konform ist.

**Erfolg:**
- Grünes Häkchen, kurze Bestätigung: „Datei ist gültig. Import wird gestartet."

**Fehler:**
- Rotes Icon (#E10019)
- **Menschlich lesbare Fehlermeldung** (kein roher Stacktrace)
- Klare Handlungsempfehlung: „Was bedeutet das? Was tun?"
- Beispiel: „Die Datei enthält ein unbekanntes Feld in Zeile 142. Bitte prüfen Sie, ob die richtige Schema-Version ausgewählt ist."

---

### 5. Import-Ergebnis / Kennzahlen-Dashboard

Nach erfolgreichem Import: **4 Kennzahlen-Cards** (große Kacheln, Icon + Zahl):

| Card | Inhalt | Beispiel |
|------|--------|---------|
| Patienten | Anzahl importierter Patienten | 4.823 |
| Meldungen | Anzahl Tumormeldungen | 5.104 |
| Diagnosejahre | Zeitraum der Diagnosen | 2014 – 2023 |
| Dateigröße | Größe der hochgeladenen Datei | 18,7 MB |

Zweck: Nutzer erkennt sofort ob er die richtige Datei hochgeladen hat.

---

## Tech Stack

| Technologie | Zweck | Begründung |
|-------------|-------|-----------|
| Next.js 15 + React 19 | Framework | Bereits vorhanden, state of the art |
| TypeScript | Typsicherheit | Pflicht für Produktivbetrieb |
| Tailwind CSS v4 | Styling | Responsive, konsistent |
| shadcn/ui | UI-Komponenten | Barrierefrei, air-gap-fähig, professionell |
| Lucide React | Icons | Minimalistisch, gut lesbar |
| Lato | Schrift | Konsistent mit Hamburg Corporate Design |

**Air-gap-Kompatibilität:** Lato wird lokal eingebunden (kein Google Fonts CDN).

---

## Responsive

- Vollständig responsive
- Optimiert für Desktop (1280px+) in Behörden
- Mobile: funktional, aber nicht primärer Use-Case

---

## Offene Punkte

- [ ] Analyse-Container (R/Python, code-server): Zugänglich für alle Nutzer oder nur Statistiker?
- [ ] Navigation: Braucht es eine Sidebar für spätere Erweiterungen?
