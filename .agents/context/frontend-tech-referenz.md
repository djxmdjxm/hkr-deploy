# Technische Referenz: HKR Upload-Frontend

**Stack:** Next.js 15 · React 19 · TypeScript · Tailwind CSS v4 · shadcn/ui · Lucide React
**Anwendungsfall:** Mehrstufiger XML-Datei-Upload-Workflow für das Hamburgische Krebsregister
**Umgebung:** Air-gapped Docker-Container (kein Internet nach Deployment)

---

## Inhaltsverzeichnis

1. [Next.js 15 App Router — Mehrstufige Wizards](#1-nextjs-15-app-router--mehrstufige-wizards)
2. [shadcn/ui — Relevante Komponenten](#2-shadcnui--relevante-komponenten)
3. [Tailwind CSS v4 — Änderungen gegenüber v3](#3-tailwind-css-v4--änderungen-gegenüber-v3)
4. [SVG-Animation für Upload-Fortschritt](#4-svg-animation-für-upload-fortschritt)
5. [Streaming Upload-Progress mit XHR in React](#5-streaming-upload-progress-mit-xhr-in-react)
6. [Air-Gap-Kompatibilität](#6-air-gap-kompatibilität)
7. [TypeScript-Patterns für diesen Anwendungsfall](#7-typescript-patterns-für-diesen-anwendungsfall)

---

## 1. Next.js 15 App Router — Mehrstufige Wizards

### 1.1 Überblick: App Router Grundprinzipien

Der App Router (seit Next.js 13, stable ab 14, Standard in 15) basiert auf einem **dateibasierten Routing-System** im `app/`-Verzeichnis. Jeder Ordner entspricht einem URL-Segment; spezielle Dateien (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`) steuern das Verhalten.

**Hierarchie eines Route-Segments:**
```
app/
  layout.tsx       ← Persistenter Shell (Navigation, Footer)
  page.tsx         ← Inhalt der Route
  loading.tsx      ← Suspense-Fallback (automatisch gerendert)
  error.tsx        ← Fehlergrenze für dieses Segment
```

### 1.2 Verzeichnisstruktur für den 4-Schritt-Workflow

Das Upload-Workflow-Feature für das HKR umfasst vier Schritte:

```
Upload → Validierung → Import → Ergebnisse
```

**Empfohlene Verzeichnisstruktur:**

```
src/app/
  upload/
    layout.tsx           ← Gemeinsames Layout mit Stepper-Navigation
    page.tsx             ← Schritt 1: Datei auswählen & hochladen
    validierung/
      page.tsx           ← Schritt 2: Validierungsergebnisse anzeigen
    import/
      page.tsx           ← Schritt 3: Import bestätigen & starten
    ergebnisse/
      page.tsx           ← Schritt 4: Abschlussbericht
```

**`src/app/upload/layout.tsx`** — Persistentes Layout mit Stepper:

```tsx
// Dieses Layout bleibt beim Navigieren zwischen den Schritten erhalten.
// Es ist ein Server Component (kein "use client"), da es keinen
// interaktiven State benötigt — der aktive Schritt wird aus der URL gelesen.

import { WizardStepper } from "@/components/upload/WizardStepper";

export default function UploadLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      {/* Stepper-Leiste: liest aktiven Schritt aus der URL */}
      <WizardStepper />
      {/* Seiteninhalt des jeweiligen Schritts */}
      <main className="mt-8">{children}</main>
    </div>
  );
}
```

### 1.3 Server Components vs. Client Components

**Grundprinzip:** Alles im App Router ist standardmäßig ein **Server Component**. Nur dort, wo Browser-APIs, State (`useState`) oder Event-Handler nötig sind, wird `"use client"` gesetzt.

| Kriterium | Server Component | Client Component |
|-----------|-----------------|-----------------|
| Direktive | keine (Standard) | `"use client"` am Dateianfang |
| Rendering | Nur auf dem Server | Server-SSR + Client-Hydration |
| Datenzugriff | Direkt (DB, FS, Secrets) | Via API-Calls |
| useState / useEffect | Nicht erlaubt | Erlaubt |
| Event-Handler (onClick etc.) | Nicht erlaubt | Erlaubt |
| Browser-APIs (window, document) | Nicht erlaubt | Erlaubt |

**Für den Upload-Wizard gilt:**

| Komponente | Typ | Begründung |
|------------|-----|-----------|
| `upload/layout.tsx` | Server | Nur Struktur, kein State |
| `upload/page.tsx` | Client | Drag-and-Drop, File-State, XHR |
| `upload/validierung/page.tsx` | Server | Liest Validierungsergebnis aus DB/API |
| `upload/import/page.tsx` | Client | Bestätigungs-Button, Loading-State |
| `upload/ergebnisse/page.tsx` | Server | Zeigt statische Ergebnisdaten |
| `WizardStepper` | Client | Liest URL mit `usePathname()` |
| `UploadDropzone` | Client | File-API, XHR, useState |
| `ProgressFlower` | Client | SVG-Animation, animierter State |

**`"use client"` muss nur an der Grenze gesetzt werden** — nicht in jeder Datei. Wenn `UploadDropzone` als Client Component markiert ist, können alle seine Kinder ebenfalls Client-Code ausführen.

### 1.4 URL-basiertes vs. State-basiertes Step-Management

**URL-basiertes Step-Management** (empfohlen für diesen Use Case):

```
/upload                → Schritt 1: Upload
/upload/validierung    → Schritt 2: Validierung
/upload/import         → Schritt 3: Import
/upload/ergebnisse     → Schritt 4: Ergebnisse
```

Vorteile:
- Browser-Zurück-Button funktioniert
- Direktlinks auf Schritte möglich (nützlich beim Debugging)
- Kein serverseitiger Session-State nötig
- Der aktive Schritt ist aus der URL ableitbar ohne globalen State

Nachteile:
- Zwischen-State (z.B. Job-ID nach Upload) muss weitergegeben werden
- Lösung: Query-Parameter (`?jobId=abc123`) oder temporärer Client-State via `sessionStorage`

**Schritt-zu-Schritt-Navigation mit `useRouter`:**

```tsx
"use client";

import { useRouter } from "next/navigation";

export function UploadPage() {
  const router = useRouter();

  async function handleUploadSuccess(jobId: string) {
    // Nach erfolgreichem Upload: weiter zu Schritt 2
    // jobId wird als Query-Parameter mitgegeben
    router.push(`/upload/validierung?jobId=${jobId}`);
  }

  return <UploadDropzone onSuccess={handleUploadSuccess} />;
}
```

**Stepper liest aktiven Schritt aus der URL:**

```tsx
"use client";

import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils"; // shadcn/ui Utility

const SCHRITTE = [
  { label: "Upload",       href: "/upload" },
  { label: "Validierung",  href: "/upload/validierung" },
  { label: "Import",       href: "/upload/import" },
  { label: "Ergebnisse",   href: "/upload/ergebnisse" },
];

export function WizardStepper() {
  const pathname = usePathname();

  // Aktiven Schritt anhand der aktuellen URL bestimmen
  const aktiverIndex = SCHRITTE.findLastIndex((s) =>
    pathname.startsWith(s.href)
  );

  return (
    <nav className="flex items-center gap-0">
      {SCHRITTE.map((schritt, index) => (
        <div key={schritt.href} className="flex items-center">
          {/* Schritt-Indikator */}
          <div
            className={cn(
              "flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold",
              index < aktiverIndex && "bg-hkr-navy text-white",   // abgeschlossen
              index === aktiverIndex && "bg-hkr-red text-white",  // aktiv
              index > aktiverIndex && "bg-gray-200 text-gray-500" // ausstehend
            )}
          >
            {index + 1}
          </div>
          {/* Schritt-Label */}
          <span
            className={cn(
              "ml-2 text-sm",
              index === aktiverIndex ? "font-semibold text-hkr-navy" : "text-gray-500"
            )}
          >
            {schritt.label}
          </span>
          {/* Verbindungslinie zwischen Schritten */}
          {index < SCHRITTE.length - 1 && (
            <div
              className={cn(
                "mx-3 h-0.5 w-12",
                index < aktiverIndex ? "bg-hkr-navy" : "bg-gray-200"
              )}
            />
          )}
        </div>
      ))}
    </nav>
  );
}
```

### 1.5 Loading States, Suspense und Streaming

**`loading.tsx` — automatische Suspense-Boundaries:**

Next.js erstellt automatisch eine `<Suspense>`-Grenze um das entsprechende `page.tsx`, wenn eine `loading.tsx` im gleichen Verzeichnis liegt:

```tsx
// src/app/upload/validierung/loading.tsx
// Wird angezeigt, während page.tsx seine Daten lädt.
// Ist ein Server Component — kein "use client" nötig.

export default function ValidierungLadeindikator() {
  return (
    <div className="space-y-4">
      {/* Skeleton-UI für Validierungsergebnisse */}
      <div className="h-8 w-1/3 animate-pulse rounded bg-gray-200" />
      <div className="h-32 animate-pulse rounded bg-gray-200" />
    </div>
  );
}
```

**Granulare Suspense-Grenzen für Teile einer Seite:**

```tsx
// src/app/upload/ergebnisse/page.tsx
import { Suspense } from "react";
import { ErgebnisKarten } from "@/components/upload/ErgebnisKarten";
import { FehlerListe } from "@/components/upload/FehlerListe";

export default async function ErgebnissePage({
  searchParams,
}: {
  // In Next.js 15: searchParams ist ein Promise — muss awaited werden
  searchParams: Promise<{ jobId: string }>;
}) {
  const { jobId } = await searchParams;

  return (
    <div className="space-y-6">
      {/* ErgebnisKarten lädt schnell */}
      <Suspense fallback={<p>Lade Zusammenfassung...</p>}>
        <ErgebnisKarten jobId={jobId} />
      </Suspense>

      {/* FehlerListe lädt langsamer — eigene Suspense-Grenze */}
      <Suspense fallback={<p>Lade Fehlerdetails...</p>}>
        <FehlerListe jobId={jobId} />
      </Suspense>
    </div>
  );
}
```

**Wichtig in Next.js 15:** `searchParams` und `params` sind jetzt **Promises**. Sie müssen mit `await` aufgelöst werden:

```tsx
// Next.js 14 (alt):
export default function Page({ searchParams }: { searchParams: { jobId: string } }) {
  const jobId = searchParams.jobId; // direkter Zugriff
}

// Next.js 15 (neu):
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ jobId: string }>;
}) {
  const { jobId } = await searchParams; // muss awaited werden
}
```

---

## 2. shadcn/ui — Relevante Komponenten

### 2.1 Was ist shadcn/ui?

shadcn/ui ist **keine npm-Bibliothek** im traditionellen Sinne. Es ist eine Sammlung von Copy-Paste-Komponenten, die auf **Radix UI** (zugängliche, headless Primitives) und **Tailwind CSS** aufbauen. Der entscheidende Unterschied:

- Komponenten werden **in das eigene Projekt kopiert** (nach `src/components/ui/`)
- Sie sind vollständig anpassbar — kein Styles überschreiben nötig
- Keine Paketabhängigkeit auf shadcn/ui selbst nach der Installation
- Air-gap-sicher: Alle Abhängigkeiten landen in `package.json`

### 2.2 Installation (mit Tailwind v4)

**Voraussetzung:** Next.js 15-Projekt mit Tailwind v4 bereits eingerichtet.

```bash
# shadcn/ui CLI initialisieren (Tailwind v4 wird automatisch erkannt)
pnpm dlx shadcn@latest init

# Einzelne Komponenten hinzufügen:
pnpm dlx shadcn@latest add button
pnpm dlx shadcn@latest add card
pnpm dlx shadcn@latest add progress
pnpm dlx shadcn@latest add alert
pnpm dlx shadcn@latest add badge
pnpm dlx shadcn@latest add separator
pnpm dlx shadcn@latest add toast
```

Der `init`-Befehl:
1. Erstellt `components.json` (Konfigurationsdatei)
2. Fügt CSS-Variablen in `globals.css` ein (Design-Tokens)
3. Erstellt `src/lib/utils.ts` mit der `cn()`-Hilfsfunktion
4. Installiert Abhängigkeiten (`radix-ui`, `class-variance-authority`, `clsx`, `tailwind-merge`)

**Nach `init` sieht `globals.css` so aus (Tailwind v4 Variante):**

```css
@import "tailwindcss";
@import "tw-animate-css"; /* Animation-Bibliothek (Ersatz für tailwindcss-animate) */

:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.97 0 0);
  --secondary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --radius: 0.625rem;
}

.dark {
  /* Dark-Mode-Variablen ... */
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  /* ... weitere Token-Mappings ... */
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
}
```

### 2.3 Relevante Komponenten für den HKR Upload-Workflow

#### Button

```tsx
import { Button } from "@/components/ui/button";

// Varianten: default, destructive, outline, secondary, ghost, link
<Button variant="default">Datei hochladen</Button>
<Button variant="destructive">Abbrechen</Button>
<Button variant="outline" disabled={isLoading}>
  Zurück
</Button>
```

#### Card — Ergebnis-Karten

```tsx
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export function ErgebnisKarte({ titel, beschreibung, kinder }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{titel}</CardTitle>
        <CardDescription>{beschreibung}</CardDescription>
      </CardHeader>
      <CardContent>{kinder}</CardContent>
    </Card>
  );
}
```

#### Progress — Upload-Fortschrittsbalken

```tsx
import { Progress } from "@/components/ui/progress";

