# Installs the random-sound Stop hook for Claude Code.
# Put this file next to play-random-sound.ps1 (and any sounds to add) and run it.
$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 otherwise may write arrays as {"value": [...], "Count": n}.
Remove-TypeData System.Array -ErrorAction SilentlyContinue

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$soundsDir = Join-Path $claudeDir 'sounds'
$hooksDir = Join-Path $claudeDir 'hooks'
$settingsPath = Join-Path $claudeDir 'settings.json'
$playerSource = Join-Path $PSScriptRoot 'play-random-sound.ps1'
$playerTarget = Join-Path $hooksDir 'play-random-sound.ps1'
$extensions = @('.wav', '.mp3', '.wma', '.m4a', '.aac')

New-Item -ItemType Directory -Force -Path $soundsDir | Out-Null
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
Copy-Item -Force -LiteralPath $playerSource -Destination $playerTarget

# The old single-sound version's sound file goes; put it next to this installer to keep it.
$oldSound = Join-Path $soundsDir 'zvonok.wav'
if (Test-Path -LiteralPath $oldSound) {
    Remove-Item -Force -LiteralPath $oldSound
    Write-Host "zvonok: removed old sound $oldSound"
}

# Sounds next to this installer, or in a "sounds" folder beside it, are copied into the sounds folder.
$sourceDirs = @($PSScriptRoot)
$bundledSounds = Join-Path $PSScriptRoot 'sounds'
if (Test-Path -LiteralPath $bundledSounds) { $sourceDirs += $bundledSounds }
foreach ($dir in $sourceDirs) {
    Get-ChildItem -LiteralPath $dir -File |
        Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
        ForEach-Object { Copy-Item -Force -LiteralPath $_.FullName -Destination (Join-Path $soundsDir $_.Name) }
}

$hook = [pscustomobject]@{
    type    = 'command'
    command = 'powershell.exe'
    args    = @('-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $playerTarget)
    async   = $true
}
$entry = [pscustomobject]@{ hooks = @($hook) }

$settings = [pscustomobject]@{}
if (Test-Path -LiteralPath $settingsPath) {
    $raw = [System.IO.File]::ReadAllText($settingsPath)
    if ($raw.Trim()) { $settings = $raw | ConvertFrom-Json }
    Copy-Item -Force -LiteralPath $settingsPath -Destination "$settingsPath.bak"
}

if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}

# Drop earlier zvonok hooks (the single-sound one and this one), keep everything else.
$stop = @()
$removedHooks = 0
if ($settings.hooks.PSObject.Properties['Stop']) {
    foreach ($group in @($settings.hooks.Stop)) {
        $all = @($group.hooks)
        $kept = @($all | Where-Object {
            $joined = @($_.args) -join ' '
            -not ($joined -like '*zvonok.wav*' -or $joined -like '*play-random-sound.ps1*')
        })
        $removedHooks += $all.Count - $kept.Count
        if ($kept.Count -gt 0) {
            $group.hooks = $kept
            $stop += $group
        }
    }
}
if ($removedHooks -gt 0) { Write-Host "zvonok: removed $removedHooks old hook(s) from $settingsPath" }
$stop += $entry

if ($settings.hooks.PSObject.Properties['Stop']) {
    $settings.hooks.Stop = $stop
} else {
    $settings.hooks | Add-Member -NotePropertyName Stop -NotePropertyValue $stop
}

$json = $settings | ConvertTo-Json -Depth 32
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host "zvonok: hook set in $settingsPath"

$count = @(Get-ChildItem -LiteralPath $soundsDir -File |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() }).Count
Write-Host "zvonok: $count sound(s) in $soundsDir"

if ($count -gt 0) {
    Write-Host 'zvonok: test sound...'
    & $playerTarget
}

Start-Process explorer.exe $soundsDir
Write-Host 'zvonok: done. Drop more sounds into the opened folder, then restart Claude Code.'
