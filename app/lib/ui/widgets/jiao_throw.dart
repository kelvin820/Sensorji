import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../logic/draw.dart';

/// 擲筊動畫（六十甲子籤，取代原本規劃的 jiaobei.riv）。
///
/// 兩片筊杯從下方拋起，在空中翻滾（繞橫軸翻：看到的面在平面 OB05_flat 與凸面 OB05_round
/// 之間切換，側面時壓扁）、自轉，落地後彈兩下、晃一晃停住，停定的面由 [result] 決定。
/// 每次碰地觸發 [onLand]（App 震動、播落地聲），停定觸發 [onDone]。
/// [throwId] 每加一就擲一次；[result] 為 null 時顯示還拿在手上的一對（OB05）。
/// 減少動態效果時直接顯示停定結果。
class JiaoThrow extends StatefulWidget {
  const JiaoThrow({super.key, required this.result, required this.throwId, this.onLand, this.onDone});

  final JiaoResult? result;
  final int throwId;
  final ValueChanged<int>? onLand;
  final VoidCallback? onDone;

  @override
  State<JiaoThrow> createState() => _JiaoThrowState();
}

const kJiaoThrowDuration = Duration(milliseconds: 1900);

// 時間軸（0…1）
const _fall = 0.58; // 第一次碰地
const _bounce1 = 0.74; // 第二次碰地
const _bounce2 = 0.86; // 第三次碰地，之後晃一晃停住

/// 筊杯一片的寬度佔舞台寬。
const _blockW = 0.36;

class _Block {
  _Block({required this.flatUp, required this.restX, required this.restAngle, required this.halfTurns, required this.spinTurns});

  /// 停定時平面朝上（OB05_flat）或凸面朝上（OB05_round）。
  final bool flatUp;

  /// 停定的位置（舞台寬的比例，中心）與角度。
  final double restX;
  final double restAngle;

  /// 空中繞橫軸翻幾個半圈（偶數＝起手的面朝上；起手是平面朝上）。
  final int halfTurns;

  /// 空中自轉幾圈（平面內）。
  final double spinTurns;
}