// value: Zahl von 0 bis 100
<Progress value={uploadProgress} className="h-2" />
```

#### Alert — Fehler- und Erfolgsmeldungen

```tsx
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { AlertCircle, CheckCircle2 } from "lucide-react";

// Fehleranzeige:
<Alert variant="destructive">
  <AlertCircle className="h-4 w-4" />
  <AlertTitle>Validierungsfehler</AlertTitle>
  <AlertDescription>
    Die XML-Datei enthält 3 Fehler. Bitte korrigieren Sie die Datei.
  </AlertDescription>
</Alert>

// Erfolgsanzeige:
<Alert className="border-green-500 bg-green-50">
  <CheckCircle2 className="h-4 w-4 text-green-600" />
  <AlertTitle className="text-green-800">Import erfolgreich</AlertTitle>
  <AlertDescription className="text-green-700">
    247 Datensätze wurden importiert.
  </AlertDescription>
</Alert>
```

#### Badge — Status-Labels

```tsx
import { Badge } from "@/components/ui/badge";

// Varianten: default, secondary, destructive, outline
<Badge variant="destructive">Fehler</Badge>
<Badge variant="secondary">Warnung</Badge>
<Badge className="bg-green-100 text-green-800">Erfolg</Badge>
```

#### Separator — visuelle Trennlinie

```tsx
import { Separator } from "@/components/ui/separator";

