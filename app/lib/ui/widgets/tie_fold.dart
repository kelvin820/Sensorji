import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import 'slip_reader.dart' show kSlipAspect;

/// 分鏡 ⑥ 凶籤結籤（Flutter 程式動畫，取代原本規劃的 tie.riv）。
///
/// 1. 折：使用者把手指往左拖，抽到的那張籤紙像屏風一樣折成細條（切成 [_strips] 條，
///    相鄰兩條往相反方向轉，越折越窄、摺痕越深）。每折到一段觸發 [onFoldStep]。
///    放開時折超過 60% 就自己折完，不到就攤回去；也可以呼叫 [TieFoldState.foldAll]（「幫我折好」）。
/// 2. 結：細條轉成橫的、移到籤架上，換成結好的籤（OB07），繩結收緊時觸發 [onKnot]，
///    最後畫面微暗，觸發 [onDone]。
/// [tied] 為 true（已結過）或減少動態效果時直接顯示結好的籤。
class TieFold extends StatefulWidget {
  const TieFold({
    super.key,
    required this.slipImage,
    this.tied = false,
    this.onFoldStep,
    this.onKnot,
    this.onDone,
  });

  final String slipImage;
  final bool tied;
  final ValueChanged<int>? onFoldStep;
  final VoidCallback? onKnot;
  final VoidCallback? onDone;

  @override
  State<TieFold> createState() => TieFoldState();
}

const _strips = 6;

/// 折到底時每條轉幾度（cos 80° ≈ 0.17，整張剩約六分之一寬）。
const _maxFoldAngle = 80 * pi / 180;

/// 折的段數（每段觸發一次 onFoldStep）。
const kFoldSteps = 5;

// 結的時間軸（0…1，共 kTieDuration）
const _turnEnd = 0.38; // 轉成橫的、移到籤架
const _swapEnd = 0.58; // 換成結好的籤
const _knotAt = 0.62; // 繩結收緊
const _knotEnd = 0.78;
const kTieDuration = Duration(milliseconds: 2200);

/// 結好的籤 OB07：1600×779。
const _tiedAspect = 779 / 1600;

class TieFoldState extends State<TieFold> with TickerProviderStateMixin {
  /// 折的進度 0…1（跟著手指；放開時用動畫補完或攤回）。
  late final AnimationController _fold = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final AnimationController _tie = AnimationController(vsync: this, duration: kTieDuration);
  int _lastStep = 0;
  bool _knotted = false;
  bool _reduced = false;

  double get fold => _fold.value;
  bool get tying => _tie.isAnimating || _tie.value > 0;
  bool get done => _tie.value >= 1;

  @override
  void initState() {
    super.initState();
    // 已結過：先設好最後狀態再掛監聽，免得又觸發繩結（再震一次、再存一次）
    if (widget.tied) {
      _fold.value = 1;
      _tie.value = 1;
      _knotted = true;
      _lastStep = kFoldSteps;
    }
    _fold.addListener(_checkStep);
    _tie.addListener(_checkKnot);
    _tie.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _fold.dispose();
    _tie.dispose();
    super.dispose();
  }

  void _checkStep() {
    // 每折過一段通知一次；攤回去再折會再通知
    final step = (_fold.value * kFoldSteps + 1e-6).floor();
    for (var s = _lastStep + 1; s <= step; s++) {
      widget.onFoldStep?.call(s);
    }
    _lastStep = step;
  }

  void _checkKnot() {
    if (!_knotted && _tie.value >= _knotAt) {
      _knotted = true;
      widget.onKnot?.call();
    }
  }

  /// 「幫我折好」：自動折完並結上。減少動態效果時直接完成。
  Future<void> foldAll() async {
    if (tying) return;
    if (_reduced) {
      _fold.value = 1;
      _tie.value = 1; // 不經過動畫：直接觸發繩結與完成
      _checkKnot();
      widget.onDone?.call();
      return;
    }
    await _fold.animateTo(1, duration: Duration(milliseconds: (1400 * (1 - _fold.value)).round() + 1), curve: Curves.easeInOut);
    await _tie.forward();
  }

  void _drag(DragUpdateDetails d, double width) {
    if (tying) return;
    // 往左拖＝折起來；往右拖攤回去
    _fold.value = (_fold.value - d.delta.dx / (width * 0.75)).clamp(0.0, 1.0);
  }

