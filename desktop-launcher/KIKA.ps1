# KIKA Desktop-Launcher
# Mini-GUI fuer Start, Stop und Statusanzeige der Container.
# Funktioniert auf jedem Windows 10/11 ohne Installation (PowerShell + .NET WinForms sind Bordmittel).

# --- Konfiguration ---------------------------------------------------------
# Pfad zum docker-compose.yml relativ zum Skript-Verzeichnis.
# Standard: KIKA-Ordner liegt unter D:\KiKA RGAP\, das Skript im Unterordner desktop-launcher.
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposeFile = Join-Path (Split-Path -Parent $ScriptDir) "docker-compose.yml"
$ProjectName = "hkr-clean"
$BrowserUrl  = "http://localhost:8090"

# Falls die Compose-Datei woanders liegt: hier den absoluten Pfad eintragen.
# Beispiel:
# $ComposeFile = "D:\KiKA RGAP\docker-compose.yml"

# --- WinForms laden --------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# Hamburg CD Farben
$Navy   = [System.Drawing.Color]::FromArgb(0,   48,  99)
$Blue   = [System.Drawing.Color]::FromArgb(0,   92,  169)
$Red    = [System.Drawing.Color]::FromArgb(225, 0,   25)
$Green  = [System.Drawing.Color]::FromArgb(22,  163, 74)
$Amber  = [System.Drawing.Color]::FromArgb(240, 180, 41)
$Bg     = [System.Drawing.Color]::FromArgb(242, 245, 247)
$Gray   = [System.Drawing.Color]::FromArgb(80,  80,  80)
$White  = [System.Drawing.Color]::White
$Muted  = [System.Drawing.Color]::FromArgb(140, 140, 140)

# --- Hilfsfunktion: docker compose ohne Fenster aufrufen -------------------
function Invoke-Compose {
    param([string[]]$ArgList, [int]$TimeoutSec = 120)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "docker"
    $argList2 = @("compose", "-p", $ProjectName, "-f", "`"$ComposeFile`"") + $ArgList
    $psi.Arguments = $argList2 -join " "
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch {}
        return @{ ExitCode = -1; Stdout = ""; Stderr = "Timeout nach ${TimeoutSec}s" }
    }
    return @{ ExitCode = $p.ExitCode; Stdout = $p.StandardOutput.ReadToEnd(); Stderr = $p.StandardError.ReadToEnd() }
}

# Liefert "running" / "stopped" / "partial" / "no-docker" / "no-compose"
function Get-KikaStatus {
    if (-not (Test-Path $ComposeFile)) { return "no-compose" }
    $r = Invoke-Compose -ArgList @("ps", "--format", "json") -TimeoutSec 8
    if ($r.ExitCode -ne 0) {
        if ($r.Stderr -match "daemon|pipe|connect") { return "no-docker" }
        return "unknown"
    }
    $lines = $r.Stdout -split "`n" | Where-Object { $_.Trim() -ne "" }
    if ($lines.Count -eq 0) { return "stopped" }
    $running = 0; $total = 0
    foreach ($line in $lines) {
        try {
            $obj = $line | ConvertFrom-Json
            $total++
            if ($obj.State -eq "running") { $running++ }
        } catch { }
    }
    if ($total -eq 0)              { return "stopped" }
    if ($running -eq 0)            { return "stopped" }
    if ($running -eq $total)       { return "running" }
    return "partial"
}

# --- Fenster ---------------------------------------------------------------
$form              = New-Object System.Windows.Forms.Form
$form.Text         = "KIKA"
$form.ClientSize   = New-Object System.Drawing.Size(480, 368)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox  = $false
$form.BackColor    = $Bg
$form.Font         = New-Object System.Drawing.Font("Segoe UI", 9)

# Header (Navy)
$header           = New-Object System.Windows.Forms.Panel
$header.Size      = New-Object System.Drawing.Size(480, 84)
$header.Location  = New-Object System.Drawing.Point(0, 0)
$header.BackColor = $Navy
$form.Controls.Add($header)

$lblTitle           = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "KIKA"
$lblTitle.ForeColor = $White
$lblTitle.Font      = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$lblTitle.AutoSize  = $true
$lblTitle.Location  = New-Object System.Drawing.Point(20, 12)
$lblTitle.BackColor = [System.Drawing.Color]::Transparent
$header.Controls.Add($lblTitle)

# Blumen-Reihe rechts im Header — 5 Varianten, gezeichnet wie in FlowerProgress.tsx
# Color-Emojis koennen WinForms-Labels nicht farbig rendern, also selbst malen.
$flowerPanel           = New-Object System.Windows.Forms.Panel
$flowerPanel.Size      = New-Object System.Drawing.Size(220, 72)
$flowerPanel.Location  = New-Object System.Drawing.Point(248, 6)
$flowerPanel.BackColor = [System.Drawing.Color]::Transparent
$header.Controls.Add($flowerPanel)

$flowerPanel.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # Stamm-Farbe (gruener Stiel)
    $stemColor = [System.Drawing.Color]::FromArgb(95,  165, 90)
    $stemPen   = New-Object System.Drawing.Pen $stemColor, 2

    # 5 Blumen-Definitionen: Petal-Farbe, Center-Farbe
    $flowers = @(
        @{ petal = [System.Drawing.Color]::FromArgb(225, 0,   25);  center = [System.Drawing.Color]::FromArgb(165, 25,  35) }    # rose
        @{ petal = [System.Drawing.Color]::FromArgb(255, 192, 203); center = [System.Drawing.Color]::FromArgb(240, 110, 150) }  # cherry
        @{ petal = [System.Drawing.Color]::FromArgb(255, 200, 40);  center = [System.Drawing.Color]::FromArgb(115, 75,  20) }   # sunflower
        @{ petal = [System.Drawing.Color]::FromArgb(255, 255, 255); center = [System.Drawing.Color]::FromArgb(255, 200, 40) }   # daisy
        @{ petal = [System.Drawing.Color]::FromArgb(245, 110, 50);  center = [System.Drawing.Color]::FromArgb(150, 50,  30) }   # tulip
    )

    $spacing = 42
    $startX = 12
    for ($i = 0; $i -lt 5; $i++) {
        $cx = $startX + $i * $spacing + 14
        $cy = 30
        $f = $flowers[$i]

        # Stiel
        $g.DrawLine($stemPen, $cx, $cy + 4, $cx, $cy + 28)

        # Petals: 6 Ellipsen rund um die Mitte
        $petalBrush = New-Object System.Drawing.SolidBrush $f.petal
        $petalSize  = 9
        for ($p = 0; $p -lt 6; $p++) {
            $angle = ($p * 60) * [Math]::PI / 180
            $px = $cx + [Math]::Cos($angle) * 7
            $py = $cy + [Math]::Sin($angle) * 7
            $g.FillEllipse($petalBrush, $px - $petalSize/2, $py - $petalSize/2, $petalSize, $petalSize)
        }
        $petalBrush.Dispose()

        # Mitte
        $centerBrush = New-Object System.Drawing.SolidBrush $f.center
        $g.FillEllipse($centerBrush, $cx - 4, $cy - 4, 8, 8)
        $centerBrush.Dispose()
    }
    $stemPen.Dispose()
})

