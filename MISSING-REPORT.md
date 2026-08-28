# تقرير الجرد — Ather بعد النقل من ويندوز إلى لينكس

**تاريخ الجرد:** 2026-08-28
**المسار:** `/home/yassen/Yassen/ather1/ather`
**الفرع:** `ai-audit/2026-08-25` @ `dd7dc0d` — شجرة العمل نظيفة
**الجهاز:** Omarchy / Arch Linux، kernel 7.1.9-arch1-2

> **ملاحظة:** هذا تقرير قراءة فقط. لم يُعدَّل أي ملف في المشروع.
> كل ما هو غير مؤكد مكتوب صراحةً بـ **«غير مؤكد»** ولم يُخمَّن.

---

## ٠. نوع المشروع والإصدارات المطلوبة

| البند | القيمة | المصدر |
|---|---|---|
| النوع | تطبيق Flutter (`project_type: app`) | `.metadata:9` |
| المنصات المُعرَّفة | `android` + `windows` فقط — **لا يوجد `linux/` ولا `ios/` ولا `web/`** | `.metadata:14-21`، فحص الشجرة |
| اسم الحزمة | `ather` — الإصدار `1.9.0+17` | `pubspec.yaml:1,5` |
| `applicationId` | `com.ather.app` (ثابت، ممنوع تغييره — القاعدة ١) | `android/app/build.gradle.kts:79` |
| Dart SDK المطلوب | `^3.12.2` | `pubspec.yaml:8` |
| نظام البناء (أندرويد) | Gradle **9.1.0** (wrapper) | `android/gradle/wrapper/gradle-wrapper.properties:5` |
| AGP | `com.android.application` **9.0.1** | `android/settings.gradle.kts:19` |
| Kotlin | **2.3.20** | `android/settings.gradle.kts:23` |
| google-services plugin | **4.4.4** | `android/settings.gradle.kts:21` |
| Crashlytics plugin | **3.0.2** | `android/settings.gradle.kts:22` |
| Java source/target | **17** (و `jvmTarget = JVM_17`) | `android/app/build.gradle.kts:64-65,182` |
| compileSdk / targetSdk | **36 / 36** (من افتراضات Flutter) | `FlutterExtension.kt:23,34` |
| minSdk | **24** | `FlutterExtension.kt:26` |
| NDK | **28.2.13676358** | `FlutterExtension.kt:42` |
| Core library desugaring | مُفعَّل — `desugar_jdk_libs:2.1.4` | `android/app/build.gradle.kts:66,187` |
| قاعدة البيانات | Drift / SQLite محلي — ترحيل إلزامي عند تغيير `schemaVersion` | `CLAUDE.md` القاعدة ١ |
| Firebase | مشروع `ather-49705` — Core/Auth/Firestore/Crashlytics/App Check | `firebase.json`, `pubspec.yaml:56-70` |

**الإصدارات المتوفرة فعلياً على الجهاز:** Flutter **3.47.1** (stable, rev `6655482ec06`)، Dart **3.13.1**، JDK **21.0.12.1** (الافتراضي) + JDK **17.0.20.1** مثبَّت أيضاً.
قيد `^3.12.2` مُحقَّق بـ Dart 3.13.1. ✔

---

## جدول ١ — ملفات ناقصة حرجة (المشروع لن يبني/يعمل بدونها)