<Separator className="my-4" />
```

#### Toast — temporäre Benachrichtigungen

```tsx
// Zunächst: Toaster in Layout einbinden
import { Toaster } from "@/components/ui/toaster";

// In layout.tsx:
export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Toaster />
      </body>
    </html>
  );
}

// In Client Components:
import { useToast } from "@/hooks/use-toast";

export function UploadForm() {
  const { toast } = useToast();

  function handleError(nachricht: string) {
    toast({
      title: "Fehler beim Upload",
      description: nachricht,
      variant: "destructive",
    });
  }
}
```

### 2.4 Datei-Upload-Zone (kein fertiges shadcn-Primitive — selbst bauen)

shadcn/ui hat keine eingebaute Dropzone-Komponente. Die Empfehlung: selbst bauen auf Basis von `Button` und nativen HTML-File-Inputs:

```tsx
"use client";

import { useRef, useState, DragEvent } from "react";
import { Button } from "@/components/ui/button";
import { UploadCloud } from "lucide-react";
import { cn } from "@/lib/utils";

interface UploadDropzoneProps {
  onDateiAusgewaehlt: (datei: File) => void;
  akzeptierteTypen?: string; // z.B. ".xml,application/xml"
}

export function UploadDropzone({
  onDateiAusgewaehlt,
  akzeptierteTypen = ".xml",
}: UploadDropzoneProps) {
  const [isDragOver, setIsDragOver] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  function handleDrop(e: DragEvent<HTMLDivElement>) {
    e.preventDefault();
    setIsDragOver(false);
    const datei = e.dataTransfer.files[0];
    if (datei) onDateiAusgewaehlt(datei);
  }

  return (
    <div
      onDrop={handleDrop}
      onDragOver={(e) => { e.preventDefault(); setIsDragOver(true); }}
      onDragLeave={() => setIsDragOver(false)}
      className={cn(
        "flex flex-col items-center justify-center rounded-lg border-2 border-dashed p-12 transition-colors",
        isDragOver
          ? "border-hkr-navy bg-blue-50"
          : "border-gray-300 hover:border-gray-400"
      )}
    >
      <UploadCloud className="mb-4 h-12 w-12 text-gray-400" />
      <p className="mb-2 text-lg font-semibold text-gray-700">
        XML-Datei hier ablegen
      </p>
      <p className="mb-4 text-sm text-gray-500">oder</p>
      <Button
        variant="outline"
        onClick={() => inputRef.current?.click()}
      >
        Datei auswählen
      </Button>
      {/* Verstecktes File-Input — wird über Button ausgelöst */}
      <input
        ref={inputRef}
        type="file"
        accept={akzeptierteTypen}
        className="hidden"
        onChange={(e) => {
          const datei = e.target.files?.[0];
          if (datei) onDateiAusgewaehlt(datei);
        }}
      />
    </div>
  );
}
```

### 2.5 Stepper-Komponente (kein fertiges shadcn-Primitive)

shadcn/ui enthält keinen Stepper. Die Optionen:

1. **Selbst bauen** (wie im WizardStepper oben gezeigt) — empfohlen für volle Kontrolle
2. **`shadcn-stepper` Community-Package:** `pnpm dlx shadcn@latest add https://shadcn-stepper.vercel.app`
3. **Einfache Tab-Leiste** mit `Tabs`-Komponente (funktioniert auch als visueller Stepper)

### 2.6 Anpassen von shadcn-Komponenten

Da Komponenten im eigenen Repo liegen, kann man sie direkt editieren. Für einmalige Anpassungen besser `className` nutzen:

```tsx
// Tailwind-Klassen überschreiben via className-Prop
// tailwind-merge (in cn()) sorgt dafür, dass Konflikte korrekt aufgelöst werden
<Button className="bg-hkr-navy hover:bg-hkr-navy/90">
  Importieren
</Button>

// Für strukturelle Änderungen: Datei src/components/ui/button.tsx direkt editieren
```

---

## 3. Tailwind CSS v4 — Änderungen gegenüber v3

### 3.1 Das Wichtigste vorab: Was sich geändert hat

Tailwind CSS v4 (erschienen Januar 2025) ist eine **Neuentwicklung** mit grundlegend anderem Konfigurationsansatz. Die wichtigsten Änderungen auf einen Blick:

| Aspekt | v3 | v4 |
|--------|----|----|
| Konfigurationsdatei | `tailwind.config.js` | Keine — CSS-first via `@theme` |
| CSS-Import | `@tailwind base; @tailwind components; @tailwind utilities;` | `@import "tailwindcss";` |
| PostCSS-Plugin | `tailwindcss` | `@tailwindcss/postcss` |
| Farbformat | RGB/HSL | OKLCH (Standard) |
| Theme-Werte | JavaScript-Objekt | CSS Custom Properties |
| Autoprefixer | Separates Plugin | Eingebaut |
| Content-Pfade | Explizit in Config | Automatisch erkannt |

### 3.2 Installation und Setup

```bash
# Pakete installieren
pnpm add -D tailwindcss @tailwindcss/postcss

# KEIN tailwind.config.js mehr nötig
```

**`postcss.config.mjs`:**

```javascript
// Kein tailwindcss-Plugin mehr — stattdessen @tailwindcss/postcss
// Kein autoprefixer mehr — ist in @tailwindcss/postcss eingebaut
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

**`globals.css` — minimale Konfiguration:**

```css
/* Einzige benötigte Zeile — ersetzt alle drei @tailwind-Direktiven aus v3 */
@import "tailwindcss";
```

### 3.3 CSS-First-Konfiguration mit `@theme`

In v4 werden alle Design-Tokens direkt in der CSS-Datei als CSS Custom Properties definiert:

```css
@import "tailwindcss";

@theme {
  /* Schriften */
  --font-sans: "Lato", ui-sans-serif, system-ui, sans-serif;
  --font-mono: ui-monospace, monospace;

  /* Breakpoints */
  --breakpoint-sm: 640px;
  --breakpoint-md: 768px;
  --breakpoint-lg: 1024px;
  --breakpoint-xl: 1280px;

  /* Abstände (Erweiterung der Standard-Skala) */
  --spacing-18: 4.5rem;

  /* Farben (werden zu Tailwind-Utilities: bg-hkr-navy, text-hkr-red, etc.) */
  --color-hkr-navy: #003063;
  --color-hkr-navy-light: #0a4a8f;
  --color-hkr-red: #E10019;
  --color-hkr-red-light: #ff1a2e;
  --color-hkr-gray: #f5f5f5;

  /* Border-Radius */
  --radius: 0.5rem;
}
```

**Alle in `@theme` definierten Werte sind automatisch:**
- Als Tailwind-Utility-Klassen verfügbar: `bg-hkr-navy`, `text-hkr-red`, `border-hkr-navy`
- Als CSS Custom Properties im DOM verfügbar: `var(--color-hkr-navy)`

### 3.4 Hamburger Farbpalette für das HKR

Hamburg Rot und Hamburg Navy als Projektfarben:

```css
@import "tailwindcss";
@import "tw-animate-css"; /* Animations-Plugin für shadcn/ui */

/* ======================================================
   HKR Design Tokens
   Hamburg Rot: #E10019 — für Aktionen, Fehler, Akzente
   Hamburg Navy: #003063 — für primäre Elemente, Buttons
   ====================================================== */
