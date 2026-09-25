# install-toobaagent.ps1 — نصب Tooba agent Desktop روی ویندوز
# هم‌سبک با اسکریپت رسمی هرمس:  iex (irm https://raw.githubusercontent.com/<OWNER>/<REPO>/main/install-toobaagent.ps1)
#
# چه می‌کند:
#   1) آخرین Release را از گیت‌هاب می‌خواند (یا تگ مشخص با -Tag)
#   2) فایل نصب NSIS را دانلود می‌کند
#   3) SHA256 را (اگر در Release موجود باشد) تطبیق می‌دهد
#   4) نصب خاموش اجرا می‌کند (/S)
#   5) مسیر حذف از Control Panel را چاپ می‌کند
#
# حذف: Control Panel → Programs and Features → "Tooba agent Desktop" → Uninstall
#       (یا: Get-Package '*Tooba*' | Uninstall-Package)

[CmdletBinding()]
param(
  [string]$Owner = '<OWNER>',
  [string]$Repo  = '<REPO>',
  [string]$Tag   = '',                       # خالی = آخرین Release
  [string]$AssetPattern = 'ToobaAgentDesktop-*-win-x64.exe',
  [switch]$SkipHashCheck,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Info($m) { if (-not $Quiet) { Write-Host "[tooba] $m" -ForegroundColor Cyan } }
function Fail($m) { Write-Host "[tooba] ERROR: $m" -ForegroundColor Red; exit 1 }

if ($Owner -eq '<OWNER>' -or $Repo -eq '<REPO>') {
  Fail 'این اسکریپت باید با Owner/Repo واقعی خودتان جای‌گذاری شود.'
}

$api = if ($Tag) { "https://api.github.com/repos/$Owner/$Repo/releases/tags/$Tag" }
       else      { "https://api.github.com/repos/$Owner/$Repo/releases/latest" }

Info "خواندن Release از $api"
try {
  $headers = @{ 'User-Agent' = 'tooba-installer'; 'Accept' = 'application/vnd.github+json' }
  if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)" }
  $release = Invoke-RestMethod -Uri $api -Headers $headers -TimeoutSec 60
} catch {
  Fail "دریافت Release ناموفق بود: $($_.Exception.Message)"
}

$asset = $release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
if (-not $asset) { Fail "دارایی نصب با الگوی '$AssetPattern' در Release '$($release.tag_name)' پیدا نشد." }

$tmp  = Join-Path $env:TEMP $asset.name
$sums = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1

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

Info 'اجرای نصب خاموش…'
$proc = Start-Process -FilePath $tmp -ArgumentList '/S' -PassThru -Wait
if ($proc.ExitCode -ne 0) { Fail "نصب با کد $($proc.ExitCode) ناموفق بود." }

Info 'نصب شد.'
Write-Host ''
Write-Host 'حذف برنامه:' -ForegroundColor Yellow
Write-Host '  Control Panel → Programs and Features → "Tooba agent Desktop" → Uninstall'
Write-Host '  یا در PowerShell:  Get-Package "*Tooba*" | Uninstall-Package'
Write-Host ''
if (-not $Quiet) { Info "مسیر نصب پیش‌فرض: $env:LOCALAPPDATA\Programs\ToobaAgent" }