| الملف | ليه مهم | متذكور فين (ملف:سطر) | مساره في الويندوز | يتولّد من جديد؟ | لو لأ، تجيبه منين |
|---|---|---|---|---|---|
| **`ather-upload.jks`** (مفتاح التوقيع) | بدونه **بناء الـ release يفشل صراحةً** برسالة `GradleException`. وأهم من كده: القاعدة ١ — لو ضاع، Play لن يقبل أي تحديث موقَّع بمفتاح غير، وكل طالب هيضطر يمسح التطبيق ويفقد قاعدة بياناته المحلية. | `android/key.properties:16` (السطر `storeFile=`)؛ الحارس في `android/app/build.gradle.kts:20-46`؛ `RELEASING.md:12` | `C:\Users\kk783\keys\ather-upload.jks` | **لا — إطلاقاً.** توليد مفتاح جديد = هوية تطبيق جديدة. `CLAUDE.md` يمنع ذلك نصاً. | من نسخة احتياطية للـ `.jks` أو من مدير كلمات السر / القرص القديم. **بحثتُ في `/home/yassen` حتى عمق ٦ ولم أجد أي `.jks`/`.keystore`/`.p12` على هذا الجهاز.** |
| **كلمتا سر الـ keystore** (`storePassword`, `keyPassword`) | يقرأهما Gradle عند التوقيع. `key.properties` **موجود** لكن قيمتاهما لم أقرأهما (سياسة `CLAUDE.md`) — لذا حالتهما **غير مؤكدة**: قد تكونا مملوءتين وقد تكونا لا تزالان `REPLACE_ME`. | `android/key.properties:28-29` | نفس الملف | لا | مدير كلمات السر. **راجعها بنفسك:** `grep -c REPLACE_ME android/key.properties` |
| **Android SDK بالكامل** | لا يوجد أي SDK على الجهاز. بدونه لا debug ولا release ولا `adb` ولا `apksigner`. | `android/local.properties:1` (`sdk.dir=`)؛ `flutter doctor` → `[✗] Android toolchain` | `C:\Users\kk783\AppData\Local\Android\Sdk` | **نعم** — يُنزَّل من جديد | جدول ٤ |
| **`platform-36`, `build-tools`, `ndk;28.2.13676358`, `platform-tools`** | `compileSdk=36`، و NDK مطلوب لأن المشروع يبني `.so` (مجلدات `cxx` في `build/`) | `FlutterExtension.kt:23,42`; `android/app/build.gradle.kts:60-61` | تحت الـ SDK أعلاه | نعم | جدول ٤ |
| **`~/.android/debug.keystore`** | غير موجود. Gradle سيولِّده تلقائياً — لكن ببصمة SHA-1 **جديدة**. البصمتان المسجَّلتان في Firebase هما `f3eaec08…` و `6f69a69e…` (بصمات جهاز ويندوز). النتيجة: **Google Sign-In سيفشل في كل بناء debug على هذا الجهاز** حتى تُسجَّل البصمة الجديدة. | `RELEASING.md:66-76`؛ `android/app/google-services.json` (`certificate_hash`) | `C:\Users\kk783\.android\debug.keystore` | يتولَّد تلقائياً — لكن **البصمة ستختلف** | إمّا تنسخ الـ debug.keystore القديم من الويندوز، أو تسجّل SHA-1 الجديدة في Firebase وتُعيد تنزيل `google-services.json` |

---

## جدول ٢ — ملفات ناقصة غير حرجة

| الملف | ليه مهم | متذكور فين (ملف:سطر) | يتولّد من جديد؟ | من أين |
|---|---|---|---|---|
| **`.firebaserc`** | يربط المجلد بمشروع Firebase. بدونه `firebase deploy --only firestore:rules` و hosting لا يعرفان أي مشروع. | `firebase.json` كله يفترض وجوده؛ `RELEASING.md` §4a؛ `tool/check_deployed_rules.sh` | نعم | `firebase use --add` واختيار `ather-49705` (المعرّف موجود في `firebase.json:36`) |
| **`linux/`** (مجلد سطح مكتب لينكس) | غير موجود — لذا `flutter run -d linux` لن يعمل رغم أن `flutter doctor` يرى Linux toolchain سليماً. | `.metadata:14-21` تسرد `root`/`android`/`windows` فقط | نعم — `flutter create --platforms=linux .` | يتولَّد. **ملاحظة: هذا تعديل على المشروع، لم أنفّذه.** |
| **`.env` / `.env.local` / `.env.production`** | **لا وجود لها ولا إشارة لها في أي مكان.** المشروع لا يستخدم dotenv أصلاً — لا حزمة `flutter_dotenv` في `pubspec.yaml` ولا مدخل `assets` لها. | — | لا ينطبق | **لا شيء ناقص هنا.** ✔ |
| **`GoogleService-Info.plist`** | خاص بـ iOS، والمشروع لا يحتوي منصة iOS. | — | لا ينطبق | **لا شيء ناقص هنا.** ✔ |
| **service-account JSON** | لا إشارة له في أي ملف. لا يُستخدم. | — | لا ينطبق | **لا شيء ناقص هنا.** ✔ |
| **`firebase` CLI** | مطلوب لنشر قواعد Firestore و hosting. غير مثبَّت. | `RELEASING.md`؛ `firebase.json` | نعم | `npm i -g firebase-tools` (node 26.7.0 متوفر عبر mise) |
| **`flutterfire` CLI** | مطلوب لإعادة توليد `firebase_options.dart` / `google-services.json`. غير مثبَّت. | `firebase.json:33-46` | نعم | `dart pub global activate flutterfire_cli` |

