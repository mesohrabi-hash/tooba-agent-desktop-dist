# tooba-agent-desktop-dist (عمومی)

مخزن **توزیع** نصب‌کنندهٔ Tooba agent Desktop. جدا از مخزن سورس (خصوصی) نگه داشته می‌شود
تا نصب یک‌خطی روی کلاینت‌ها **بدون احراز هویت** کار کند.

## نصب

```powershell
iex (irm https://raw.githubusercontent.com/mesohrabi-hash/tooba-agent-desktop-dist/main/install-toobaagent.ps1)
```

## حذف

Control Panel → Programs → Programs and Features → **Tooba agent Desktop** → Uninstall

## چه چیزی اینجا می‌آید

- `install-toobaagent.ps1` — اسکریپت نصب (بررسی SHA256 + نصب خاموش + راهنمای حذف)
- Release assets: `ToobaAgentDesktop-<version>-win-x64.exe` · `SHA256SUMS.txt` · `latest.yml`

## چه چیزی اینجا **نمی‌آید**

- سورس کد (در مخزن خصوصی `tooba-agent-desktop`)
- هیچ دادهٔ سازمانی/شرکتی (پیش از هر انتشار با اسکنر داده کنترل می‌شود)

نسخهٔ پایه: Hermes Agent 0.17.0 (MIT، Nous Research) — رابط فارسی + RTL.
