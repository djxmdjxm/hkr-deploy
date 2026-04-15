# KIKA UI Design Vision

*Erstellt: 2026-04-15 — Grundlage: Frühstücksgespräch Annemarie + Christopher*

---

## Zielgruppe

Mitarbeiter der 15 Landeskrebsregister — nicht zwingend technikaffin.
Das System muss ohne Schulung verständlich sein.

**Leitfrage für jede Design-Entscheidung:**
> „Würde ein Register-Sachbearbeiter ohne IT-Kenntnisse das sofort verstehen?"

---

## Stil: „Trusted Government Tool"

Nicht steril-bürokratisch, nicht verspielt.
Orientierung: moderne Behörden-Portale oder medizinische SaaS-Tools.

### Farben
- Weißer Hintergrund
- Eine ruhige Primärfarbe (tiefes Blau oder Teal — noch zu finalisieren)
- Akzentfarbe nur für CTAs, Erfolg- und Fehlerzustände

### Typografie
- Klare Sans-Serif
- Großzügige Schriftgrößen — kein Kleingedrucktes
- Alle Texte ohne Fachbegriff-Kenntnisse lesbar

### Responsive
- Vollständig responsive
- Optimiert für Desktop-Monitore in Behörden (1280px+)

---

## Kernseiten & UI-Elemente

### 1. Willkommensseite / Prozess-Übersicht

Prominent oben: ein **horizontaler Stepper** mit den 4 Prozessschritten:

```
[ 1. Upload ] → [ 2. Validierung ] → [ 3. Import ] → [ 4. Analyse ]
```

- Aktueller Schritt: aktiv/farbig hervorgehoben
- Künftige Schritte: ausgegraut
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

- Sauberer **Fortschrittsbalken** mit Prozentangabe
- MB-Zähler: „4,2 MB von 18,7 MB hochgeladen"
- Kein Spinner ohne Information — der Nutzer sieht immer was passiert

---

### 4. Validierungsergebnis

Nach dem Upload: sofortige Rückmeldung ob die XML-Datei schema-konform ist.

**Erfolg:**
- Grünes Häkchen, kurze Bestätigung: „Datei ist gültig. Import wird gestartet."

**Fehler:**
- Rotes Icon
- **Menschlich lesbare Fehlermeldung** (kein roher Stacktrace)
- Klare Handlungsempfehlung: „Was bedeutet das? Was tun?"
- Beispiel: „Die Datei enthält ein unbekanntes Feld in Zeile 142. Bitte prüfen Sie, ob die richtige Schema-Version ausgewählt ist."

---

### 5. Import-Ergebnis / Kennzahlen-Dashboard

Nach erfolgreichem Import: **3–4 Kennzahlen-Cards** (große Kacheln, Icon + Zahl):

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
| Tailwind CSS v4 | Styling | Responsive, konsistent, kein CSS-Chaos |
| shadcn/ui | UI-Komponenten | Barrierefrei, air-gap-fähig (kein CDN), professionell |
| Lucide React | Icons | Minimalistisch, gut lesbar |

**Air-gap-Kompatibilität:** Next.js baut zu statischen Assets / Node-Bundle — kein CDN nötig, funktioniert in der geschlossenen HKR-Umgebung.

---

## Offene Punkte

- [ ] Finale Primärfarbe (Blau vs. Teal) — Referenz-Screenshot von Annemarie/Christopher?
- [ ] Analyse-Container (R/Python, code-server): Zugänglich für alle Nutzer oder nur Statistiker?
- [ ] Navigation: Braucht es eine Sidebar oder reicht der Stepper?