### ملفات كان يمكن أن تكون ناقصة — وتحققتُ أنها **موجودة** ✔

`android/app/google-services.json` (متتبَّع في git) · `lib/firebase_options.dart` (متتبَّع) · `firebase.json` · `firestore.rules` · `android/key.properties` (موجود، غير متتبَّع) · `android/local.properties` (موجود، غير متتبَّع) · `android/gradle/wrapper/gradle-wrapper.jar` · `android/gradlew` (تنفيذي، LF) · `assets/fonts/ReadexPro.ttf` · الكود المولَّد كامل: `lib/core/l10n/generated/*.dart` و `lib/data/db/app_database.g.dart` · `.dart_tool/package_config.json` و `~/.pub-cache` (900MB، 304 حزمة) — أي أن `pub get` مُنجَز.

---

## جدول ٣ — مسارات ويندوز محتاجة تتظبط

### أ) مسارات فعّالة — تؤثر على البناء

| # | الملف:السطر | المسار الكامل | بيشاور على إيه | البديل في لينكس |
|---|---|---|---|---|
| 1 | `android/key.properties:16` | `C:\\\\Users\\\\kk783\\\\keys\\\\ather-upload.jks` | ملف مفتاح التوقيع | `/home/yassen/keys/ather-upload.jks` — **بشرط إحضار الـ `.jks` أولاً** (جدول ١). في ملف `.properties` يمكن كتابة المسار بشرطة مائلة عادية. |
| 2 | `android/local.properties:1` | `C:\\Users\\kk783\\AppData\\Local\\Android\\Sdk` | `sdk.dir` — جذر Android SDK | `/home/yassen/Android/Sdk` (ليتطابق مع `ANDROID_HOME` الحالي) |
| 3 | `.commandcode/settings.json:11` | `C:\\Users\\kk783\\AppData\\Local\\Android\\Sdk\\build-tools\\36.0.0\\apksigner.bat` | صلاحية تشغيل `apksigner` | `$ANDROID_HOME/build-tools/36.0.0/apksigner` |
| 4 | `.commandcode/settings.json:10` | `C:\\Program Files\\Git\\bin\\bash.exe` | صلاحية تشغيل bash | `/usr/bin/bash` |
| 5 | `.commandcode/settings.json:8,9` | `windows\flutter\ephemeral\.plugin_symlinks` + أوامر `dir` و `findstr` و `2>nul` | أوامر cmd ويندوز داخل صلاحيات | `ls` / `grep` / `2>/dev/null` |

> **ملاحظة:** `local.properties:2` قيمته `flutter.sdk=/home/yassen/.cache/flutter_sdk` — **مسار لينكس صحيح وموجود**، وهو نفس إصدار Flutter الموجود في `/opt/flutter` (كلاهما rev `6655482ec06` = 3.47.1). هذا السطر **مضبوط بالفعل**. لكن السطرين `flutter.versionName=1.6.0` و `flutter.versionCode=11` قديمان مقارنةً بـ `pubspec.yaml` (1.9.0+17) — هما مخرجات بناء قديم، ويُعاد كتابتهما مع كل `flutter build`، لذا **غير حرجين**.

