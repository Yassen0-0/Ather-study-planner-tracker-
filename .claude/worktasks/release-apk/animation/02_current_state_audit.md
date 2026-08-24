# جرد نظام الحركة الحالي — تقرير فريق تدقيق الكود

> مصدر الحقيقة: قراءة سطر بسطر لـ `lib/core/theme/app_spacing.dart` و`lib/core/widgets/*`
> والشِل والمسارات. هذا تشخيص، ليس حكمًا — الهندسة الحالية منضبطة بشكل استثنائي.

## 1. جدول توكنز `AppMotion` الكامل

| التوكن | القيمة | ملاحظة |
|---|---|---|
| `pressScale` | `0.97` | |
| `press` | `140ms` + `Cubic(0.34, 1.4, 0.64, 1)` | المنحنى الوحيد مع `celebrationCurve` المتجاوز لـ1.0 |
| `sheet` / `sheetCurve` | `280ms`, `Cubic(0.22, 1, 0.36, 1)` | ⚠️ الشيت الفعلي لا يستهلكهما (انظر §4) |
| `celebration` / `celebrationCurve` | `500ms`, `Cubic(0.34, 1.56, 0.64, 1)` | |
| `value` / `valueCurve` | `600ms`, `easeOutCubic` | للبارات والأرقام |
| `toast` | `2200ms` | مدة بقاء وليست منحنى |
| `standard` | `Cubic(0.23, 1, 0.32, 1)` | "الـ ease-out الواحد"، ~25 موقع استخدام |
| `page`/`pageRise` | `220ms`/`8px` | دفع المسارات |
| `nav` | `150ms` | الأقصر في التطبيق — التاب |
| `enter`/`enterRise`/`stagger`/`staggerCap` | `260ms`/`12px`/`40ms`/`6` | دخول الصفوف |
| `exit` | `200ms` | خروج أقصر من الدخول عمدًا |
| `step`/`stepRise`/`segment` | `200ms`/`10px`/`250ms` | الويزارد |
| `micro`/`microRise`/`microOut` | `180ms`/`6px`/`150ms` | توست، بنرات، checkbox |
| `pop`/`tick`/`flood` | `200ms`/`220ms`/`120ms` | flood+tick = 340ms |
| `beforeAfterArrowDelay`/`ValueDelay` | `60ms`/`120ms` | تسلسل قبل→سهم→بعد |
| `glassSigma`/`glassTint` | `24`/`0.85` | سيجما لا تتحرك أبدًا |

توكنز محذوفة موثقة كقبر: `weekSnap`, `weekSnapCurve`, `weekGlowPulse` — متت مع الـ week strip.

**الإحصائية المفصلية: صفر استخدام لـ `SpringSimulation` أو `SpringDescription` في `lib/` كله.**
كل التجاوزات الحالية (press/celebration) هي Cubic مزيّفة تحاكي bounce بدون فيزياء.

## 2. آليات الودجات المحركة (الأساسية)

### M-20 أيقونة التاب — `icon_motion.dart` (`TabGlyph`)
- `TweenAnimationBuilder<double>` واحد على `nav`(150ms)/`standard`.
- توين **واحد يوزَّع على مستهلكين**: `Color.lerp` للون (الأيقونة والنص من نفس اللحظة عبر builder)،
  و`selection` (0..1) يدخل رسّام الحرف:
  - `home`: fill-alpha تحت الخط الثابت 1.9 (لا يتغير مسار).
  - `review`: خط 2→3 + زوايا رؤوس الأسهم تمتلئ alpha.
  - `chart`: 2.1→3.4 · `tasks`: 1.9→2.9.
- `shouldRepaint` يشمل تغير selection → إطارات وسطية صحيحة.
- **صفر transforms، صفر scale، صفر path mutation.**

### `Pressable` — ضغطة كل ما يمكن لمسه
- `AnimatedScale` إلى 0.97 عند الضغط، 140ms `pressCurve`. Reduce-motion ⇒ ثبات تام.
- إعلانات `button` + `semanticLabel` + `minTarget` 48dp.

### العائلة الغارقة (flood) — أفضل لحظة دقيقة في التطبيق
- `CompletionDisc`: مراقب صريح 340ms مقسوم 120(flood)/220(tick)؛ مزروع بقيمته الحالية
  فلا يعيد التشغيل عند scroll؛ قابل للعكس mid-flight؛ reduce-motion ⇒ قيمة مباشرة.
- `OverdueMark`: مراقب كسول `AnimationController? ??=` (dispose آمن)، 370ms:
  flood ثم fade+collapse عبر `Align(widthFactor)` — يخرج ولا يحتفظ بعلامة صح خضراء دائمة.