@theme {
  /* Primärfarbe: Hamburg Navy */
  --color-hkr-navy: #003063;
  --color-hkr-navy-light: #0a4a8f;
  --color-hkr-navy-dark: #001f42;

  /* Akzentfarbe: Hamburg Rot */
  --color-hkr-red: #E10019;
  --color-hkr-red-light: #ff1a2e;
  --color-hkr-red-dark: #b3000f;

  /* Neutrale Farben */
  --color-hkr-gray-50: #f9fafb;
  --color-hkr-gray-100: #f3f4f6;
  --color-hkr-gray-200: #e5e7eb;
  --color-hkr-gray-800: #1f2937;

  /* Semantische Farben */
  --color-hkr-success: #166534;    /* Grün für Import-Erfolg */
  --color-hkr-success-bg: #dcfce7;
  --color-hkr-warning: #92400e;    /* Orange für Warnungen */
  --color-hkr-warning-bg: #fef3c7;
  --color-hkr-error: #991b1b;      /* Rot für Fehler */
  --color-hkr-error-bg: #fee2e2;

  /* Typografie */
  --font-sans: "Lato", ui-sans-serif, system-ui, sans-serif;
}

/* shadcn/ui Design Tokens — werden von den Komponenten verwendet */
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: #003063;         /* HKR Navy als Primärfarbe */
  --primary-foreground: white;
  --destructive: #E10019;     /* HKR Rot für Fehler */
  --border: oklch(0.922 0 0);
  --radius: 0.5rem;
}

@theme inline {
  /* Mapping von shadcn-Tokens auf Tailwind-Utilities */
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-destructive: var(--destructive);
  --color-border: var(--border);
}
```

**Verwendung der HKR-Farben:**

```tsx
// Tailwind-Utility-Klassen (automatisch aus @theme generiert):
<button className="bg-hkr-navy text-white hover:bg-hkr-navy-light">
  Importieren
</button>

<div className="border-l-4 border-hkr-red bg-hkr-error-bg p-4">
  <p className="text-hkr-error">Fehler: ...</p>
</div>

// CSS Custom Properties (für SVG-Animationen etc.):
const farbe = "var(--color-hkr-navy)";
```

### 3.5 Breaking Changes — Migration v3 → v4

**Wichtige umbenannte Utilities:**

| v3 | v4 | Hinweis |
|----|----|----|
| `shadow-sm` | `shadow-xs` | Skala verschoben |
| `shadow` | `shadow-sm` | Skala verschoben |
| `blur-sm` | `blur-xs` | Skala verschoben |
| `rounded-sm` | `rounded-xs` | Skala verschoben |
| `ring` | `ring-3` | Standard-Breite geändert |
| `outline-none` | `outline-hidden` | Semantisch klarer |
| `bg-opacity-50` | `bg-black/50` | Opacity-Modifier statt separate Utility |
| `flex-shrink-0` | `shrink-0` | Kürzer |
| `flex-grow` | `grow` | Kürzer |
| `bg-gradient-to-r` | `bg-linear-to-r` | CSS-native Benennung |

**Standard-Verhalten geändert:**

```html
<!-- v3: border ohne Farbklasse = gray-200 -->
<!-- v4: border ohne Farbklasse = currentColor — IMMER explizite Farbe angeben -->
<div class="border border-gray-200 px-4 py-2">Inhalt</div>

<!-- v3: Wichtig-Modifier war am Anfang -->
<!-- v4: Wichtig-Modifier ist am Ende -->
<div class="flex! bg-hkr-navy!">  <!-- v4 -->

<!-- v3: Beliebige Werte mit [...] und Komma -->
<!-- v4: Leerzeichen in beliebigen Werten mit _ statt Leerzeichen -->
<div class="grid-cols-[1fr_2fr_1fr]">  <!-- v4: Unterstriche statt Leerzeichen -->
```

**Automatisches Migrations-Tool:**

```bash
# Führt automatische Umbenennung durch
npx @tailwindcss/upgrade
```

### 3.6 `@theme inline` vs. `@theme`

Es gibt zwei Varianten:

- **`@theme`** — Definiert eigenständige Design-Token-Werte
- **`@theme inline`** — Mappt existierende CSS Custom Properties auf Tailwind-Utilities (kein neues `:root` wird generiert)

shadcn/ui nutzt `@theme inline`, um seine `:root`-Variablen auf Tailwind-Utilities zu mappen, ohne sie zu duplizieren.

---

## 4. SVG-Animation für Upload-Fortschritt

### 4.1 Grundprinzip: stroke-dasharray / stroke-dashoffset

Die gängigste Technik für SVG-Pfad-Animationen (z.B. eine wachsende Blume) nutzt zwei SVG-Attribute:

- **`stroke-dasharray`**: Definiert das Muster von Strichen und Lücken. Mit `stroke-dasharray="100"` wird ein Pfad mit einer einzelnen Strichlänge von 100 Einheiten gezeichnet (= Gesamtlänge des Pfads).
- **`stroke-dashoffset`**: Verschiebt den Startpunkt des Dash-Musters. Bei `stroke-dashoffset="100"` (= volle Länge) ist der Pfad unsichtbar. Bei `stroke-dashoffset="0"` ist er vollständig gezeichnet.

**Fortschrittsformel:**

```
offset = pfadLaenge * (1 - fortschritt / 100)

Bei 0%:   offset = pfadLaenge → Pfad unsichtbar
Bei 50%:  offset = pfadLaenge / 2 → Pfad halb gezeichnet
Bei 100%: offset = 0 → Pfad vollständig gezeichnet
```

### 4.2 React-Komponente: Animierter Kreisfortschritt (einfache Variante)

```tsx
"use client";

// Einfacher animierter Fortschrittsring — Basis für komplexere Blumen-Variante

interface FortschrittsringProps {
  fortschritt: number;  // 0 bis 100
  groesse?: number;     // Durchmesser in px (Standard: 120)
  strichBreite?: number;
}

export function Fortschrittsring({
  fortschritt,
  groesse = 120,
  strichBreite = 8,
}: FortschrittsringProps) {
  const radius = (groesse - strichBreite) / 2;
  // Umfang des Kreises = 2 * π * r
  const umfang = 2 * Math.PI * radius;
  // Offset = wie viel "fehlt" noch bis 100%
  const offset = umfang * (1 - fortschritt / 100);

  return (
    <svg
      width={groesse}
      height={groesse}
      viewBox={`0 0 ${groesse} ${groesse}`}
      aria-label={`Upload-Fortschritt: ${Math.round(fortschritt)}%`}
      role="progressbar"
      aria-valuenow={Math.round(fortschritt)}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      {/* Hintergrundring (statisch, grau) */}
      <circle
        cx={groesse / 2}
        cy={groesse / 2}
        r={radius}
        fill="none"
        stroke="#e5e7eb"   /* gray-200 */
        strokeWidth={strichBreite}
      />
      {/* Fortschrittsring (animiert) */}
      <circle
        cx={groesse / 2}
        cy={groesse / 2}
        r={radius}
        fill="none"
        stroke="#003063"   /* HKR Navy */
        strokeWidth={strichBreite}
        strokeLinecap="round"
        strokeDasharray={umfang}
        strokeDashoffset={offset}
        /* Drehung: SVG beginnt rechts (3 Uhr), wir wollen oben (12 Uhr) */
        transform={`rotate(-90 ${groesse / 2} ${groesse / 2})`}
        style={{
          /* Transition für flüssige Animation bei jedem Fortschritts-Update */
          transition: "stroke-dashoffset 0.3s ease-in-out",
        }}
      />
      {/* Prozentzahl in der Mitte */}
      <text
        x="50%"
        y="50%"
        textAnchor="middle"
        dominantBaseline="middle"
        className="fill-hkr-navy text-lg font-bold"
        style={{ fontSize: "1.25rem", fontWeight: 700 }}
      >
        {Math.round(fortschritt)}%
      </text>
    </svg>
  );
}
```

### 4.3 Animierte Blume / Rose — Petal-by-Petal Reveal

Für eine stilisierte Blume, die mit dem Upload-Fortschritt "aufblüht", gibt es zwei Ansätze:

**Ansatz A: Mehrere unabhängige Blütenblätter (einfacher)**

```tsx
"use client";