### ب) مسارات في إعدادات الـ IDE — تعطِّل الاستكمال في Android Studio فقط، لا تؤثر على البناء من الطرفية

| # | الملف | العدد | المسار النموذجي | البديل |
|---|---|---|---|---|
| 6 | `.idea/libraries/Dart_Packages.xml` | **338 سطراً** | `file://$USER_HOME$/AppData/Local/Pub/Cache/hosted/pub.dev/…` | `~/.pub-cache/hosted/pub.dev/…` |
| 7 | `.idea/libraries/Flutter_Plugins.xml` | **33 سطراً** | نفس النمط | نفس البديل |
| 8 | `.idea/libraries/Dart_SDK.xml` | **11 سطراً** | `file://C:\flutter/bin/cache/dart-sdk/lib/…` | `/opt/flutter/bin/cache/dart-sdk/lib/…` |
| 9 | `.idea/workspace.xml:53` | 1 | `"last_opened_file_path": "C:/ather"` | `/home/yassen/Yassen/ather1/ather` |

> **الحل العملي لكل هذا القسم:** هذه الملفات كلها مُستثناة في `.gitignore` (`.idea/`, `*.iml`) — يُفضَّل **حذف `.idea/` و `sahm.iml` و `android/sahm_android.iml`** وترك Android Studio يعيد توليدها. **لم أحذف شيئاً.**

### ج) مسارات في التوثيق — لا تكسر شيئاً، لكنها تُضلِّل من يتبع الخطوات

| الملف:السطر | المسار |
|---|---|
| `RELEASING.md:12`, `:54` (وأمثلة `keytool` في §2 و §3) | `C:\Users\<you>\keys\ather-upload.jks`، `/c/Users/<you>/keys/` |
| `android/key.properties.example:15`, `:25` | `C:\Users\<you>\keys\ather-upload.jks` |
| `android/app/build.gradle.kts:36` | `<path>\\ather-upload.jks` داخل نص رسالة الخطأ |
| `PROJECT.md:1122`, `:1432` | `C:\ather`, `C:\arrow` (سياق تاريخي — يوثّق حادثة نقل سابقة) |
| `animation/PROMPT_COMPANY.md:4,12,18,24` | `C:\ather\animation` |

### د) نتائج بحث سلبية (لا توجد) ✔

- `%USERPROFILE%` / `%APPDATA%` / `%LOCALAPPDATA%` وأي `%VAR%` → **صفر نتائج** في الملفات النصية.
- مسارات UNC `\\server\share` → **صفر**. (النتيجة الوحيدة `Software\\Microsoft\\Windows\\…` في `windows/runner/win32_window.cpp:26` هي مفتاح ريجستري داخل كود ويندوز الأصلي — سليمة ولا تُمسّ.)
- `file:///` → **صفر**.
- `.vscode/` → غير موجود.
- ملفات `.bat`/`.cmd`/`.ps1` خارج `build/`: `android/gradlew.bat` فقط — جزء قياسي من قالب Flutter، يُترك كما هو.

### هـ) نهايات الأسطر CRLF

الشجرة نُسخت من ويندوز فحملت CRLF: **90 من 113 ملف `.dart`** في `lib/`، بالإضافة إلى `CLAUDE.md`, `PROJECT.md`, `analysis_options.yaml`, `android/app/build.gradle.kts` وغيرها.
`git status` نظيف لأن `.gitattributes` فيه `* text=auto` فيُطبِّع إلى LF داخل المستودع.
**الأثر: منخفض** — Dart وKotlin وYAML تتحمّل CRLF. والأهم أن ملفات `.sh` سليمة: `tool/check_invariants.sh` و `tool/check_deployed_rules.sh` و `android/gradlew` كلها **LF وقابلة للتنفيذ** (بفضل `*.sh text eol=lf`) — وهذا بالضبط ما كان سيكسر البناء لو تعطّل.

