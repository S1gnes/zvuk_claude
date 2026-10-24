# Plays one sound from %USERPROFILE%\.claude\sounds in shuffled order:
# every sound plays once before any repeats, and never the same one twice in a row.
$ErrorActionPreference = 'Stop'

$soundsDir = Join-Path $env:USERPROFILE '.claude\sounds'
$queuePath = Join-Path $soundsDir '.queue'
$lastPath = Join-Path $soundsDir '.last'
$extensions = @('.wav', '.mp3', '.wma', '.m4a', '.aac')
$maxSeconds = 60

if (-not (Test-Path -LiteralPath $soundsDir)) { exit 0 }

$files = @(Get-ChildItem -LiteralPath $soundsDir -File |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
    ForEach-Object { $_.Name })
if ($files.Count -eq 0) { exit 0 }

$queue = @()
if (Test-Path -LiteralPath $queuePath) {
    $queue = @([System.IO.File]::ReadAllLines($queuePath) | Where-Object { $files -contains $_ })
}

if ($queue.Count -eq 0) {
    $queue = @($files | Get-Random -Count $files.Count)
    $last = ''
    if (Test-Path -LiteralPath $lastPath) { $last = [System.IO.File]::ReadAllText($lastPath).Trim() }
    if ($queue.Count -gt 1 -and $queue[0] -eq $last) {
        $first = $queue[0]
        $queue[0] = $queue[1]
        $queue[1] = $first
    }
}

$name = $queue[0]
$rest = [string[]]@()
if ($queue.Count -gt 1) { $rest = [string[]]$queue[1..($queue.Count - 1)] }
[System.IO.File]::WriteAllLines($queuePath, $rest)
[System.IO.File]::WriteAllText($lastPath, $name)

$path = Join-Path $soundsDir $name

function Invoke-MediaPlayer([string]$file) {
    Add-Type -AssemblyName PresentationCore
    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([Uri]$file)
    $waited = 0
    while (-not $player.NaturalDuration.HasTimeSpan -and $waited -lt 5000) {
        Start-Sleep -Milliseconds 100
        $waited += 100
    }
    $seconds = 10
    if ($player.NaturalDuration.HasTimeSpan) { $seconds = $player.NaturalDuration.TimeSpan.TotalSeconds }
    $player.Play()
    Start-Sleep -Milliseconds ([int](([Math]::Min($seconds, $maxSeconds) + 0.3) * 1000))
    $player.Stop()
    $player.Close()
}

if ([System.IO.Path]::GetExtension($path).ToLowerInvariant() -eq '.wav') {
    try {
        (New-Object System.Media.SoundPlayer $path).PlaySync()
    } catch {
        Invoke-MediaPlayer $path
    }
} else {
    Invoke-MediaPlayer $path
}
