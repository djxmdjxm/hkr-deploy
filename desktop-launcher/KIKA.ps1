# KIKA Desktop-Launcher
# Mini-GUI fuer Start, Stop und Statusanzeige der Container.
# Funktioniert auf jedem Windows 10/11 ohne Installation (PowerShell + .NET WinForms sind Bordmittel).

# --- Konfiguration ---------------------------------------------------------
# Pfad zum docker-compose.yml relativ zum Skript-Verzeichnis.
# Standard: KIKA-Ordner liegt unter D:\KiKA RGAP\, das Skript liegt im Unterordner desktop-launcher.
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

# Hamburg CD Farben
$Navy   = [System.Drawing.Color]::FromArgb(0,   48, 99)
$Red    = [System.Drawing.Color]::FromArgb(225, 0,  25)
$Green  = [System.Drawing.Color]::FromArgb(22,  163, 74)
$Amber  = [System.Drawing.Color]::FromArgb(240, 180, 41)
$Bg     = [System.Drawing.Color]::FromArgb(242, 245, 247)
$Gray   = [System.Drawing.Color]::FromArgb(80,  80,  80)
$White  = [System.Drawing.Color]::White

# --- Hilfsfunktion: docker compose ohne Fenster aufrufen -------------------
function Invoke-Compose {
    param([string[]]$Args)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "docker"
    $psi.Arguments = (@("compose", "-p", $ProjectName, "-f", "`"$ComposeFile`"") + $Args) -join " "
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    return @{ ExitCode = $p.ExitCode; Stdout = $p.StandardOutput.ReadToEnd(); Stderr = $p.StandardError.ReadToEnd() }
}

# Liefert "running" / "stopped" / "partial"
function Get-KikaStatus {
    $r = Invoke-Compose @("ps", "--format", "json")
    if ($r.ExitCode -ne 0) { return "unknown" }
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
$form.Size         = New-Object System.Drawing.Size(460, 320)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox  = $false
$form.BackColor    = $Bg
$form.Font         = New-Object System.Drawing.Font("Segoe UI", 9)

# Header-Streifen (Navy)
$header           = New-Object System.Windows.Forms.Panel
$header.Size      = New-Object System.Drawing.Size(460, 60)
$header.Location  = New-Object System.Drawing.Point(0, 0)
$header.BackColor = $Navy
$form.Controls.Add($header)

$lblTitle           = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "KIKA"
$lblTitle.ForeColor = $White
$lblTitle.Font      = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblTitle.AutoSize  = $true
$lblTitle.Location  = New-Object System.Drawing.Point(20, 10)
$header.Controls.Add($lblTitle)

$lblSub             = New-Object System.Windows.Forms.Label
$lblSub.Text        = "Hamburgisches Krebsregister"
$lblSub.ForeColor   = [System.Drawing.Color]::FromArgb(200, 215, 230)
$lblSub.Font        = New-Object System.Drawing.Font("Segoe UI", 9)
$lblSub.AutoSize    = $true
$lblSub.Location    = New-Object System.Drawing.Point(22, 38)
$header.Controls.Add($lblSub)

# Status-Lampe + Text
$statusDot           = New-Object System.Windows.Forms.Label
$statusDot.Text      = [char]0x25CF  # filled circle
$statusDot.Font      = New-Object System.Drawing.Font("Segoe UI", 22)
$statusDot.AutoSize  = $true
$statusDot.Location  = New-Object System.Drawing.Point(20, 78)
$statusDot.ForeColor = $Gray
$form.Controls.Add($statusDot)

$lblStatus           = New-Object System.Windows.Forms.Label
$lblStatus.Text      = "Status wird geprueft..."
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
$lblStatus.AutoSize  = $true
$lblStatus.Location  = New-Object System.Drawing.Point(55, 88)
$lblStatus.ForeColor = $Navy
$form.Controls.Add($lblStatus)

# Buttons
function New-FlatButton([string]$text, [int]$x, [int]$y, [int]$w, $color) {
    $b           = New-Object System.Windows.Forms.Button
    $b.Text      = $text
    $b.Location  = New-Object System.Drawing.Point($x, $y)
    $b.Size      = New-Object System.Drawing.Size($w, 44)
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $color
    $b.ForeColor = $White
    $b.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    return $b
}

$btnStart = New-FlatButton "  Start"   20  140 200 $Navy
$btnStop  = New-FlatButton "  Stop"   230 140 200 $Red
$btnOpen  = New-FlatButton "  Im Browser oeffnen"  20  195 410 ([System.Drawing.Color]::FromArgb(0, 92, 169))
$form.Controls.Add($btnStart)
$form.Controls.Add($btnStop)
$form.Controls.Add($btnOpen)

# Footer-Hinweis
$lblFoot           = New-Object System.Windows.Forms.Label
$lblFoot.Text      = "Compose: $ComposeFile"
$lblFoot.Font      = New-Object System.Drawing.Font("Segoe UI", 7)
$lblFoot.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
$lblFoot.AutoSize  = $false
$lblFoot.Size      = New-Object System.Drawing.Size(420, 16)
$lblFoot.Location  = New-Object System.Drawing.Point(20, 252)
$lblFoot.TextAlign = "MiddleLeft"
$form.Controls.Add($lblFoot)

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
            $lblStatus.Text      = "Teilweise aktiv (Container starten oder gestoppt)"
        }
        "stopped" {
            $statusDot.ForeColor = $Red
            $lblStatus.Text      = "Gestoppt"
        }
        default {
            $statusDot.ForeColor = $Gray
            $lblStatus.Text      = "Status unbekannt - laeuft Docker Desktop?"
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

    $r = Invoke-Compose @("up", "-d")
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

    $r = Invoke-Compose @("down")
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

# Status alle 3s aktualisieren
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({ Update-Status })
$timer.Start()

# Initialer Status-Check
Update-Status

# Fenster anzeigen
[void]$form.ShowDialog()
$timer.Stop()