---

## جدول ٤ — أدوات وبيئة: المتوفر والناقص + أوامر Arch

### المتوفر ✔

| الأداة | الإصدار | المسار |
|---|---|---|
| Flutter | 3.47.1 stable | `/opt/flutter` (عبر `flutter-bin`) |
| Dart | 3.13.1 | `/usr/bin/dart` |
| JDK 21 | 21.0.12.1 (الافتراضي) | `/usr/lib/jvm/java-21-openjdk` |
| JDK 17 | 17.0.20.1 | مثبَّت، غير مُفعَّل |
| Android Studio | 2026.1.3.8 | `/opt/android-studio` (+ JBR مدمج) |
| keytool | مع JDK | `/usr/bin/keytool` |
| cmake / ninja / clang | 4.4.2 / 1.13.2 / 22.1.8 | `/usr/bin/` |
| git / unzip | — | `/usr/bin/` |
| node / npm | 26.7.0 | عبر mise |
| pub cache | 900 MB، 304 حزمة | `~/.pub-cache` |
| yay (AUR) | — | `/usr/bin/yay` |

### الناقص ✘

| الناقص | الأثر | أمر التثبيت على Arch |
|---|---|---|
| **Android SDK** (لا يوجد أي نسخة على القرص) | لا بناء أندرويد إطلاقاً | `yay -S android-sdk-cmdline-tools-latest` ثم `sdkmanager` أدناه — أو الأسهل: افتح **Android Studio** (مثبَّت) → SDK Manager ونزّله إلى `~/Android/Sdk` |
| platform 36 · build-tools 36.0.0 · platform-tools · ndk 28.2.13676358 | `compileSdk`/NDK/`adb` | `sdkmanager "platforms;android-36" "build-tools;36.0.0" "platform-tools" "ndk;28.2.13676358"` |
| قبول تراخيص SDK | Gradle يرفض البناء بدونها | `flutter doctor --android-licenses` |
| `adb` | لا تثبيت على جهاز/محاكي | يأتي مع `platform-tools`، أو `sudo pacman -S android-tools` |
| `apksigner` | **لا يمكن التحقق من شهادة الـ APK** — وهذا الفحص الوحيد الذي لا يستطيع `check_invariants.sh` القيام به (`CLAUDE.md`) | يأتي مع `build-tools;36.0.0`، أو `sudo pacman -S android-tools` |
| `ANDROID_HOME` | مضبوط على `/home/yassen/Android/Sdk` وهو **مسار غير موجود** — لذا `flutter doctor` يفشل | أنشئ المجلد ونزّل الـ SDK فيه، أو صحّح المتغيّر ليطابق موقع التنزيل الفعلي |
| `firebase` CLI | لا نشر لقواعد Firestore ولا hosting | `npm i -g firebase-tools` |
| `flutterfire` CLI | لا إعادة توليد لـ `firebase_options.dart` | `dart pub global activate flutterfire_cli` |
| `mesa-utils` (اختياري) | `flutter doctor` ينبّه أنه لا يقرأ معلومات التعريف عبر `eglinfo` — تحذير فقط | `sudo pacman -S mesa-utils` |
| Chrome (اختياري) | تطوير الويب فقط — والمشروع لا يحتوي منصة web | `yay -S google-chrome` أو `CHROME_EXECUTABLE=/usr/bin/chromium` |

> **`gradle` غير مثبَّت — وهذا صحيح ومقصود.** المشروع يستخدم الـ wrapper (`android/gradlew` + `gradle-9.1.0-all.zip`)، وهو ينزّل Gradle بنفسه. لا تثبّت gradle من النظام.

> **بخصوص JDK:** الافتراضي حالياً JDK 21، والمشروع يستهدف Java 17 (`sourceCompatibility`/`jvmTarget`). Gradle 9.1 و AGP 9.0.1 يعملان على JDK 21 من حيث المبدأ، لكنني **لم أتحقق عملياً** لأن ذلك يتطلب بناءً فعلياً. **غير مؤكد.** لو ظهر خطأ toolchain، الحل: `sudo archlinux-java set java-17-openjdk` أو `org.gradle.java.home` في `gradle.properties`.

