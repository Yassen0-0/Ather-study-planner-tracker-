# برومبت للـ AI على جهاز الويندوز

> انسخ كل ما تحت الخط وابعته كما هو.

---

أنت على جهاز ويندوز فيه نسخة قديمة من مشروع Flutter اسمه **Ather** (`applicationId = com.ather.app`، مشروع Firebase `ather-49705`).
المشروع اتنقل لجهاز لينكس، والنسخة اللي هناك **ناقصة ملفات مهمة** لأنها كلها مُستثناة في `.gitignore` فمسافرتش مع المستودع.

مطلوب منك تجمع الملفات دي، **تتحقق إنها الصح**، وتحطها في أرشيف واحد مضغوط بكلمة سر.

---

## ممنوعات — اقراها الأول

1. **ممنوع تولّد keystore جديد** بـ `keytool -genkey` مهما حصل. مفتاح التوقيع هو هوية التطبيق على Google Play. مفتاح جديد = تطبيق جديد، وكل طالب مستخدم التطبيق هيضطر يمسحه ويفقد قاعدة بياناته المحلية (مفيش نسخة على سيرفر). لو ملقتش المفتاح، **قول كده صراحةً** وخلاص.
2. **ممنوع تكتب أي كلمة سر في الشات** أو في أي ملف هيترفع على git.
3. **ممنوع تعمل `git add` أو `git commit` لأي ملف `.jks` أو `.keystore` أو `key.properties`.** لو اتحطوا في git مرة واحدة بيفضلوا في تاريخ كل نسخة للأبد.
4. **ممنوع ترفع الأرشيف على أي خدمة سحابية أو تبعته في إيميل أو شات.** الانتقال يكون USB أو ناقل مباشر.
5. متعملش أي تعديل على ملفات المشروع. ده جمع ونقل بس.

---

## الخطوة ١ — فحص شغل مش مرفوع (اعملها الأول، قبل أي حاجة)

المشروع ده بيتشتغل عليه بـ git worktrees، وفي سابقة إن شغل خلص وفضل غير مُرفوع في worktree تاني فطلع APK بتصميم قديم.

روح لمجلد المشروع على الويندوز واعمل:

```powershell
git worktree list
git status --short
git log --oneline -5
git branch -vv
```

وبعدين لكل worktree ظاهر في القايمة:

```powershell
git -C "<مسار الـ worktree>" status --short
```

**بلّغني بالنتيجة:** هل في تعديلات غير مرفوعة تحت `lib/`؟ في أي فرع؟ آخر commit إيه وتاريخه إيه؟
**متعملش commit ولا push من نفسك** — استنى ردي.

---

## الخطوة ٢ — دوّر على ملفات التوقيع

المسار المتوقع للمفتاح الأساسي (من `android/key.properties` في النسخة القديمة):

```
C:\Users\kk783\keys\ather-upload.jks
```

اتأكد منه، وبرضه امسح القرص كله عشان لو اتنقل:

```powershell
Get-ChildItem -Path C:\Users -Include *.jks,*.keystore,*.p12,*.pfx -Recurse -File -ErrorAction SilentlyContinue |
  Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
```

لو ملقتش حاجة، وسّع لـ `-Path C:\` (هياخد وقت أطول).

كمان دوّر على:

```powershell
Test-Path "$env:USERPROFILE\.android\debug.keystore"
Get-ChildItem -Path C:\Users -Include .env,.env.local,.env.production,.firebaserc -Recurse -File -Force -ErrorAction SilentlyContinue |
  Select-Object FullName
```

---

## الخطوة ٣ — تحقّق إن الـ `.jks` هو الصح (أهم خطوة)

مش أي `.jks` ينفع. لازم بصمته تطابق واحدة من البصمتين المسجّلتين في Firebase للتطبيق ده:

```
f3eaec08a58d41d334d22abade33b1e89577623e
6f69a69ee9b3b2a7717c083a833636b9e6e8e86e
```

شغّل الأمر ده (هيطلب كلمة سر المخزن — **اكتبها في الطرفية بس، متكتبهاش في ردك**):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
  -keystore "C:\Users\kk783\keys\ather-upload.jks" -alias ather
```

*(لو `keytool` مش في المسار ده، دوّر عليه: `Get-ChildItem -Path "C:\Program Files" -Filter keytool.exe -Recurse -ErrorAction SilentlyContinue`)*