// Blüte mit 8 Blütenblättern — jedes erscheint sequenziell mit dem Fortschritt

const BLUETENBLAETTER_PFADE = [
  "M 60 60 Q 60 20 80 10 Q 100 0 80 40 Z",  // oben
  "M 60 60 Q 90 40 110 50 Q 130 60 90 70 Z", // oben-rechts
  // ... weitere 6 Blütenblätter
];

interface BlueteProps {
  fortschritt: number; // 0 bis 100
}

export function UploadBluete({ fortschritt }: BlueteProps) {
  const anzahlAktiv = Math.floor((fortschritt / 100) * BLUETENBLAETTER_PFADE.length);

  return (
    <svg viewBox="0 0 120 120" width="160" height="160">
      {BLUETENBLAETTER_PFADE.map((pfad, i) => (
        <path
          key={i}
          d={pfad}
          fill={i < anzahlAktiv ? "#003063" : "#e5e7eb"}
          style={{
            transition: "fill 0.4s ease",
            // Leichte Verzögerung je Blütenblatt für Kaskaden-Effekt
            transitionDelay: `${i * 0.05}s`,
          }}
        />
      ))}
      {/* Blütenmitte */}
      <circle cx="60" cy="60" r="12" fill="#E10019" />
      {/* Prozentzahl */}
      <text
        x="60"
        y="64"
        textAnchor="middle"
        fill="white"
        style={{ fontSize: "9px", fontWeight: "bold" }}
      >
        {Math.round(fortschritt)}%
      </text>
    </svg>
  );
}
```

**Ansatz B: Spiralförmiger Pfad mit stroke-dashoffset (avanciert)**

```tsx
"use client";

import { useEffect, useRef } from "react";

// Spiral-/Rosetten-Pfad: Animierter SVG-Pfad der sich mit Fortschritt "aufzeichnet"
// Gesamtlänge des Pfads wird einmalig berechnet und für die Animation verwendet.

interface AnimiertePfadBlumProps {
  fortschritt: number;
}

export function AnimiertePfadBlume({ fortschritt }: AnimiertePfadBlumProps) {
  const pfadRef = useRef<SVGPathElement>(null);

  // Rosettenförmiger Pfad (Parametrisierte Darstellung)
  // Dieser Pfad beschreibt eine 5-blättrige Rose
  const ROSENWEG =
    "M 100 50 " +
    "C 100 30, 120 10, 100 10 C 80 10, 80 30, 100 30 " + // Blütenblatt 1
    "C 100 30, 130 20, 140 40 C 150 60, 130 70, 120 55 " + // Blütenblatt 2
    "C 120 55, 140 80, 125 95 C 110 110, 95 95, 100 80 " + // Blütenblatt 3
    "C 100 80, 85 110, 70 100 C 55 90, 65 70, 80 75 " + // Blütenblatt 4
    "C 80 75, 50 65, 55 45 C 60 25, 80 30, 100 50"; // Blütenblatt 5

  useEffect(() => {
    const pfad = pfadRef.current;
    if (!pfad) return;

    const gesamtlaenge = pfad.getTotalLength();
    pfad.style.strokeDasharray = `${gesamtlaenge}`;
    pfad.style.strokeDashoffset = `${gesamtlaenge * (1 - fortschritt / 100)}`;
  }, [fortschritt]);

  return (
    <svg
      viewBox="0 0 200 200"
      width="160"
      height="160"
      role="progressbar"
      aria-valuenow={Math.round(fortschritt)}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      {/* Hintergrundpfad (hellgrau, statisch) */}
      <path d={ROSENWEG} fill="none" stroke="#e5e7eb" strokeWidth="4" />
      {/* Animierter Fortschrittspfad */}
      <path
        ref={pfadRef}
        d={ROSENWEG}
        fill="none"
        stroke="#003063"    /* HKR Navy */
        strokeWidth="4"
        strokeLinecap="round"
        style={{ transition: "stroke-dashoffset 0.3s ease-in-out" }}
      />
      {/* Mittelpunkt: HKR Rot */}
      <circle cx="100" cy="100" r="15" fill="#E10019" />
      <text
        x="100"
        y="105"
        textAnchor="middle"
        fill="white"
        style={{ fontSize: "11px", fontWeight: "bold" }}
      >
        {Math.round(fortschritt)}%
      </text>
    </svg>
  );
}
```

### 4.4 CSS-Keyframe-Animation für Idle-State

Wenn kein Upload läuft, kann eine sanfte Pulsier-Animation den Idle-Zustand visualisieren:

```css
/* In globals.css — funktioniert mit Tailwind v4 */
@keyframes bluete-pulsieren {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%       { opacity: 0.7; transform: scale(0.97); }
}

.bluete-idle {
  animation: bluete-pulsieren 2s ease-in-out infinite;
}
```

```tsx
// In der Komponente:
<svg className={fortschritt === 0 ? "bluete-idle" : ""}>
  {/* ... */}
</svg>
```

---

## 5. Streaming Upload-Progress mit XHR in React

### 5.1 Warum XHR statt fetch?

Die moderne `fetch`-API unterstützt **kein Upload-Progress-Tracking**. `fetch` kann nur Download-Progress über `response.body` (ReadableStream) melden. Für Upload-Fortschritt ist `XMLHttpRequest` (XHR) zwingend erforderlich:

| Feature | fetch | XMLHttpRequest |
|---------|-------|----------------|
| Upload-Progress | Nicht möglich | `xhr.upload.onprogress` |
| Download-Progress | `response.body` (ReadableStream) | `xhr.onprogress` |
| Async/Await | Ja | Nein (Callbacks) |
| Abbrechen | `AbortController` | `xhr.abort()` |
| TypeScript-Support | Vollständig | Vollständig |

### 5.2 Custom Hook: `useXhrUpload`

```tsx
"use client";

import { useState, useRef, useCallback } from "react";

// Typen für den Upload-Status
type UploadStatus = "idle" | "uploading" | "success" | "error";

interface UploadState {
  status: UploadStatus;
  fortschritt: number;     // 0-100
  fehlerNachricht: string | null;
  jobId: string | null;    // ID der erstellten Import-Job nach erfolgreichem Upload
}

interface UseXhrUploadOptions {
  url: string;             // Upload-Endpunkt, z.B. "/api/upload"
  feldName?: string;       // FormData-Feldname (Standard: "datei")
}

interface UseXhrUploadResult {
  state: UploadState;
  starten: (datei: File) => void;
  abbrechen: () => void;
  zuruecksetzen: () => void;
}

/**
 * Custom Hook für XHR-basiertes File-Upload mit Fortschritts-Tracking.
 * Verwendet XMLHttpRequest, da fetch keine Upload-Progress-Events unterstützt.
 */
