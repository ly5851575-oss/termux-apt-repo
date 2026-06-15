# NetHunter Setup & secctl

نظام منظم لتثبيت وإدارة Kali NetHunter Rootless على Termux، مع أمر مركزي باسم `secctl`.

## ما الذي يحافظ عليه المشروع؟

- لا يحذف أدوات موجودة عند إضافة أدوات جديدة.
- يمنع تكرار اسم الأداة بين ملفات الحزم.
- لا يحتوي على تكامل ذكاء اصطناعي أو إرسال تقارير إلى أي خدمة خارجية.
- لا يحذف Kali أو ملف rootfs من خلال `secctl cleanup`.
- يستخدم مصادر Kali وGitHub الرسمية للأدوات التي تحتاج تثبيتًا خارجيًا.

## التثبيت

من Termux:

```bash
cd ~/termux-apt-repo/nethunter-setup
bash bin/secctl setup
```

## الأوامر

```bash
secctl doctor
secctl install --profile all
secctl status
secctl inventory
secctl report
secctl update
secctl cleanup
secctl version
```

## ملفات الأدوات

- `core`: أساسيات النظام والبناء والتحرير.
- `web`: أدوات تدقيق تطبيقات الويب المصرح به.
- `network`: تشخيص الشبكات والحزم.
- `forensics`: التحليل الجنائي للملفات.
- `audit`: فحوصات الجودة المحلية.
- `system_audit`: تدقيق النظام والبرمجيات الخبيثة.
- `code_supply_chain`: تحليل الكود وسلسلة التوريد.
- `binary_analysis`: تحليل البرامج وتصحيحها.

## الاستخدام القانوني

استخدم الأدوات فقط على الأنظمة والشبكات التي تملكها أو لديك تصريح مكتوب لاختبارها. NetHunter Rootless لا يمنح Root حقيقيًا لأندرويد، وبعض قدرات الشبكات منخفضة المستوى ستبقى محدودة.
