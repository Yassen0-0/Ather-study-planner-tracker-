# أمثلة كود مقترحة — جاهزة للنسخ عند الاعتماد

> **لماذا markdown وليست ملفات .dart؟** لأن `flutter analyze` يفحص كل Dart في المستودع،
> وكود مقترح خارج `lib/` سيكسر التحليل وCI. هذه نماذج مرجعية — عند اعتماد أي منها تُكتب
> داخل `lib/core/` بمسار عمل المشروع الرسمي (اختبارات + PROJECT.md work-log).
> الأسلوب يتبع عادات المستودع: doc comment يقول *ليه* مش *إيه*، وتوكنز لا أرقام متفرقة.

## 1) طبقة النوابض `Springs` — تُوضع بجانب `AppMotion`

```dart
import 'package:flutter/physics.dart';

/// The app's spring vocabulary. Five members, no sixth: if a new motion does
/// not fit one of these, it is a design conversation before it is a constant.
/// mass is always 1 — sidesteps Flutter 3.32's underdamped-formula change.
abstract final class Springs {
  /// Press-down and any motion that must never overshoot. ζ = 1.
  static final crisp = SpringDescription.withDurationAndBounce(
    duration: Duration(milliseconds: 160), bounce: 0);

  /// The workhorse: tab selection, icon pops, press release. One clean bounce ≤5%.
  static final select = SpringDescription.withDurationAndBounce(
    duration: Duration(milliseconds: 300), bounce: 0.30);

  /// Panels settling where they land. Confident, near-critical.
  static final settle =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 220, ratio: 0.81);

  /// The rare celebration register. Never for chrome.
  static final celebrate = SpringDescription.withDurationAndBounce(
    duration: Duration(milliseconds: 450), bounce: 0.55);

  /// Gesture releases: feed the finger's velocity, physics does the rest.
  static SpringSimulation fling({
    required double from,
    required double to,
    required double velocity,
  }) => SpringSimulation(settle, from, to, velocity);
}
```

## 2) قائد النابض القابل للمقاطعة

```dart
mixin SpringDriver<T extends StatefulWidget> on State<T>
    implements TickerProviderStateMixin {
  late final _driver = AnimationController.unbounded(vsync: this);
  double get value => _driver.value;

  /// Re-targeting mid-flight is the point: calling again simply re-launches
  /// the simulation from wherever we are now, current velocity included.
  void driveTo(double target, {SpringDescription? spring, double velocity = 0}) {
    _driver.animateWith(
      SpringSimulation(spring ?? Springs.select, _driver.value, target, velocity),
    );
  }

  @override
  void dispose() {
    _driver.dispose();
    super.dispose();
  }
}
```

## 3) Pressable v2 — جوهر الضغط الفيزيائي

```dart
class _PressableState extends State<Pressable> with SpringDriver {
  double get _target => _pressed ? AppMotion.pressScale : 1.0;

  void _set(bool down) {
    setState(() => _pressed = down);
    // Down is a decision the user made; up carries their finger's energy out.
    driveTo(_target,
        spring: down ? Springs.crisp : Springs.select);
    if (down && context.hapticsEnabled) HapticFeedback.lightImpact();
  }

  // build: ScaleTransition(scale: _driver) بدل AnimatedScale الحالي
}
```

## 4) أيقونة التاب — إضافة الارتداد فوق M-20 دون لمسه

```dart
class _TabGlyphState extends State<TabGlyph> with SpringDriver {
  double _last = 0;

  @override
  void didUpdateWidget(TabGlyph old) {
    super.didUpdateWidget(old);
    final target = widget.selected ? 1.0 : 0.0;
    if (target != _last && widget.selected) {
      // Selection pop: dip then spring past rest by ~4.6% (ζ≈0.70). Interruptible.
      _driver.value = 0;
      driveTo(1.0, spring: Springs.select);
      if (context.hapticsEnabled) HapticFeedback.selectionClick();
    }
    _last = target;
  }

  // build: التوين الحالي للوزن/اللون كما هو، والأيقونة داخل
  // ScaleTransition(scale: Tween(0.9, 1).chain(CurvedAnimation(...)))
  //   → عملياً: Transform.scale(scale: 0.9 + 0.1 * value)
}
```

## 5) مؤشر التاب المنزلق (هيكل)

```dart
// داخل صف التابات: Stack واحد فوق الصف، Positioned بعرض ثابت 16px.
// الموضع = index × slotWidth + (slotWidth - indicatorWidth) / 2
// slotWidth من LayoutBuilder (الخانات Expanded أصلاً) — لا حاجة ل GlobalKey.
class _Indicator extends StatelessWidget {
  final AnimationController driver; // unbounded، موضع بالبكسل المنطقي
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: driver,
    builder: (_, __) => Positioned(
      left: 0, // الاتجاه عبر Directionality: نحسب offset منطقيًا ونقلبه هنا
      child: Transform.translate(
        offset: Offset(driver.value, 0),
        child: Container(width: 16, height: 3,
          decoration: BoxDecoration(
            color: context.colors.accent,
            borderRadius: BorderRadius.circular(2))),
      ),
    ),
  );
}
// الانتقال: driver.animateWith(SpringSimulation(Springs.settle, oldX, newX, 0));
// تحت reduce-motion: driver.value = newX فوراً.
```