---

## ٥. تاريخ git — هل حُذفت هذه الملفات من قبل؟

**لا. ولم تكن موجودة أصلاً في أي وقت.**

فحصتُ كل الفروع (`git log --all --diff-filter=D`) وأيضاً كل تاريخ كل مسار:

| النمط | عدد المرات في التاريخ |
|---|---|
| `*.jks` | **0** |
| `*.keystore` | **0** |
| `android/key.properties` | **0** |
| `android/local.properties` | **0** |
| `*.env` | **0** |
| `*.p12` / `*.pem` | **0** |
| `GoogleService-Info.plist` | **0** |

مجموع الملفات المحذوفة في تاريخ المستودع كله = **13 ملفاً**، ولا واحد منها ملف سرّي أو ملف بيئة:
`lib/core/widgets/week_strip.dart`, `test/widget/week_strip_test.dart`, `PLAN.md`, `tool/add_p5_arb.py`, `tool/add_p5_rich_arb.py`, `tool/fix_p3_arb.py`, `opencode/PROJECT_REVIEW_REPORT.md`, `.auto-claude-security.json`, `.auto-claude-status`, `.claude_settings.json`, `wt-session-a`, `wt-session-b`, `android/build/reports/problems/problems-report.html`.

**الاستنتاج:** الملفات الناقصة لم تُحذف — هي **لم تسافر مع المستودع أبداً**، لأنها كلها مُستثناة في `.gitignore`. لذا لا يمكن استرجاع أي منها من git ولا من `ather-all-backup.bundle` (حزمة git لا تحمل إلا ما هو متتبَّع). **مصدرها الوحيد هو جهاز الويندوز القديم أو نسخة احتياطية خارجية.**

---

## ٦. تحليل `.gitignore` و `.gitattributes` — «المستثنى = الضائع»

### النمط الحاكم

`.gitignore` يستثني بالضبط ما يجب أن يُنقل يدوياً. لكل مُدخَل، هل ضاع فعلاً؟

| السطر في `.gitignore` | النمط | الحالة على القرص |
|---|---|---|
| 66 | `android/key.properties` | ✔ **موجود** (نُقل يدوياً — لكن `storeFile` بداخله يشير لمسار ويندوز) |
| 67 | `*.jks` | ✘ **ضائع — حرج** |
| 68 | `*.keystore` | ✘ ضائع (والـ debug keystore أيضاً) |
| — | `.idea/`, `*.iml` | ⚠ **موجود لكنه ملوَّث بمسارات ويندوز** (383 سطراً) |
| — | `.dart_tool/`, `.flutter-plugins-dependencies` | ✔ موجود ومحدَّث |
| — | `build/`, `.gradle/` | ✔ موجود (مخلَّفات بناء ويندوز — تُحذف بأمان بـ `flutter clean`) |
| — | `*.apk`, `*.aab`, `public/*.apk`, `dist/` | ✔ موجودة (3 APK في `dist/` + `public/ather-latest.apk`) |
| — | `.commandcode/` | ⚠ **موجود وملوَّث بمسارات ويندوز** (5 أسطر) |
| — | `.auto-claude/`, `.claude_settings.json`, `.security-key`, `logs/security/` | ✘ غير موجودة — و**لا حاجة لها**: `grep` على `lib test tool .github` يعطي صفر إشارات إليها |

`android/.gitignore` يضيف: `/local.properties` (✔ موجود، فيه مسار ويندوز)، `key.properties` (✔ موجود)، `**/*.keystore` و `**/*.jks` (✘ ضائعان)، `gradle-wrapper.jar` و `/gradlew` (✔ موجودان رغم الاستثناء).

### `.gitattributes`

