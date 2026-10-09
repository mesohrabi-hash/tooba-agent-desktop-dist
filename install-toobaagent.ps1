# install-toobaagent.ps1 — نصب Tooba agent Desktop روی ویندوز
# هم‌سبک با اسکریپت رسمی هرمس:  iex (irm https://raw.githubusercontent.com/<OWNER>/<REPO>/main/install-toobaagent.ps1)
#
# چه می‌کند:
#   1) آخرین Release را از گیت‌هاب می‌خواند (یا تگ مشخص با -Tag)
#   2) فایل نصب NSIS را دانلود می‌کند
#   3) SHA256 را (اگر در Release موجود باشد) تطبیق می‌دهد
#   4) هر نسخهٔ در حال اجرای برنامه را می‌بندد (وگرنه فایل exe قفل می‌ماند و نصب بی‌اثر می‌شود)
#   5) نصب خاموش اجرا می‌کند (/S)
#   6) نسخهٔ نصب‌شده روی دیسک را نشان می‌دهد و اگر چند نصب پیدا شد هشدار می‌دهد
#
# حذف: Control Panel → Programs and Features → "Tooba agent Desktop" → Uninstall
#       (یا: Get-Package '*Tooba*' | Uninstall-Package)

[CmdletBinding()]
param(
  [string]$Owner = 'mesohrabi-hash',
  [string]$Repo  = 'tooba-agent-desktop-dist',
  [string]$Tag   = '',                       # خالی = آخرین Release
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
    Info "خواندن Release با تگ $Tag"
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases/tags/$Tag" -Headers $headers -TimeoutSec 60
  } else {
    Info 'خواندن فهرست Releaseها (جدیدترین نسخه، شامل پیش‌انتشارها)'
    $all = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases?per_page=30" -Headers $headers -TimeoutSec 60
    $release = $all | Where-Object { $_.assets.name -like $AssetPattern } | Select-Object -First 1
    if (-not $release) { Fail "هیچ Release دارای فایل نصب با الگوی '$AssetPattern' پیدا نشد." }
  }
} catch {
  Fail "دریافت Release ناموفق بود: $($_.Exception.Message)"
}

$asset = $release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
if (-not $asset) { Fail "دارایی نصب با الگوی '$AssetPattern' در Release '$($release.tag_name)' پیدا نشد." }

$tmp  = Join-Path $env:TEMP $asset.name
$sums = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1

Info "نسخهٔ هدف: $($release.tag_name)"

$before = Get-ToobaInstallations
if ($before.Count -gt 0) {
  Info 'نسخه‌های نصب‌شدهٔ فعلی روی این کامپیوتر:'
  foreach ($b in $before) { Write-Host ("    {0}  version={1}" -f $b.FullName, $b.VersionInfo.FileVersion) -ForegroundColor DarkGray }
}

Info "دانلود $($asset.name)  ($([math]::Round($asset.size/1MB,1)) MB)"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -TimeoutSec 900

if (-not $SkipHashCheck -and $sums) {
  $sumFile = Join-Path $env:TEMP 'SHA256SUMS.txt'
  Invoke-WebRequest -Uri $sums.browser_download_url -OutFile $sumFile -TimeoutSec 120
  $expected = (Get-Content $sumFile | Where-Object { $_ -match [regex]::Escape($asset.name) }) -split '\s+' | Select-Object -First 1
  $actual = (Get-FileHash $tmp -Algorithm SHA256).Hash
  if ($expected -and ($expected.ToUpper() -ne $actual.ToUpper())) {
    Remove-Item $tmp -Force
    Fail "SHA256 مطابقت ندارد! انتظار=$expected  واقعی=$actual"
  }
  Info "SHA256 تأیید شد: $actual"
} elseif (-not $SkipHashCheck) {
  Info 'هشدار: SHA256SUMS.txt در Release نبود — بررسی یکپارچگی انجام نشد.'
}

# --- بستن برنامهٔ در حال اجرا (بدون این مرحله نصب روی نسخهٔ قبلی بی‌اثر می‌ماند) ---
$running = Get-Process -Name 'ToobaAgent' -ErrorAction SilentlyContinue
if ($running) {
  Info "بستن $($running.Count) نسخهٔ در حال اجرا…"
  $running | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $still = Get-Process -Name 'ToobaAgent' -ErrorAction SilentlyContinue
  if ($still) { Fail 'برنامه بسته نشد. آن را دستی ببندید (آیکون سینی → Exit) و دوباره اجرا کنید.' }
} else {
  Info 'هیچ نسخهٔ در حال اجرایی نبود.'
}

Info 'اجرای نصب خاموش…'
$proc = Start-Process -FilePath $tmp -ArgumentList '/S' -PassThru -Wait
if ($proc.ExitCode -ne 0) { Fail "نصب با کد $($proc.ExitCode) ناموفق بود." }

Info 'نصب شد.'
try { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } catch { }
try { if ($sumFile) { Remove-Item $sumFile -Force -ErrorAction SilentlyContinue } } catch { }

# --- تأیید نسخهٔ نصب‌شده ---
Start-Sleep -Seconds 2
$after = Get-ToobaInstallations
Write-Host ''
Write-Host 'نسخه‌های نصب‌شده روی این کامپیوتر:' -ForegroundColor Yellow
if ($after.Count -eq 0) {
  Write-Host '  (پیدا نشد — مسیر نصب را دستی بررسی کنید)' -ForegroundColor Red
} else {
  foreach ($a in $after) { Write-Host ("  {0}   version={1}" -f $a.FullName, $a.VersionInfo.FileVersion) }
  if ($after.Count -gt 1) {
    Write-Host '  توجه: بیش از یک نصب وجود دارد. میان‌بری که باز می‌کنید باید به جدیدترین مسیر بالا اشاره کند.' -ForegroundColor Yellow
  }
}
Write-Host ''
Write-Host 'برنامه را باز کنید و نسخهٔ نوار بالای پنجره را ببینید؛ باید با نسخهٔ هدف بالا یکی باشد.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'حذف برنامه:' -ForegroundColor Yellow
Write-Host '  Control Panel → Programs and Features → "Tooba agent Desktop" → Uninstall'
Write-Host '  یا در PowerShell:  Get-Package "*Tooba*" | Uninstall-Package'
Write-Host ''