# Status-Zeile (Lampe + Text in eigenem Panel mit eigener Hoehe)
$statusPanel           = New-Object System.Windows.Forms.Panel
$statusPanel.Size      = New-Object System.Drawing.Size(440, 50)
$statusPanel.Location  = New-Object System.Drawing.Point(20, 104)
$statusPanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($statusPanel)

$statusDot           = New-Object System.Windows.Forms.Label
$statusDot.Text      = [char]0x25CF
$statusDot.Font      = New-Object System.Drawing.Font("Segoe UI", 24)
$statusDot.AutoSize  = $true
$statusDot.Location  = New-Object System.Drawing.Point(0, 6)
$statusDot.ForeColor = $Gray
$statusDot.BackColor = [System.Drawing.Color]::Transparent
$statusPanel.Controls.Add($statusDot)

$lblStatus           = New-Object System.Windows.Forms.Label
$lblStatus.Text      = "Status wird geprueft..."
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 12)
$lblStatus.AutoSize  = $false
$lblStatus.Size      = New-Object System.Drawing.Size(390, 36)
$lblStatus.TextAlign = "MiddleLeft"
$lblStatus.Location  = New-Object System.Drawing.Point(45, 7)
$lblStatus.ForeColor = $Navy
$lblStatus.BackColor = [System.Drawing.Color]::Transparent
$statusPanel.Controls.Add($lblStatus)

# Buttons
function New-FlatButton([string]$text, [int]$x, [int]$y, [int]$w, $color) {
    $b           = New-Object System.Windows.Forms.Button
    $b.Text      = $text
    $b.Location  = New-Object System.Drawing.Point($x, $y)
    $b.Size      = New-Object System.Drawing.Size($w, 48)
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $color
    $b.ForeColor = $White
    $b.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.UseVisualStyleBackColor = $false
    return $b
}