## 6) مساعد draw-on للمسارات

```dart
/// Draws a stroke as if being written. Metrics are computed once per path,
/// never inside paint. Used by the brand ring and the trajectory line only —
/// draw-on everywhere would be noise.
class DrawOnPainter extends CustomPainter {
  DrawOnPainter({required this.path, required this.t, required this.paintStroke});
  final Path path;
  final double t; // 0..1
  final Paint paintStroke;

  late final metrics = path.computeMetrics().toList();

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) { canvas.drawPath(path, paintStroke); return; }
    double drawn = metrics.fold(0.0, (s, m) => s + m.length) * t.clamp(0.0, 1.0);
    final partial = Path();
    for (final m in metrics) {
      final take = math.min(drawn, m.length);
      partial.addPath(m.extractPath(0, take), Offset.zero);
      drawn -= take;
      if (drawn <= 0) break;
    }
    canvas.drawPath(partial, paintStroke);
  }

  @override
  bool shouldRepaint(DrawOnPainter old) =>
      old.t != t || !identical(old.path, path);
}
```

## 7) نمو عمود Analytics (استثناء موثق)

```dart
class _GrowingBar extends StatelessWidget {
  final double fraction; final int index;
  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),   // أول رسم ينمو؛ تغيّر البيانات يعاد تصويبه
      duration: reduced ? Duration.zero
        : AppMotion.value + Duration(milliseconds: 30 * math.min(index, 4)),
      curve: Interval(0, 1, curve: Curves.easeOutCubic),
      child: const ColoredBox(color: AppColors.accentSoft),
      builder: (_, t, child) => FractionallySizedBox(
        heightFactor: t, alignment: AlignmentDirectional.bottomStart, child: child),
    );
  }
}
```

## 8) هيكل سحب day-picker الحي

```dart
void onDragUpdate(DragUpdateDetails d) {
  setState(() => _dragPx += d.delta.dx * _directionSign);
}
double get _visualDx {
  final maxPull = cellWidth * 0.35;
  final x = _dragPx.clamp(-maxPull / 0.35, maxPull / 0.35);
  return x.sign * maxPull * _rubber(x.abs() / maxPull); // rubber(u)=1-(1-u)^2
}
bool _passesCommit(double velocityPerMs) =>
    _dragPx.abs() > commitThresholdPx || velocityPerMs.abs() > 0.11;

void onDragEnd(DragEndDetails d) {
  final v = d.velocity.pixelsPerSecond.dx / 1000; // px→logical/ms
  final committed = _passesCommit(v);
  if (committed && context.hapticsEnabled) HapticFeedback.lightImpact(); // العتبة لا الالتزام
  widget.onDayShift(committed ? _dragPx.sign.round() : 0);
  // العودة دائماً للمركز بنابض يستقبل سرعة الإصبع:
  _rowDrive.driveTo(0, spring: Springs.settle,
      velocity: -_dragPx / 100 /* وحدات/ثانية تقريبية */);
  setState(() => _dragPx = 0);
}
// build: Transform.translate(offset: Offset(_visualDx + _rowDriver.value, 0))
```

## 9) مساعد Haptics بمفتاح واحد

```dart
/// Four touches total. Light for ~90% of interactions; heavy is reserved for
/// destructive commits. Gated by the user's vibration preference, not by
/// reduce-motion — haptics are not visual motion.
extension Haptics on BuildContext {
  static const _key = 'haptics_enabled';
  bool get hapticsEnabled => /* SharedPreferences read through provider */;
  void tapHaptic() => _ifEnabled(() => HapticFeedback.lightImpact());
  void selectHaptic() => _ifEnabled(() => HapticFeedback.selectionClick());
  void successHaptic() => _ifEnabled(() => HapticFeedback.mediumImpact());
  void destructiveHaptic() => _ifEnabled(() => HapticFeedback.heavyImpact());
}
```

## 10) مزامنة الخطوة 4 (نواة الفكرة)

```dart
// MasteryBar تضيف بارامتراً واحداً:
MasteryBar(fraction: result, animateOnEnter: true)
// تنفيذه الداخلي: بدل Tween(begin: fraction, end: fraction)
//   ⇒ Tween(begin: animateOnEnter ? 0 : fraction, end: fraction)
// فيتشار الرقم والبار نفس الـ 600ms ونفس valueCurve من لحظة الظهور.
```