مكتوب لمستودع كان يُعمل عليه من ويندوز (`core.autocrlf=true`). القاعدة الحاسمة بعد النقل هي `*.sh text eol=lf` — وهي **فعّالة وصحيحة**: كل سكربتات الـ shell سليمة LF وقابلة للتنفيذ. لا يوجد فيها ما هو ناقص.

---

## ٧. ملاحظات إضافية ظهرت أثناء الجرد

1. **`.claude/worktrees/` و `.claude/worktasks/` نسخ ميتة.** سبعة مجلدات + مجلد مهام، **مُتتبَّعة في git (297 ملفاً)**، وكلها نسخ كاملة قديمة من المشروع من عصر `C:\ather`، بنهايات CRLF ومسارات ويندوز. `git worktree list` يُظهر worktree واحداً فقط (هذا)، و `git -C` على كلٍ منها يرد `fatal: not a git repository`. **فحص القاعدة ٢ نظيف — لا يوجد عمل أحدث مخفي.** لكنها تُضخّم كل عملية بحث ويجب أن تُحذف في مهمة منفصلة.
2. **CI يثبّت Flutter 3.44.6** (`.github/workflows/guardrails.yml:37`) بينما الجهاز عليه 3.47.1. فارق قد يُنتج نتائج تحليل مختلفة بين المحلي والـ CI. **غير حرج.**
3. **`check_invariants.sh` يقارن مقابل `origin/main`** — الفرع موجود (`3f2873b`)، فالسكربت سيعمل كاملاً على هذا الجهاز.
4. **التوافقات صحيحة:** `settings_screen.dart:63` فيه `appVersion = '1.9.0+17'` مطابق لـ `pubspec.yaml`. ✔
5. **بصمتان SHA-1 مسجَّلتان** في `google-services.json` لحزمة `com.ather.app` — ولا واحدة منهما تخصّ هذا الجهاز (لا يوجد debug.keystore هنا بعد).

---

## ٨. الخطوات المرتَّبة للوصول إلى بناء ناجح

### المرحلة أ — تشغيل الاختبارات والتحليل (لا تحتاج Android SDK إطلاقاً) — ابدأ من هنا

```bash
cd /home/yassen/Yassen/ather1/ather
flutter pub get
flutter analyze
flutter test
bash tool/check_invariants.sh origin/main
```
كل هذا يعمل **الآن** بما هو مثبَّت. لو نجح، فالكود نفسه سليم بعد النقل والمشكلة كلها في البيئة والتوقيع.

### المرحلة ب — تركيب Android SDK (يفتح باب بناء الـ debug)

```bash
# الأسهل: Android Studio مثبَّت بالفعل
#   افتحه → More Actions → SDK Manager → نزّل إلى ~/Android/Sdk:
#   Android 36 · Build-Tools 36.0.0 · Platform-Tools · NDK 28.2.13676358
#
# أو من الطرفية:
yay -S android-sdk-cmdline-tools-latest
export ANDROID_HOME="$HOME/Android/Sdk"     # يطابق المضبوط حالياً
sdkmanager --sdk_root="$ANDROID_HOME" \
  "platforms;android-36" "build-tools;36.0.0" \
  "platform-tools" "ndk;28.2.13676358"

flutter doctor --android-licenses
flutter doctor -v          # يجب أن يصبح Android toolchain ✓
```
ثبّت `ANDROID_HOME` في `~/.bashrc` حتى لا يضيع مع كل جلسة.

### المرحلة ج — إصلاح مسارَي الويندوز الفعّالين

> **لم أنفّذ أياً من هذا. القرار لك.**

1. `android/local.properties:1` → `sdk.dir=/home/yassen/Android/Sdk`
   *(بديل أنظف: احذف السطر تماماً — Flutter يعيد كتابة الملف من `ANDROID_HOME` في أول بناء.)*
2. نظّف مخلَّفات بناء ويندوز: `flutter clean`
3. اختياري: احذف `.idea/` و `sahm.iml` و `android/sahm_android.iml` ليعيد Android Studio توليدها بمسارات لينكس.