$btnStart = New-FlatButton "Start"  20  173 215 $Navy
$btnStop  = New-FlatButton "Stop"   245 173 215 $Red
$btnOpen  = New-FlatButton "Im Browser oeffnen" 20 233 440 $Blue
$form.Controls.Add($btnStart)
$form.Controls.Add($btnStop)
$form.Controls.Add($btnOpen)

# Footer
$lblFoot           = New-Object System.Windows.Forms.Label
$lblFoot.Text      = "Compose: $ComposeFile"
$lblFoot.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblFoot.ForeColor = $Muted
$lblFoot.AutoSize  = $false
$lblFoot.Size      = New-Object System.Drawing.Size(440, 18)
$lblFoot.Location  = New-Object System.Drawing.Point(20, 298)
$lblFoot.TextAlign = "MiddleLeft"
$lblFoot.AutoEllipsis = $true
$form.Controls.Add($lblFoot)

$lblFoot2          = New-Object System.Windows.Forms.Label
$lblFoot2.Text     = "Projekt: $ProjectName  -  URL: $BrowserUrl"
$lblFoot2.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
$lblFoot2.ForeColor = $Muted
$lblFoot2.AutoSize = $false
$lblFoot2.Size     = New-Object System.Drawing.Size(440, 18)
$lblFoot2.Location = New-Object System.Drawing.Point(20, 316)
$lblFoot2.TextAlign = "MiddleLeft"
$form.Controls.Add($lblFoot2)

# --- Status-Update ---------------------------------------------------------
function Update-Status {
    $s = Get-KikaStatus
    switch ($s) {
        "running" {
            $statusDot.ForeColor = $Green
            $lblStatus.Text      = "Laeuft - alle Container aktiv"
        }
        "partial" {
            $statusDot.ForeColor = $Amber
            $lblStatus.Text      = "Teilweise aktiv (im Uebergang)"
        }
        "stopped" {
            $statusDot.ForeColor = $Red
            $lblStatus.Text      = "Gestoppt"
        }
        "no-docker" {
            $statusDot.ForeColor = $Amber
            $lblStatus.Text      = "Docker Desktop laeuft nicht"
        }
        "no-compose" {
            $statusDot.ForeColor = $Amber
            $lblStatus.Text      = "docker-compose.yml nicht gefunden"
        }
        default {
            $statusDot.ForeColor = $Gray
            $lblStatus.Text      = "Status unbekannt"
        }
    }
}

# --- Button Handler --------------------------------------------------------
$btnStart.Add_Click({
    $btnStart.Enabled = $false
    $btnStop.Enabled  = $false
    $statusDot.ForeColor = $Amber
    $lblStatus.Text      = "Starte alle Container..."
    [System.Windows.Forms.Application]::DoEvents()

    $r = Invoke-Compose -ArgList @("up", "-d") -TimeoutSec 300
    if ($r.ExitCode -ne 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Start fehlgeschlagen.`n`n" + $r.Stderr,
            "KIKA - Fehler",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    Update-Status
    $btnStart.Enabled = $true
    $btnStop.Enabled  = $true
})

$btnStop.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Alle KIKA-Container stoppen?",
        "KIKA - Stop",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $btnStart.Enabled = $false
    $btnStop.Enabled  = $false
    $statusDot.ForeColor = $Amber
    $lblStatus.Text      = "Stoppe alle Container..."
    [System.Windows.Forms.Application]::DoEvents()

    $r = Invoke-Compose -ArgList @("down") -TimeoutSec 120
    if ($r.ExitCode -ne 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Stop fehlgeschlagen.`n`n" + $r.Stderr,
            "KIKA - Fehler",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    Update-Status
    $btnStart.Enabled = $true
    $btnStop.Enabled  = $true
})

$btnOpen.Add_Click({
    Start-Process $BrowserUrl
})

# Status-Check NACH ShowDialog: erst Fenster anzeigen, dann initialer Check via Timer.
# Timer feuert nach 100ms einmalig den ersten Check, dann alle 3s.
$initTimer = New-Object System.Windows.Forms.Timer
$initTimer.Interval = 100
$initTimer.Add_Tick({
    $initTimer.Stop()
    Update-Status
    $pollTimer = New-Object System.Windows.Forms.Timer
    $pollTimer.Interval = 3000
    $pollTimer.Add_Tick({ Update-Status })
    $pollTimer.Start()
    $form.Add_FormClosing({ $pollTimer.Stop() })
})
$form.Add_Shown({ $initTimer.Start() })

# Fenster anzeigen
[void]$form.ShowDialog()