export function useXhrUpload({
  url,
  feldName = "datei",
}: UseXhrUploadOptions): UseXhrUploadResult {
  const [state, setState] = useState<UploadState>({
    status: "idle",
    fortschritt: 0,
    fehlerNachricht: null,
    jobId: null,
  });

  // Ref für XHR-Instanz — ermöglicht Abbrechen von außen
  const xhrRef = useRef<XMLHttpRequest | null>(null);

  const starten = useCallback(
    (datei: File) => {
      // Alten Request abbrechen falls noch aktiv
      if (xhrRef.current) {
        xhrRef.current.abort();
      }

      const xhr = new XMLHttpRequest();
      xhrRef.current = xhr;

      // --- Upload-Fortschritt-Event ---
      // Wird während des Uploads wiederholt ausgelöst
      // e.loaded = bereits gesendete Bytes
      // e.total = Gesamtgröße der Datei
      // e.lengthComputable = ob total bekannt ist (fast immer true für File-Uploads)
      xhr.upload.onprogress = (e: ProgressEvent) => {
        if (e.lengthComputable) {
          const prozent = Math.round((e.loaded / e.total) * 100);
          setState((prev) => ({
            ...prev,
            status: "uploading",
            fortschritt: prozent,
          }));
        }
      };

      // --- Erfolgreicher Abschluss ---
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          // Server antwortet mit JSON: { jobId: "abc123" }
          const antwort: { jobId: string } = JSON.parse(xhr.responseText);
          setState({
            status: "success",
            fortschritt: 100,
            fehlerNachricht: null,
            jobId: antwort.jobId,
          });
        } else {
          // HTTP-Fehler (4xx, 5xx)
          let meldung = `Server-Fehler: HTTP ${xhr.status}`;
          try {
            const fehler = JSON.parse(xhr.responseText);
            meldung = fehler.message ?? meldung;
          } catch {
            // Antwort war kein JSON — ignorieren
          }
          setState({
            status: "error",
            fortschritt: 0,
            fehlerNachricht: meldung,
            jobId: null,
          });
        }
      };

      // --- Netzwerkfehler ---
      xhr.onerror = () => {
        setState({
          status: "error",
          fortschritt: 0,
          fehlerNachricht: "Netzwerkfehler beim Upload. Bitte erneut versuchen.",
          jobId: null,
        });
      };

      // --- Upload abgebrochen ---
      xhr.onabort = () => {
        setState({
          status: "idle",
          fortschritt: 0,
          fehlerNachricht: null,
          jobId: null,
        });
      };

      // FormData erstellen und senden
      const formData = new FormData();
      formData.append(feldName, datei);

      xhr.open("POST", url);
      setState({ status: "uploading", fortschritt: 0, fehlerNachricht: null, jobId: null });
      xhr.send(formData);
    },
    [url, feldName]
  );

  const abbrechen = useCallback(() => {
    xhrRef.current?.abort();
  }, []);

  const zuruecksetzen = useCallback(() => {
    xhrRef.current?.abort();
    setState({ status: "idle", fortschritt: 0, fehlerNachricht: null, jobId: null });
  }, []);

  return { state, starten, abbrechen, zuruecksetzen };
}
```

### 5.3 Verwendung des Hooks mit SVG-Animation

```tsx
"use client";

import { useRouter } from "next/navigation";
import { useXhrUpload } from "@/hooks/useXhrUpload";
import { AnimiertePfadBlume } from "@/components/upload/AnimiertePfadBlume";
import { UploadDropzone } from "@/components/upload/UploadDropzone";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { AlertCircle } from "lucide-react";

export function UploadBereich() {
  const router = useRouter();
  const { state, starten, abbrechen, zuruecksetzen } = useXhrUpload({
    url: "/api/upload",
  });

  // Nach erfolgreichem Upload: automatisch zu Schritt 2 navigieren
  if (state.status === "success" && state.jobId) {
    router.push(`/upload/validierung?jobId=${state.jobId}`);
  }

  return (
    <div className="space-y-6">
      {/* Dropzone — nur sichtbar im Idle-Zustand */}
      {state.status === "idle" && (
        <UploadDropzone
          onDateiAusgewaehlt={starten}
          akzeptierteTypen=".xml,application/xml"
        />
      )}

      {/* SVG-Animation während des Uploads */}
      {state.status === "uploading" && (
        <div className="flex flex-col items-center gap-4 py-8">
          <AnimiertePfadBlume fortschritt={state.fortschritt} />
          <p className="text-sm text-gray-600">
            Datei wird hochgeladen... {state.fortschritt}%
          </p>
          <Button variant="outline" onClick={abbrechen}>
            Abbrechen
          </Button>
        </div>
      )}

      {/* Fehleranzeige */}
      {state.status === "error" && (
        <div className="space-y-4">
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertTitle>Upload fehlgeschlagen</AlertTitle>
            <AlertDescription>{state.fehlerNachricht}</AlertDescription>
          </Alert>
          <Button onClick={zuruecksetzen}>Erneut versuchen</Button>
        </div>
      )}
    </div>
  );
}
```

### 5.4 Server-seitiger Upload-Endpunkt (Next.js Route Handler)

```tsx
// src/app/api/upload/route.ts
// Route Handler in Next.js App Router — ersetzt /pages/api/

import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  // formData() liest multipart/form-data aus dem Request
  const formData = await request.formData();
  const datei = formData.get("datei");

  if (!datei || !(datei instanceof File)) {
    return NextResponse.json(
      { message: "Keine Datei übermittelt" },
      { status: 400 }
    );
  }

  // Datei validieren (MIME-Type, Dateigröße)
  if (!datei.name.endsWith(".xml") && datei.type !== "application/xml") {
    return NextResponse.json(
      { message: "Nur XML-Dateien werden akzeptiert" },
      { status: 422 }
    );
  }

  // Datei-Inhalt lesen
  const inhalt = await datei.text();

  // Hier: Import-Job in der Datenbank anlegen und Datei speichern
  // const job = await db.importJob.create({ ... });

  // Job-ID zurückgeben — Client navigiert damit zu Schritt 2
  return NextResponse.json({ jobId: "job_" + Date.now() }, { status: 201 });
}
```

---

## 6. Air-Gap-Kompatibilität

Das HKR-Frontend läuft in einem Docker-Container ohne Internet-Zugang nach dem Deployment. Folgende Punkte müssen beachtet werden:

### 6.1 Lato-Schrift lokal einbinden

**Problem:** `next/font/google` lädt beim ersten Build die Schrift von Google Fonts herunter. In einer Air-Gap-Umgebung schlägt dieser Download fehl.

**Lösung:** Schrift-Dateien manuell herunterladen und `next/font/local` verwenden.

**Schritt 1: Lato-Schriftdateien herunterladen**

Die `.woff2`-Dateien von Google Fonts oder fonts.google.com herunterladen:
- `Lato-Regular.woff2` (weight 400)
- `Lato-Italic.woff2` (weight 400, italic)
- `Lato-Bold.woff2` (weight 700)
- `Lato-BoldItalic.woff2` (weight 700, italic)

Ablegen in: `src/app/fonts/`

**Schritt 2: `localFont` konfigurieren**

```tsx
// src/app/layout.tsx
import localFont from "next/font/local";