### `ListEntrance/RiseIn`
- التذكّر لكل زيارة شاشة عبر `Set` داخل Scope (`updateShouldNotify:false`).
- السقف `min(index, 6)` ⇒ أقصى تأخير 240ms مهما طالت القائمة.
- **التأخير Interval على المراقب نفسه وليس `Future.delayed`** — سبب استقرار `pumpAndSettle`.

### الباقي بسرعة
`MasteryBar`/`AnimatedPercentage`: TAB بخدعة begin==end (أول رسم = الحالة النهائية).
`CelebrationOverlay`: القرص فقط 500ms؛ **العنوان والرقم أطفال ثابتون**.
`AtherToast`: overlay singleton، دخول rise 12px، خروج opacity فقط، Timers حقيقية.
`CollapsingList`: `AnimatedList`، الخروج SizeTransition+fade 200ms (الاستثناء الموثق الوحيد للـ layout).
`SpinningCog`: زاوية متراكمة (لا ترجع للخلف أبدًا). `AnimatedBackChevron`: انعكاس scaleX + خط 2.4→2.2.
`BranchCrossFade`: Stack من AnimatedOpacity مع `IgnorePointer+ExcludeSemantics+TickerMode(false)`
للتبويبات المخفية — نمط صحيح يجب أن يُحتفى به.

## 3. ما هو غائب كليًا (فراغات نظامية)
1. **فيزياء**: لا نوابض، لا سرعة إصبع، لا مقاطعة فيزيائية (كل شيء duration-based).
2. **Haptics**: لا وجود لها في الكود إطلاقًا.
3. **استمرارية مكانية للتاب**: لا مؤشر ينزلق بين الخانات.
4. **رسم المسارات (draw-on)**: PathMetric مستخدم في العلامة التجارية فقط، لا في UI.
5. **morph بين حالتي أيقونة**: eye↔eyeOff وأمثالها تبدّل فوري.

## 4. الانحرافات والتكرارات (مرشحة تنظيف مستقبلية)
1. `AtherSwitch` يستخدم `Curves.easeOut` الخام + يستعير توكن `press` لقلب switch — خارج المفردات.
2. `showAtherSheet` يمرر `transitionAnimationController: null` ⇒ أنيميشن Material الافتراضي
   (~250ms بمنحنى Material) وليس توكنز `sheet` — التوكنز تُستهلك فعليًا في مسار الويزارد فقط.
3. انتقالات المسارات تحت reduce-motion تستبدل الحركة بـ fade لكن **تكمل 220/280ms كاملة**
   — النظام كله ينتهي فورًا إلا هنا.
4. ثلاثة تنفيذات يدوية لـ fade+rise رغم توثيق "لا تكتب ثالثًا": RiseIn، router، wizard switcher.
5. رسّامَا flood منفصلان (CompletionDisc vs OverdueCheck) — نفس الفكرة بمعاملات مختلفة.
6. `SegmentedControl` كود ميت بلا أي حركة. ثلاث مدد مختلفة لنفس إشارة PopIn (200/180/220) بلا توثيق.
7. رفع السحب في المهام يستخدم `Curves.easeOut` خامًا (`tasks_screen.dart:236`) بدل توكن — انحراف رابع خارج المفردات اكتشفته المراجعة.
8. الزجاج مُبوَّب على **المنصة لا على reduce-motion** عمدًا (app_shell.dart:158–166)، والتعتيم رُفع 0.72→0.85 لضمان التباين — قراران يستحقان الظهور هنا لا البقاء ضمنيين.
9. `OverdueMark` لا تماثل مقصودة: العودة للتأخر تعود فورية غير مغروقة (icon_motion.dart:524–529) — يوثَّق ليمنع «إصلاح» مستقبلي.

## 5. أخطار pumpAndSettle
- **حلقتان لا نهائيتان** (تصحيح بعد مراجعة): `CircularProgressIndicator` في `PrimaryButton.busy`، وحلقة busy ثانية في `SettingsRow` (`settings_list.dart:172–181`) تُدرَج مكان الشيفرون أثناء عمليات الحساب/التوقيع.
- **PathMetric ليس حصريًا للعلامة التجارية** (تصحيح): `DashedAddButton` يمشي الـ metrics لرسم شرطاته (`buttons.dart:~252`) — غير المتاح هو *draw-on متحرك* في UI، لا استخدام PathMetric ذاته.
- التأخيرات كلها Intervals (سليم). توست = Timers حقيقية (تضخ يدويًا في الاختبارات).
- التابات المخفية صامتة بـ TickerMode. السيجما ثابتة. كل المراقبات منتهية المدة.
- الاختبار الذي يعتبر "pumpAndSettle يعود أصلًا" تأكيدًا: day_picker_test (توهج العودة يجب أن يبقى غير نابض).