  Future<void> _release() async {
    if (tying) return;
    if (_fold.value >= 0.6) {
      await _fold.animateTo(1, curve: Curves.easeOut);
      await _tie.forward();
    } else {
      await _fold.animateTo(0, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        // 攤開的籤紙：高度佔舞台 82%，寬度不超過舞台 80%
        var h = size.height * 0.82;
        var w = h * kSlipAspect;
        if (w > size.width * 0.8) {
          w = size.width * 0.8;
          h = w / kSlipAspect;
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _drag(d, w),
          onHorizontalDragEnd: (_) => _release(),
          onHorizontalDragCancel: _release,
          child: AnimatedBuilder(
            animation: Listenable.merge([_fold, _tie]),
            builder: (context, _) => Semantics(
              label: done ? '籤已繫在籤架上' : '籤紙，已折 ${(_fold.value * 100).round()}%',
              child: Stack(
                clipBehavior: Clip.none,
                children: _layers(size, w, h),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _layers(Size stage, double w, double h) {
    final t = _tie.value;
    double seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
    final turn = Curves.easeInOutCubic.transform(seg(0, _turnEnd));
    final swap = Curves.easeInOut.transform(seg(_turnEnd, _swapEnd));
    final knot = seg(_knotAt, _knotEnd);
    final dim = Curves.easeIn.transform(seg(_knotEnd, 1));

    // 結好的籤在籤架上的位置：舞台寬 92%，垂直置中略偏上
    final tiedW = stage.width * 0.92;
    final tiedH = tiedW * _tiedAspect;
    final tiedCenter = Offset(stage.width / 2, stage.height * 0.42);
    // OB07 裡細條的長度約佔圖寬 55%：細條轉橫後縮到這個長度
    final stripTargetScale = tiedW * 0.55 / h;
    final center = Offset.lerp(Offset(stage.width / 2, stage.height / 2), tiedCenter, turn)!;

    final layers = <Widget>[];

    // 1. 折起來的籤紙（結的前半段轉成橫的並移到籤架）
    if (swap < 1) {
      layers.add(Positioned(
        left: center.dx - w / 2,
        top: center.dy - h / 2,
        width: w,
        height: h,
        child: Opacity(
          opacity: 1 - swap,
          child: Transform.rotate(
            angle: -pi / 2 * turn,
            child: Transform.scale(scale: 1 + (stripTargetScale - 1) * turn, child: _accordion(w, h, _fold.value)),
          ),
        ),
      ));
    }

    // 2. 結好的籤（OB07），繩結收緊時輕輕一縮再彈回
    if (swap > 0) {
      final pulse = knot > 0 && knot < 1 ? sin(pi * knot) : 0.0;
      layers.add(Positioned(
        left: tiedCenter.dx - tiedW / 2,
        top: tiedCenter.dy - tiedH / 2,
        width: tiedW,
        height: tiedH,
        child: Opacity(
          opacity: swap,
          child: Transform.scale(
            scale: (0.96 + 0.04 * swap) * (1 - 0.035 * pulse),
            child: Image.asset('assets/objects/OB07.webp', fit: BoxFit.contain),
          ),
        ),
      ));
    }

    // 3. 結好後四周漸暗、只留籤架上的籤（靜下來）。限在舞台內，不蓋到上下的文字與按鈕。
    if (dim > 0) {
      layers.insert(
        0,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, tiedCenter.dy / stage.height * 2 - 1),
                  radius: 0.9,
                  colors: [Palette.ink.withValues(alpha: 0), Palette.ink.withValues(alpha: 0.28 * dim)],
                  stops: const [0.35, 1],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return layers;
  }

  /// 屏風式折法：整張籤紙切成 [_strips] 條，相鄰的往相反方向轉 [f]×80°，緊靠在一起置中。
  Widget _accordion(double w, double h, double f) {
    final angle = _maxFoldAngle * Curves.easeInOut.transform(f);
    final stripW = w / _strips;
    final projected = stripW * cos(angle);
    final total = projected * _strips;
    final left0 = (w - total) / 2;
    final image = Image.asset(widget.slipImage, width: w, height: h, fit: BoxFit.fill);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < _strips; i++)
          Positioned(
            left: left0 + i * projected + (projected - stripW) / 2,
            top: 0,
            width: stripW,
            height: h,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0009)
                ..rotateY(i.isEven ? angle : -angle),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: OverflowBox(
                      maxWidth: w,
                      alignment: Alignment(-1 + 2 * i / (_strips - 1), 0),
                      child: image,
                    ),
                  ),
                  // 摺痕明暗：朝內的那面暗、朝外的亮
                  ColoredBox(
                    color: i.isEven
                        ? Colors.white.withValues(alpha: 0.10 * sin(angle))
                        : Palette.ink.withValues(alpha: 0.28 * sin(angle)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