// Lato als lokale Schrift einbinden — kein Netzwerkaufruf zur Build- oder Laufzeit
const lato = localFont({
  src: [
    {
      path: "./fonts/Lato-Regular.woff2",
      weight: "400",
      style: "normal",
    },
    {
      path: "./fonts/Lato-Italic.woff2",
      weight: "400",
      style: "italic",
    },
    {
      path: "./fonts/Lato-Bold.woff2",
      weight: "700",
      style: "normal",
    },
    {
      path: "./fonts/Lato-BoldItalic.woff2",
      weight: "700",
      style: "italic",
    },
  ],
  // CSS-Variable für Verwendung in @theme
  variable: "--font-lato",
  // font-display: swap verhindert unsichtbaren Text während des Ladens
  display: "swap",
});

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    // className + variable setzen damit die Schrift in Tailwind verfügbar ist
    <html lang="de" className={`${lato.className} ${lato.variable}`}>
      <body>{children}</body>
    </html>
  );
}
```

**Schritt 3: Schrift in `@theme` referenzieren**

```css
/* globals.css */
@theme {
  /* Lato via CSS-Variable die in layout.tsx gesetzt wird */
  --font-sans: var(--font-lato), ui-sans-serif, system-ui, sans-serif;
}
```

### 6.2 Alle Abhängigkeiten in `package.json`

Alle Bibliotheken müssen zum Build-Zeitpunkt in `node_modules` vorhanden sein. Keine CDN-Links in `<script>` oder `<link>` Tags verwenden. Beim `shadcn/ui init` werden die Abhängigkeiten automatisch in `package.json` eingetragen:

```json
{
  "dependencies": {
    "next": "15.5.0",
    "react": "19.1.0",
    "react-dom": "19.1.0",
    "@radix-ui/react-alert-dialog": "^1.1.x",
    "@radix-ui/react-progress": "^1.1.x",
    "@radix-ui/react-slot": "^1.2.x",
    "@radix-ui/react-separator": "^1.1.x",
    "@radix-ui/react-toast": "^1.2.x",
    "class-variance-authority": "^0.7.x",
    "clsx": "^2.1.x",
    "lucide-react": "^0.x",
    "tailwind-merge": "^2.x"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4",
    "tailwindcss": "^4",
    "tw-animate-css": "^1.x",
    "typescript": "^5"
  }
}
```

### 6.3 Next.js Standalone-Modus für Docker

**`next.config.ts`:**

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Standalone-Modus: Minimales Bundle für Docker
  // Erzeugt .next/standalone/ mit allem was für den Start nötig ist
  output: "standalone",

  // Image-Optimierung deaktivieren, da kein Sharp im Air-Gap-Container
  // (alternativ: Sharp als Dependency aufnehmen)
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
```

### 6.4 Dockerfile für Air-Gap-Deployment

```dockerfile
# Mehrstufiger Build: Trennt Build-Abhängigkeiten von der Laufzeit-Image.
# Ergebnis: Schlankes Production-Image ohne Build-Tools.

ARG NODE_VERSION=22-slim

# ─── Stage 1: Abhängigkeiten installieren ────────────────────────────────────
FROM node:${NODE_VERSION} AS dependencies
WORKDIR /app
# Nur package.json und Lockfile kopieren — Docker-Cache-Layer effizient nutzen
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

# ─── Stage 2: Anwendung bauen ────────────────────────────────────────────────
FROM node:${NODE_VERSION} AS builder
WORKDIR /app
# Abhängigkeiten aus Stage 1 übernehmen
COPY --from=dependencies /app/node_modules ./node_modules
# Quellcode kopieren
COPY . .
ENV NODE_ENV=production
# Next.js Build — erzeugt .next/standalone/
RUN npm run build

# ─── Stage 3: Production-Runtime ─────────────────────────────────────────────
FROM node:${NODE_VERSION} AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Statische Assets und standalone-Bundle kopieren
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static

# Als non-root User ausführen (Sicherheit)
USER node
EXPOSE 3000

# server.js = Entry Point des standalone Bundles
CMD ["node", "server.js"]
```

**.dockerignore:**

```
node_modules
.next
.git
*.md
.env*
```

### 6.5 Prüfliste für Air-Gap-Deployment

- [ ] Alle Font-Dateien liegen in `src/app/fonts/` und sind in Git eingecheckt
- [ ] `next/font/local` statt `next/font/google` verwendet
- [ ] Kein `<link rel="preconnect" href="https://fonts.gstatic.com">` in `layout.tsx`
- [ ] Kein CDN-Link in `<script>` oder `<link>` Tags
- [ ] `output: "standalone"` in `next.config.ts`
- [ ] `.dockerignore` vorhanden
- [ ] Docker-Build-Test in isolierter Umgebung (kein Internet) durchgeführt

---

## 7. TypeScript-Patterns für diesen Anwendungsfall

### 7.1 Typen für API-Responses

```typescript
// src/types/api.ts
// Zentrale Typdefinitionen für alle API-Antworten des HKR-Import-Workflows

// ─── Upload-Response ──────────────────────────────────────────────────────────
export interface UploadResponse {
  jobId: string;
  dateiname: string;
  dateigroesse: number; // Bytes
  hochgeladenAm: string; // ISO 8601
}

// ─── Validierungs-Response ────────────────────────────────────────────────────
export interface ValidierungsErgebnis {
  jobId: string;
  status: "gueltig" | "fehler" | "warnung";
  gesamtDatensaetze: number;
  fehler: ValidierungsFehler[];
  warnungen: ValidierungsWarnung[];
  validierungsDauer: number; // Millisekunden
}

export interface ValidierungsFehler {
  zeile?: number;
  spalte?: string;
  code: string;      // z.B. "PFLICHTFELD_FEHLT", "UNGUELTIGE_ICD_CODES"
  nachricht: string;
  schwere: "fatal" | "fehler";
}

export interface ValidierungsWarnung {
  zeile?: number;
  code: string;
  nachricht: string;
}

// ─── Import-Response ──────────────────────────────────────────────────────────
export interface ImportErgebnis {
  jobId: string;
  status: "erfolgreich" | "teilweise" | "fehlgeschlagen";
  importierteEintraege: number;
  uebersprungeneEintraege: number;
  fehlerhafte: ImportFehler[];
  importDauer: number; // Millisekunden
  abgeschlossenAm: string; // ISO 8601
}

export interface ImportFehler {
  datensatzId?: string;
  fehlerCode: string;
  beschreibung: string;
}

// ─── Generischer API-Error ────────────────────────────────────────────────────
export interface ApiError {
  status: number;
  message: string;
  details?: string;
}

// ─── Type-Guard: Prüft ob ein Wert ein ApiError ist ──────────────────────────
export function istApiError(wert: unknown): wert ist ApiError {
  return (
    typeof wert === "object" &&
    wert !== null &&
    "status" in wert &&
    "message" in wert
  );
}
```

### 7.2 React 19 — Neue Hooks und Form-Handling

React 19 führt neue Hooks für Server Actions und asynchrone Operationen ein:

**`useActionState`** — ersetzt `useFormState` aus React 18:

```tsx
"use client";

import { useActionState } from "react"; // React 19 — in react, nicht react-dom!
import { importStarten } from "@/actions/import"; // Server Action

// Typen für den Action-State
interface ImportState {
  status: "idle" | "pending" | "success" | "error";
  nachricht?: string;
  jobId?: string;
}

const initialState: ImportState = { status: "idle" };

export function ImportBestaetigung({ jobId }: { jobId: string }) {
  // useActionState nimmt eine Server Action und den initialen State
  // Gibt [state, dispatch, isPending] zurück
  const [state, dispatch, isPending] = useActionState(
    importStarten,
    initialState
  );

  return (
    <form action={dispatch}>
      {/* Hidden input für jobId */}
      <input type="hidden" name="jobId" value={jobId} />

      <button
        type="submit"
        disabled={isPending}
        className="bg-hkr-navy text-white px-6 py-2 rounded disabled:opacity-50"
      >
        {isPending ? "Import läuft..." : "Import starten"}
      </button>

      {state.status === "error" && (
        <p className="text-hkr-red mt-2">{state.nachricht}</p>
      )}
    </form>
  );
}
```

**Server Action für Import:**

```tsx
// src/actions/import.ts
"use server";

// Server Actions werden direkt vom Client aufgerufen — kein separater API-Endpunkt nötig.
// Die "use server"-Direktive markiert die Funktion als Server-seitig.

import type { ImportState } from "@/types/state";

export async function importStarten(
  vorherigState: ImportState,
  formData: FormData
): Promise<ImportState> {
  const jobId = formData.get("jobId");

  if (!jobId || typeof jobId !== "string") {
    return { status: "error", nachricht: "Ungültige Job-ID" };
  }

  try {
    // Hier: Import-API aufrufen
    // const ergebnis = await db.importJob.starten(jobId);

    return {
      status: "success",
      jobId,
      nachricht: "Import erfolgreich gestartet",
    };
  } catch (fehler) {
    return {
      status: "error",
      nachricht: "Import konnte nicht gestartet werden",
    };
  }
}
```

**`useFormStatus`** — Ladezustand aus Eltern-Formular lesen:

```tsx
"use client";

import { useFormStatus } from "react-dom"; // useFormStatus ist in react-dom

// Hilfskomponente: Submit-Button der seinen Ladezustand selbst kennt
// Muss ein Kind-Element des <form> sein — liest Status des nächsten Eltern-Forms
export function SubmitButton({ kinder }: { kinder: React.ReactNode }) {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      className="bg-hkr-navy text-white px-6 py-2 rounded disabled:opacity-50"
    >
      {pending ? "Wird verarbeitet..." : kinder}
    </button>
  );
}
```

### 7.3 Typed Data-Fetching in Server Components

```tsx
// src/app/upload/validierung/page.tsx
import type { ValidierungsErgebnis } from "@/types/api";

// Typisierte Datenabruf-Funktion
async function holeValidierungsErgebnis(jobId: string): Promise<ValidierungsErgebnis> {
  // In der echten Implementierung: API-Aufruf oder direkter DB-Zugriff
  const res = await fetch(`http://localhost:8080/api/jobs/${jobId}/validierung`, {
    // Im Docker-Netz: interner Service-Name statt localhost
    cache: "no-store", // Immer frische Daten für Echtzeit-Status
  });

  if (!res.ok) {
    throw new Error(`Validierungsergebnis konnte nicht geladen werden: ${res.status}`);
  }

  return res.json() as Promise<ValidierungsErgebnis>;
}

export default async function ValidierungsSeite({
  searchParams,
}: {
  searchParams: Promise<{ jobId: string }>;
}) {
  const { jobId } = await searchParams;

  // TypeScript weiß: ergebnis ist vom Typ ValidierungsErgebnis
  const ergebnis = await holeValidierungsErgebnis(jobId);

  return (
    <div>
      <h2 className="text-xl font-semibold text-hkr-navy">
        Validierungsergebnis
      </h2>
      <p>
        Status:{" "}
        <span
          className={
            ergebnis.status === "gueltig"
              ? "text-green-700 font-semibold"
              : "text-hkr-red font-semibold"
          }
        >
          {ergebnis.status}
        </span>
      </p>
      <p>Datensätze: {ergebnis.gesamtDatensaetze}</p>
      <p>Fehler: {ergebnis.fehler.length}</p>
      <p>Warnungen: {ergebnis.warnungen.length}</p>
    </div>
  );
}
```

### 7.4 Lucide React — Icons

Lucide React ist die von shadcn/ui verwendete Icon-Bibliothek. Alle Icons sind als typisierte React-Komponenten verfügbar:

```tsx
import {
  UploadCloud,    // Upload-Aktion
  CheckCircle2,   // Erfolg
  AlertCircle,    // Fehler
  AlertTriangle,  // Warnung
  FileX,          // Ungültige Datei
  Database,       // Import/Datenbank
  FileText,       // Dokument/Report
  Loader2,        // Ladeindikator (mit spin-Animation)
  ChevronRight,   // Navigation vorwärts
  ChevronLeft,    // Navigation rückwärts
  X,              // Schließen/Abbrechen
} from "lucide-react";

// Verwendung: Alle Icons akzeptieren size, strokeWidth, className
<UploadCloud className="h-8 w-8 text-hkr-navy" />
<Loader2 className="h-4 w-4 animate-spin" />  // Tailwind-Animation!
<CheckCircle2 size={24} strokeWidth={1.5} />
```

---

## Anhang: Schnellstart-Checkliste

### Neues HKR-Frontend-Projekt aufsetzen

```bash
# 1. Next.js 15 Projekt erstellen
npx create-next-app@latest hkr-krebs-web \
  --typescript \
  --tailwind \
  --app \
  --src-dir \
  --import-alias "@/*"

# 2. shadcn/ui initialisieren (wähle "New York" Style, kein Farbschema)
cd hkr-krebs-web
pnpm dlx shadcn@latest init

# 3. Benötigte Komponenten installieren
pnpm dlx shadcn@latest add button card progress alert badge separator toast

# 4. Lucide React ist bereits als shadcn-Abhängigkeit installiert
# (Falls nicht: pnpm add lucide-react)

# 5. Animation-Bibliothek (shadcn/ui v4 nutzt tw-animate-css statt tailwindcss-animate)
pnpm add -D tw-animate-css

# 6. Lato-Schriftdateien herunterladen und nach src/app/fonts/ kopieren

# 7. Verzeichnisstruktur anlegen
mkdir -p src/app/upload/validierung
mkdir -p src/app/upload/import
mkdir -p src/app/upload/ergebnisse
mkdir -p src/components/upload
mkdir -p src/hooks
mkdir -p src/types
mkdir -p src/actions
```

### Kritische Dateien auf einen Blick

| Datei | Zweck |
|-------|-------|
| `src/app/globals.css` | Tailwind v4 Import, HKR-Farben in `@theme`, shadcn CSS-Vars |
| `src/app/layout.tsx` | Root Layout, Lato-Font, Toaster |
| `src/app/upload/layout.tsx` | Wizard-Shell mit Stepper |
| `src/components/upload/WizardStepper.tsx` | URL-basierter Schritt-Indikator |
| `src/components/upload/UploadDropzone.tsx` | Drag-and-Drop File-Input |
| `src/components/upload/AnimiertePfadBlume.tsx` | SVG Upload-Fortschritt |
| `src/hooks/useXhrUpload.ts` | XHR Upload mit Progress-Tracking |
| `src/types/api.ts` | Typen für alle API-Responses |
| `src/actions/import.ts` | Server Actions |
| `next.config.ts` | `output: "standalone"` für Docker |
| `Dockerfile` | Mehrstufiger Build |

---

*Erstellt: April 2026 | Stack-Versionen: Next.js 15.5, React 19.1, Tailwind CSS 4.x, shadcn/ui (Tailwind v4 Edition)*