class _JiaoThrowState extends State<JiaoThrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: kJiaoThrowDuration);
  final _random = Random();
  List<_Block>? _blocks;
  int _landed = 0;

  @override
  void initState() {
    super.initState();
    // 一開始就有結果（例如重建畫面）：先設好停定狀態再掛監聽，不重播也不重發事件
    if (widget.result != null) {
      _prepare(widget.result!, settled: true);
      _landed = 3;
    }
    _c.addListener(_checkLand);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void didUpdateWidget(JiaoThrow old) {
    super.didUpdateWidget(old);
    if (widget.throwId != old.throwId && widget.result != null) {
      _prepare(widget.result!);
      if (MediaQuery.disableAnimationsOf(context)) {
        // 直接停定。等這一幀建完再設（onDone 會讓上層 setState，不能在 build 期間做），
        // 先歸零再設到底，確保每一次都會發出 completed。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _c.value = 0;
          _c.value = 1;
        });
      } else {
        _c.forward(from: 0);
      }
    } else if (widget.result == null) {
      _blocks = null;
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _prepare(JiaoResult r, {bool settled = false}) {
    // 聖杯：一平一凸，哪一片是平的隨機
    final (a, b) = switch (r) {
      JiaoResult.holy => _random.nextBool() ? (true, false) : (false, true),
      JiaoResult.laughing => (true, true),
      JiaoResult.negative => (false, false),
    };
    int turns(bool flatUp) => 2 * (2 + _random.nextInt(2)) + (flatUp ? 0 : 1);
    _blocks = [
      _Block(
        flatUp: a,
        restX: 0.28 + _random.nextDouble() * 0.04,
        restAngle: -0.25 + _random.nextDouble() * 0.2,
        halfTurns: turns(a),
        spinTurns: 0.6 + _random.nextDouble() * 0.5,
      ),
      _Block(
        flatUp: b,
        restX: 0.70 + _random.nextDouble() * 0.04,
        restAngle: 0.1 + _random.nextDouble() * 0.25,
        halfTurns: turns(b),
        spinTurns: -(0.5 + _random.nextDouble() * 0.5),
      ),
    ];
    _landed = 0;
    if (settled) _c.value = 1;
  }

  void _checkLand() {
    final hits = [_fall, _bounce1, _bounce2].where((t) => _c.value >= t).length;
    while (_landed < hits) {
      _landed++;
      widget.onLand?.call(_landed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      final blocks = _blocks;
      if (blocks == null) {
        return Center(
          child: Semantics(
            label: '一對筊杯',
            child: Image.asset('assets/objects/OB05.webp', width: size.width * 0.62),
          ),
        );
      }
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Semantics(
          label: _c.value >= 1 ? '筊杯停定：${widget.result!.label}' : '擲筊中',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (i, b) in blocks.indexed) ..._block(size, b, mirror: i == 1),
            ],
          ),
        ),
      );
    });
  }

  List<Widget> _block(Size stage, _Block b, {required bool mirror}) {
    final t = _c.value;
    double seg(double a, double z) => ((t - a) / (z - a)).clamp(0.0, 1.0);
    final w = stage.width * _blockW;
    final h = w * 0.68;
    final ground = stage.height * 0.62; // 筊杯停定時中心的高度

    // 高度：拋物線飛起再落地，然後兩次越來越小的彈跳
    double y;
    if (t < _fall) {
      final u = seg(0, _fall);
      y = stage.height * 1.05 * (1 - u) + ground * u - stage.height * 0.62 * sin(pi * u); // 最高點約在舞台 20% 高，不飛出畫面
    } else if (t < _bounce1) {
      y = ground - stage.height * 0.07 * sin(pi * seg(_fall, _bounce1));
    } else if (t < _bounce2) {
      y = ground - stage.height * 0.025 * sin(pi * seg(_bounce1, _bounce2));
    } else {
      y = ground;
    }
    final x = stage.width * (0.5 + (b.restX - 0.5) * Curves.easeOut.transform(seg(0, _fall)));

    // 繞橫軸翻：落地前翻完；彈跳時只微微掀起
    final flipU = Curves.easeOut.transform(seg(0, _fall));
    var flip = pi * b.halfTurns * flipU;
    if (t >= _fall && t < _bounce1) flip += 0.35 * sin(pi * seg(_fall, _bounce1));
    final squash = cos(flip);
    final flatShowing = squash >= 0; // 起手平面朝上
    // 平面內自轉：落地後晃一晃停在 restAngle
    final settle = seg(_bounce2, 1);
    final wobble = 0.12 * sin(3 * pi * settle) * (1 - settle);
    final angle = 2 * pi * b.spinTurns * (1 - Curves.easeOut.transform(seg(0, _bounce1))) + b.restAngle + wobble;

    final shadowScale = (1 - (ground - y) / stage.height * 1.4).clamp(0.25, 1.0);

    return [
      // 地上的影子：筊杯越高影子越小越淡
      Positioned(
        left: x - w * 0.45 * shadowScale,
        top: ground + h * 0.32 - h * 0.08,
        width: w * 0.9 * shadowScale,
        height: h * 0.16,
        child: Opacity(
          opacity: (t < 0.08 ? seg(0, 0.08) : 1) * (0.25 + 0.35 * shadowScale),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x66000000),
              borderRadius: BorderRadius.all(Radius.elliptical(100, 30)),
            ),
          ),
        ),
      ),
      Positioned(
        left: x - w / 2,
        top: y - h / 2,
        width: w,
        height: h,
        child: Transform.rotate(
          angle: angle,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(mirror ? -1 : 1, max(0.14, squash.abs()), 1),
            child: Image.asset(
              flatShowing ? 'assets/objects/OB05_flat.webp' : 'assets/objects/OB05_round.webp',
              fit: BoxFit.contain,
              color: squash.abs() < 0.35 ? Palette.vermilionDeep.withValues(alpha: 0.25) : null,
              colorBlendMode: BlendMode.srcATop, // 側面時暗一點，像看到邊
            ),
          ),
        ),
      ),
    ];
  }
}