واعمل نفس الحاجة للـ debug keystore (كلمة السر بتاعته ثابتة ومعروفة وهي `android`):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
  -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android
```

**بلّغني بالآتي لكل مخزن:** الـ SHA-1 والـ SHA-256، واسم الـ alias، و الـ `Owner` (الـ DN)، وتاريخ `Valid from/until`.
البصمات دي مش أسرار — ابعتها عادي. قارنها بالبصمتين فوق (تجاهل النقطتين `:` وحالة الحروف) وقولي أنهي مخزن طابق أنهي بصمة.

⚠️ **علامة خطر:** لو الـ `Owner` مكتوب فيه `CN=Android Debug` في ملف `ather-upload.jks`، يبقى ده مش مفتاح الرفع الحقيقي — بلّغني فوراً ومتكملش.

---

## الخطوة ٤ — اجمع الملفات في مجلد واحد

```powershell
$dst = "$env:USERPROFILE\Desktop\ather-handoff"
New-Item -ItemType Directory -Force -Path $dst | Out-Null

# 1. مفتاح الرفع — الملف الحرج
Copy-Item "C:\Users\kk783\keys\ather-upload.jks" -Destination $dst

# 2. مفتاح الـ debug — عشان تسجيل الدخول بجوجل يفضل شغال في بناء debug
Copy-Item "$env:USERPROFILE\.android\debug.keystore" -Destination $dst

# 3. ملف كلمات السر من مجلد المشروع (فيه الباسوردات — عشان كده الأرشيف بكلمة سر)
Copy-Item "<مسار المشروع>\android\key.properties" -Destination $dst
```

ولو لقيت في الخطوة ٢ أي `.env` أو `.firebaserc` أو ملفات `.jks`/`.p12` تانية — ضيفها للمجلد كمان.

---

## الخطوة ٥ — اعمل ملف MANIFEST.txt

```powershell
Get-ChildItem $dst -File | ForEach-Object {
    "{0}`t{1} bytes`t{2}" -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash
} | Tee-Object -FilePath "$dst\MANIFEST.txt"
```

الملف ده مش سري — ابعت محتواه في ردك عشان أتأكد إن النقل وصل سليم بايت ببايت.

---

## الخطوة ٦ — اضغط بكلمة سر

```powershell
& "C:\Program Files\7-Zip\7z.exe" a -t7z -p -mhe=on -mx=9 `
  "$env:USERPROFILE\Desktop\ather-handoff.7z" "$dst\*"
```

`-mhe=on` بتشفّر أسماء الملفات كمان.
اختار كلمة سر قوية وسلّمها **بقناة منفصلة عن الأرشيف نفسه** (شفهي أو مدير كلمات سر) — **متكتبهاش في ردك**.

وبعدين امسح المجلد المؤقت:

```powershell
Remove-Item -Recurse -Force $dst
```

---

## ابعتلي في ردك

**ابعت:**
- نتيجة الخطوة ١ كاملة (فروع، شغل غير مرفوع، آخر commit)
- بصمات SHA-1 و SHA-256 وبيانات الـ Owner لكل مخزن
- محتوى `MANIFEST.txt`
- قايمة أي ملفات `.jks`/`.keystore`/`.env` تانية لقيتها ومسارها
- تأكيد إن `ather-handoff.7z` اتعمل، وحجمه

**متبعتش:**
- أي كلمة سر (لا بتاعت المخزن ولا بتاعت الأرشيف)
- محتوى `key.properties`
- الملفات نفسها

---

## لو ملقتش `ather-upload.jks`

متولّدش بديل. دوّر في الأماكن دي بالترتيب:

1. نسخ احتياطية خارجية — هارد خارجي، USB، أو نسخة النظام
2. OneDrive / Google Drive / Dropbox — نصّ البحث: `ather-upload` أو `*.jks`
3. مدير كلمات السر — ناس كتير بتحط الـ keystore كمُرفق مع الباسورد
4. سلة المحذوفات و `C:\Users\kk783\keys\` لو المجلد نفسه موجود بس فاضي
5. أي جهاز تاني اتبنى عليه release قبل كده

وبلّغني بالنتيجة صراحةً حتى لو سلبية — عشان أعرف إن بناء الـ release مقفول ومحتاج قرار من صاحب المشروع.
