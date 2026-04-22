# Willkommen im KIKA Analyse-System

## So starten Sie Ihre erste Analyse

**Schritt 1:** Klicken Sie unten auf das **Terminal**-Panel (oder `Strg+J`)
**Schritt 2:** Tippen Sie folgenden Befehl ein und drücken Sie **Enter**:

```
Rscript analyse.R
```

**Das Skript verbindet sich automatisch mit der Datenbank.**
Kein Passwort, keine weitere Konfiguration nötig.

---

## Was `analyse.R` macht

| Abschnitt | Ergebnis |
|-----------|---------|
| Fallzahlen | Wie viele Patienten und Tumorfälle sind importiert |
| ICD-Codes | Welche Diagnosen kommen vor (z.B. C50.4) |
| Altersverteilung | Medianes Alter, Min/Max, Histogramm |

---

## Weitere Skripte

| Datei | Inhalt |
|-------|--------|
| `analyse.R` | Einfache erste Übersicht — hier starten |
| `examples/annemarie-example.R` | Erweiterte Mammakarzinom-Analyse (RT nach BET) |
| `examples/pg-connect-example.R` | Nur Datenbankverbindung als Vorlage |

---

## Tastenkürzel

| Aktion | Tastenkombination |
|--------|-----------------|
| Zeile ausführen | `Strg+Enter` |
| Alles ausführen | `Strg+A`, dann `Strg+Enter` |
| Datei speichern | `Strg+S` |
| Neue Datei | `Strg+N` |

---

*Bei Fragen: christopher.mangels@innopard.com*