### المرحلة د — أول بناء debug (تحقُّق من أن السلسلة كلها تعمل)

```bash
flutter build apk --debug
```
هذا **لا يحتاج** الـ keystore — الحارس في `build.gradle.kts:26-46` مشروط بـ `Release` فقط.
سيولّد Gradle عندها `~/.android/debug.keystore` ببصمة جديدة.

### المرحلة هـ — إعادة ربط Google Sign-In بهذا الجهاز

```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore \
  -storepass android | grep SHA
```
سجّل SHA-1 (و SHA-256) في Firebase Console → مشروع `ather-49705` → إعدادات المشروع → `com.ather.app` → Add fingerprint → ثم أعد تنزيل `google-services.json` إلى `android/app/`.
**بدون هذه الخطوة سيبني التطبيق ويعمل، لكن تسجيل الدخول بجوجل سيفشل صامتاً.**

### المرحلة و — بناء release ← **محجوبة حتى يصل ملف `.jks`**

هذه المرحلة **لا يمكن إتمامها على هذا الجهاز الآن**، وليس بسبب نقص أداة:

- ملف `ather-upload.jks` غير موجود على هذا الجهاز (بحثتُ حتى عمق ٦ تحت `/home/yassen`).
- ولا يمكن استرجاعه من git ولا من `ather-all-backup.bundle` — لم يكن متتبَّعاً قط.
- و`CLAUDE.md` يمنع صراحةً توليد مفتاح جديد للالتفاف على المشكلة: المفتاح هو هوية التطبيق على Play، ومفتاح خاطئ أو ضائع يعني أن Ather **لا يمكن تحديثه أبداً** — وكل طالب يفقد قاعدة بياناته المحلية.

**ما عليك فعله:**
1. أحضِر `ather-upload.jks` من جهاز الويندوز (`C:\Users\kk783\keys\`) أو من نسختك الاحتياطية، وضعه خارج المستودع — مثلاً `~/keys/ather-upload.jks`.
2. حدّث `android/key.properties:16` إلى `storeFile=/home/yassen/keys/ather-upload.jks`.
3. تأكد أن سطرَي كلمة السر مملوءان: `grep -c REPLACE_ME android/key.properties` يجب أن يعطي `0`.
4. ارفع `+N` في `pubspec.yaml` — و**عدّل `appVersion` في `settings_screen.dart:63` معه** (`check_invariants.sh` يفشل لو اختلفا).
5. ثم:
```bash
bash tool/check_invariants.sh origin/main
flutter build apk --release --target-platform android-arm64
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```
الشهادة **يجب** أن تحمل بياناتك، لا `CN=Android Debug`. وسجّل SHA-1 مفتاح الـ release في Firebase أيضاً (`RELEASING.md` §3) وإلا فشل تسجيل الدخول لكل مستخدم حقيقي.

### المرحلة ز — أدوات Firebase (عند الحاجة للنشر)

```bash
npm i -g firebase-tools
firebase login
firebase use --add          # اختر ather-49705 — ينشئ .firebaserc الناقص
dart pub global activate flutterfire_cli
```

---

## الخلاصة في ثلاثة أسطر

- **حاجز واحد لا يُتجاوز:** ملف `ather-upload.jks`. غير موجود، غير قابل للاسترجاع من git، وممنوع توليد بديل له. بدونه لا يوجد بناء release — نهائياً.
- **حاجز واحد قابل للحل بالكامل:** لا يوجد Android SDK على الجهاز. ساعة تنزيل وينتهي، ويصبح بناء الـ debug ممكناً.
- **مساران فقط من مسارات ويندوز يؤثران على البناء** (`local.properties` و `key.properties`). الباقي — 383 سطراً في `.idea/`، و5 في `.commandcode/`، وما في التوثيق — ضوضاء لا تكسر شيئاً.

الكود نفسه، والكود المولَّد، وحزم pub، وملفات Firebase المتتبَّعة، وسكربتات الـ shell: **كلها وصلت سليمة.**
