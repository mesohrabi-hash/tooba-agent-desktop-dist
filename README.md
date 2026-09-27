# tooba-agent-desktop-dist (عمومی)

مخزن **توزیع** نصب‌کنندهٔ Tooba agent Desktop. جدا از مخزن سورس (خصوصی) نگه داشته می‌شود
تا نصب یک‌خطی روی کلاینت‌ها **بدون احراز هویت** کار کند.

## نصب — یک دستور (توصیه‌شده)

PowerShell را باز کنید و این یک خط را بچسبانید:

```powershell
iex (irm https://raw.githubusercontent.com/mesohrabi-hash/tooba-agent-desktop-dist/main/install-toobaagent.ps1)
```

اسکریپت خودش آخرین نسخه را پیدا و دانلود می‌کند، **SHA256** را بررسی می‌کند و نصب را خاموش انجام می‌دهد.

## نصب دستی — دانلود مستقیم آخرین نسخه

دانلود آخرین فایل نصب:

<https://github.com/mesohrabi-hash/tooba-agent-desktop-dist/releases/latest/download/ToobaAgentDesktop-0.17.7-win-x64.exe>

صفحهٔ همهٔ نسخه‌ها: <https://github.com/mesohrabi-hash/tooba-agent-desktop-dist/releases>

## حذف

Control Panel → Programs → Programs and Features → **Tooba agent Desktop** → Uninstall

## چه چیزی اینجا می‌آید

- `install-toobaagent.ps1` — اسکریپت نصب (بررسی SHA256 + نصب خاموش + راهنمای حذف)
- Release assets: `ToobaAgentDesktop-<version>-win-x64.exe` · `SHA256SUMS.txt` · `latest.yml`

## چه چیزی اینجا **نمی‌آید**

- سورس کد (در مخزن خصوصی `tooba-agent-desktop`)
- هیچ دادهٔ سازمانی/شرکتی (پیش از هر انتشار با اسکنر داده کنترل می‌شود)

آخرین نسخهٔ منتشرشده: **0.17.7** — نسخهٔ پایه: Hermes Agent 0.17.x (MIT، Nous Research) — رابط فارسی + RTL.
