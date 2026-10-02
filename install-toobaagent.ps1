# install-toobaagent.ps1 - install Tooba agent Desktop on Windows
# Same shape as the official Hermes installer:
#   iex (irm https://raw.githubusercontent.com/<OWNER>/<REPO>/main/install-toobaagent.ps1)
#
# What it does:
#   1) reads the latest release from GitHub (or a specific tag with -Tag)
#   2) downloads the NSIS installer
#   3) verifies SHA256 when the release ships SHA256SUMS.txt
#   4) runs a silent install (/S)
#   5) prints how to uninstall
#
# Uninstall: Control Panel -> Programs and Features -> "Tooba agent Desktop" -> Uninstall
#            (or: Get-Package '*Tooba*' | Uninstall-Package)

[CmdletBinding()]
param(
  [string]$Owner = 'mesohrabi-hash',
  [string]$Repo  = 'tooba-agent-desktop-dist',
  [string]$Tag   = '',                       # empty = latest release
  [string]$AssetPattern = 'ToobaAgentDesktop-*-win-x64.exe',
  [switch]$SkipHashCheck,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Info($m) { if (-not $Quiet) { Write-Host "[tooba] $m" -ForegroundColor Cyan } }
function Fail($m) { Write-Host "[tooba] ERROR: $m" -ForegroundColor Red; exit 1 }


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
    if (-not $release) { Fail "No release contains an installer matching '$AssetPattern'." }
  }
} catch {
  Fail "Could not read the release: $($_.Exception.Message)"
}

$asset = $release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
if (-not $asset) { Fail "No installer asset matching '$AssetPattern' in release '$($release.tag_name)'." }

$tmp  = Join-Path $env:TEMP $asset.name
$sums = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1

Info "Downloading $($asset.name)  ($([math]::Round($asset.size/1MB,1)) MB)"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -TimeoutSec 900

if (-not $SkipHashCheck -and $sums) {
  $sumFile = Join-Path $env:TEMP 'SHA256SUMS.txt'
  Invoke-WebRequest -Uri $sums.browser_download_url -OutFile $sumFile -TimeoutSec 120
  $expected = (Get-Content $sumFile | Where-Object { $_ -match [regex]::Escape($asset.name) }) -split '\s+' | Select-Object -First 1
  $actual = (Get-FileHash $tmp -Algorithm SHA256).Hash
  if ($expected -and ($expected.ToUpper() -ne $actual.ToUpper())) {
    Remove-Item $tmp -Force
    Fail "SHA256 mismatch! expected=$expected actual=$actual"
  }
  Info "SHA256 verified: $actual"
} elseif (-not $SkipHashCheck) {
  Info 'Warning: SHA256SUMS.txt is not in this release - integrity check skipped.'
}

Info 'Running silent install...'
$proc = Start-Process -FilePath $tmp -ArgumentList '/S' -PassThru -Wait
if ($proc.ExitCode -ne 0) { Fail "Install failed with exit code $($proc.ExitCode)." }

Info 'Installed.'
try { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } catch { }
try { if ($sumFile) { Remove-Item $sumFile -Force -ErrorAction SilentlyContinue } } catch { }
Write-Host ''
Write-Host 'To uninstall:' -ForegroundColor Yellow
Write-Host '  Control Panel -> Programs and Features -> "Tooba agent Desktop" -> Uninstall'
Write-Host '  or in PowerShell:  Get-Package "*Tooba*" | Uninstall-Package'
Write-Host ''
if (-not $Quiet) { Info "Default install path: $env:LOCALAPPDATA\Programs\ToobaAgent" }
