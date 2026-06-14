# Termux APT Repository

مستودع عام لحزم Termux الخاصة بحساب `ly5851575-oss`.

## رابط المستودع

```text
https://ly5851575-oss.github.io/termux-apt-repo/
```

## إضافته إلى Termux

```bash
echo "deb [trusted=yes] https://ly5851575-oss.github.io/termux-apt-repo/ ./" \
  > "$PREFIX/etc/apt/sources.list.d/checktool.list"

apt update
apt install -y checktool
```

## تشغيل CheckTool

```bash
checktool
```

للحصول على الأدوات الثقيلة غير المتوفرة أصلاً في مستودعات Termux عبر Debian/PRoot:

```bash
checktool --debian
```

> استخدم الأدوات فقط على الأنظمة والشبكات التي تملكها أو لديك تصريح صريح لاختبارها.
