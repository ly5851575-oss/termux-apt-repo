# Termux APT Repository

مستودع عام لحزم Termux الخاصة بحساب `ly5851575-oss`.

## رابط المستودع

```text
https://ly5851575-oss.github.io/termux-apt-repo/
```

## إضافته إلى Termux

```bash
echo "deb [trusted=yes] https://ly5851575-oss.github.io/termux-apt-repo/ ./" \
  | tee "$PREFIX/etc/apt/sources.list.d/checktool.list"

pkg update
pkg install checktool
```

## رفع حزمة جديدة

ارفع ملف `.deb` إلى فرع `main`. سيقوم GitHub Actions تلقائياً بنقله إلى فرع `gh-pages` وتوليد الملفين `Packages` و`Packages.gz`.
