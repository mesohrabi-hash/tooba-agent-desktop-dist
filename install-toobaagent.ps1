# install-toobaagent.ps1 - install Tooba agent Desktop on Windows
# Usage (same style as the official Hermes installer):
#   iex (irm https://raw.githubusercontent.com/mesohrabi-hash/tooba-agent-desktop-dist/main/install-toobaagent.ps1)
#
# NOTE: every message in this file is ENGLISH on purpose. Persian text in a
# PowerShell/cmd console renders reversed and broken on Windows (legacy code
# page), so the installer must never print non-ASCII characters.
#
# What it does:
#   1) reads the newest GitHub Release (or a specific tag with -Tag)
#   2) downloads the NSIS installer asset
#   3) verifies SHA256 against SHA256SUMS.txt when the release provides one
#   4) closes any running copy of the app (otherwise the .exe stays locked and
#      the install silently has no effect)
#   5) runs the installer silently (/S)
#   6) lists every installation found on disk, and warns when there is more
#      than one (a stale shortcut is the usual reason a user keeps seeing an
#      old version number)
#
# Uninstall: Control Panel -> Programs and Features -> "Tooba agent Desktop" -> Uninstall
#            (or:  Get-Package '*Tooba*' | Uninstall-Package)

[CmdletBinding()]
param(
  [string]$Owner = 'mesohrabi-hash',
  [string]$Repo  = 'tooba-agent-desktop-dist',
  [string]$Tag   = '',                       # empty = newest release
  [string]$AssetPattern = 'ToobaAgentDesktop-*-win-x64.exe',
  [switch]$SkipHashCheck,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Info($m) { if (-not $Quiet) { Write-Host "[tooba] $m" -ForegroundColor Cyan } }
function Fail($m) { Write-Host "[tooba] ERROR: $m" -ForegroundColor Red; exit 1 }

function Get-ToobaInstallations {
  $roots = @($env:LOCALAPPDATA + '\Programs', $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path $_) }
  $found = @()
  foreach ($r in $roots) {
    $found += Get-ChildItem -Path $r -Filter 'ToobaAgent.exe' -Recurse -Depth 3 -ErrorAction SilentlyContinue
  }
  return $found
}

$headers = @{ 'User-Agent' = 'tooba-installer'; 'Accept' = 'application/vnd.github+json' }
if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)" }

try {
  if ($Tag) {
    Info "Reading release with tag $Tag"
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases/tags/$Tag" -Headers $headers -TimeoutSec 60
  } else {
    Info 'Reading release list (newest first, pre-releases included)'
    $all = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases?per_page=30" -Headers $headers -TimeoutSec 60
    $release = $all | Where-Object { $_.assets.name -like $AssetPattern } | Select-Object -First 1
    if (-not $release) { Fail "No release found with an installer asset matching '$AssetPattern'." }
  }
} catch {
  Fail "Could not fetch the release: $($_.Exception.Message)"
}

$asset = $release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
if (-not $asset) { Fail "Release '$($release.tag_name)' has no installer asset matching '$AssetPattern'." }

$tmp  = Join-Path $env:TEMP $asset.name
$sums = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1

Info "Target version: $($release.tag_name)"

$before = Get-ToobaInstallations
if ($before.Count -gt 0) {
  Info 'Currently installed copies on this machine:'
  foreach ($b in $before) { Write-Host ("    {0}  version={1}" -f $b.FullName, $b.VersionInfo.FileVersion) -ForegroundColor DarkGray }
}

Info "Downloading $($asset.name)  ($([math]::Round($asset.size/1MB,1)) MB)"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -TimeoutSec 900

if (-not $SkipHashCheck -and $sums) {
  $sumFile = Join-Path $env:TEMP 'SHA256SUMS.txt'
  Invoke-WebRequest -Uri $sums.browser_download_url -OutFile $sumFile -TimeoutSec 120
  $expected = (Get-Content $sumFile | Where-Object { $_ -match [regex]::Escape($asset.name) }) -split '\s+' | Select-Object -First 1
  $actual = (Get-FileHash $tmp -Algorithm SHA256).Hash
  if ($expected -and ($expected.ToUpper() -ne $actual.ToUpper())) {
    Remove-Item $tmp -Force
    Fail "SHA256 mismatch. expected=$expected actual=$actual"
  }
  Info "SHA256 verified: $actual"
} elseif (-not $SkipHashCheck) {
  Info 'Warning: no SHA256SUMS.txt in this release - integrity was not checked.'
}

# --- Close the running app. Without this step the install has no effect on an
#     already-running copy: the .exe is locked and the files are not replaced. ---
$running = Get-Process -Name 'ToobaAgent' -ErrorAction SilentlyContinue
if ($running) {
  Info "Closing $($running.Count) running copy/copies..."
  $running | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $still = Get-Process -Name 'ToobaAgent' -ErrorAction SilentlyContinue
  if ($still) { Fail 'The app is still running. Close it by hand (tray icon -> Exit) and run this again.' }
} else {
  Info 'No running copy was found.'
}

Info 'Running the silent install...'
$proc = Start-Process -FilePath $tmp -ArgumentList '/S' -PassThru -Wait
if ($proc.ExitCode -ne 0) { Fail "Installer exited with code $($proc.ExitCode)." }

Info 'Installed.'
try { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } catch { }
try { if ($sumFile) { Remove-Item $sumFile -Force -ErrorAction SilentlyContinue } } catch { }

# --- Report what is now on disk ---
Start-Sleep -Seconds 2
$after = Get-ToobaInstallations
Write-Host ''
Write-Host 'Installed copies on this machine:' -ForegroundColor Yellow
if ($after.Count -eq 0) {
  Write-Host '  (none found - check the install path by hand)' -ForegroundColor Red
} else {
  foreach ($a in $after) { Write-Host ("  {0}   version={1}" -f $a.FullName, $a.VersionInfo.FileVersion) }
  if ($after.Count -gt 1) {
    Write-Host '  NOTE: more than one copy is installed. The shortcut you click must point at the newest path listed above.' -ForegroundColor Yellow
  }
}
Write-Host ''
Write-Host 'Open the app and read the version in the top bar of the window; it must match the target version above.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Uninstall:' -ForegroundColor Yellow
Write-Host '  Control Panel -> Programs and Features -> "Tooba agent Desktop" -> Uninstall'
Write-Host '  or in PowerShell:  Get-Package "*Tooba*" | Uninstall-Package'
Write-Host ''
