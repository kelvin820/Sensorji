import 'dart:async';
import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../logic/draw.dart';
import '../../logic/shake.dart';
import '../../logic/shaker_physics.dart';

/// 分鏡 ① 搖籤筒、② 籤棒落出（Flutter 程式動畫，取代原本規劃的 shaker.riv）。
///
/// ①：籤筒（OB02）跟著手機左右傾斜、搖一下就被甩動並往上彈；籤棒尖端從頂蓋的洞口冒出，
///     搖得越多冒得越高，每搖一下跳一下。
/// ②：籤筒前傾，一支籤棒慢慢滑出洞口，離開後在空中翻一圈落定，
///     旁邊以毛筆字由上而下逐字寫出籤號，然後換到 04 籤號畫面。
///
/// 所有座標都在 [_box] 這個固定畫布裡，外面用 FittedBox 等比縮放。
class Shaker extends StatefulWidget {
  const Shaker({
    super.key,
    required this.label,
    required this.progress,
    this.inkColor = Palette.ink,
    this.onLand,
  });

  /// 籤筒上的字（觀音籤／六十甲子）。
  final String label;

  /// 累計搖晃進度 0…1（籤棒冒出的高度）。
  final double progress;

  /// 籤號毛筆字的顏色（冬夜要用淺色）。
  final Color inkColor;

  /// 籤棒落地那一刻（App 震動）。
  final VoidCallback? onLand;

  @override
  State<Shaker> createState() => ShakerState();
}

// ── 畫布與素材量測（像素量自 素材/processed/objects） ────────────────────
const _box = Size(300, 440);

// 籤筒 OB02：776×1068，頂蓋洞口中心 (391, 112)。
const _canH = 300.0;
const _canScale = _canH / 1068;
const _canW = 776 * _canScale;
const _canLeft = (300 - _canW) / 2;
const _canTop = 140.0;
const _hole = Offset(_canLeft + 391 * _canScale, _canTop + 112 * _canScale);
const _pivot = Offset(150, _canTop + _canH / 2); // 擺動中心：籤筒中央

// 籤棒 OB03：233×1600，竿身中心在 x≈97，寬約 80。縮到竿身約洞口寬度的一半，
// 長度也不會在滑出時衝出畫面。
const _stickScale = 0.22;
const _stickW = 233 * _stickScale;
const _stickH = 1600 * _stickScale;
const _stickAnchorX = 97 / 233; // 竿身中線在圖寬的比例

// 籤棒落定的位置（竿底）與籤號那一欄。
const _landAnchor = Offset(112, 428);
const _landScale = 1.0;
const _numberX = 210.0;
const _numberTop = 64.0;
const _numberFont = 44.0;

// ② 的時間軸（0…1）。
const _slideEnd = 0.32; // 籤筒前傾、籤棒慢慢滑出
const _outEnd = 0.52; // 滑出一半，接著脫手飛出
const _slideOut1 = 0.3; // 前傾結束時露出的比例
const _slideOut2 = 0.5; // 脫手時露出的比例
const _landEnd = 0.80; // 翻轉落定
const _writeEnd = 0.95; // 籤號寫完（之後停一下）
const _tiltForward = -0.32;

/// 正常與重搖（擲筊失敗後）的落籤長度。
const kDropDuration = Duration(milliseconds: 3000);
const kDropDurationQuick = Duration(milliseconds: 1500);

class ShakerState extends State<Shaker> with TickerProviderStateMixin {
  final _physics = ShakerPhysics();
  Ticker? _ticker;
  Duration _last = Duration.zero;
  TiltSensor? _tilt;
  late final AnimationController _drop = AnimationController(vsync: this, duration: kDropDuration);
  bool _reduced = false;
  int? _number;
  double _dropStartAngle = 0;
  double _dropStartPeek = 0;
  bool _landed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _ticker?.stop();
      _tilt?.stop();
      return;
    }
    _ticker ??= createTicker(_onTick);
    if (!_ticker!.isActive) {
      _last = Duration.zero;
      _ticker!.start();
    }
    _tilt ??= TiltSensor((v) => _physics.tilt = v)..start();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _physics.step(dt);
    if (_drop.isAnimating) return; // 落籤時由 _drop 驅動重繪
    setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _tilt?.stop();
    _drop.dispose();
    super.dispose();
  }

  /// 一次有效晃動。
  void kick(double intensity) {
    if (_reduced || _number != null) return;
    _physics.kick(intensity);
  }

  /// 落籤：播完 ② 才完成（減少動態效果時立即完成）。
  Future<void> drop(int number, {bool quick = false}) async {
    if (_number != null) return;
    setState(() => _number = number);
    if (_reduced) return;
    _dropStartAngle = _physics.angle;
    _dropStartPeek = _peek;
    _drop.duration = quick ? kDropDurationQuick : kDropDuration;
    _drop.addListener(_checkLand);
    await _drop.forward(from: 0);
  }

  void _checkLand() {
    if (!_landed && _drop.value >= _landEnd) {
      _landed = true;
      widget.onLand?.call();
    }
  }

  /// 洞口外看得到的籤棒長度（未落籤時）。
  double get _peek => (14 + widget.progress.clamp(0.0, 1.0) * 46 - _physics.jiggle).clamp(0.0, 90.0);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _number == null ? '籤筒' : '落出第 $_number 籤',
      child: FittedBox(
        child: SizedBox.fromSize(
          size: _box,
          child: AnimatedBuilder(
            animation: _drop,
            builder: (context, _) => _reduced || _number == null || _drop.value == 0 && !_drop.isAnimating
                ? (_number != null ? _landedStill() : _shaking())
                : _dropping(_drop.value),
          ),
        ),
      ),
    );
  }

  // ── ①：搖籤中 ─────────────────────────────────────────────

  Widget _shaking() => Stack(
        clipBehavior: Clip.none,
        children: [
          _canister(angle: _reduced ? 0 : _physics.angle, lift: _reduced ? 0 : _physics.lift, visible: _peek),
        ],
      );

  /// 籤筒＋洞口冒出的籤棒，一起繞 [_pivot] 轉。
  Widget _canister({required double angle, required double lift, required double visible, double opacity = 1}) {
    return Positioned.fill(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, lift),
          child: Transform.rotate(
            angle: angle,
            origin: _pivot - Offset(_box.width / 2, _box.height / 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _canLeft,
                  top: _canTop,
                  width: _canW,
                  height: _canH,
                  child: Stack(
                    alignment: const Alignment(0, 0.15),
                    children: [
                      Image.asset('assets/objects/OB02.webp', width: _canW, height: _canH),
                      Text(
                        widget.label,
                        style: brush(const TextStyle(
                          fontSize: 30,
                          color: Palette.ink,
                          letterSpacing: 4,
                        )),
                      ),
                    ],
                  ),
                ),
                if (visible > 0)
                  // 只畫洞口以上的部分，看起來就是從洞裡冒出來。
                  Positioned(
                    left: _hole.dx - _stickAnchorX * _stickW,
                    top: _hole.dy - visible,
                    width: _stickW,
                    height: visible,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: _stickH,
                        maxHeight: _stickH,
                        child: Image.asset('assets/objects/OB03.webp', width: _stickW, height: _stickH),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ②：落籤 ───────────────────────────────────────────────

  Widget _dropping(double t) {
    double seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

    // 籤筒角度：前傾 → 停住 → 回正
    final aSlide = Curves.easeInOutCubic.transform(seg(0, _slideEnd));
    final aOut = Curves.easeInQuad.transform(seg(_slideEnd, _outEnd));
    final aBack = Curves.easeOutCubic.transform(seg(_outEnd, _landEnd));
    final outAngle = _tiltForward - 0.06;
    final canAngle = t < _slideEnd
        ? _dropStartAngle + (_tiltForward - _dropStartAngle) * aSlide
        : t < _outEnd
            ? _tiltForward - 0.06 * aOut
            : outAngle * (1 - aBack);

    final children = <Widget>[];
    if (t < _outEnd) {
      // 籤棒慢慢滑出洞口
      final visible = t < _slideEnd
          ? _dropStartPeek + (_stickH * _slideOut1 - _dropStartPeek) * aSlide
          : _stickH * (_slideOut1 + (_slideOut2 - _slideOut1) * aOut);
      children.add(_canister(angle: canAngle, lift: 0, visible: visible));
    } else {
      // 籤棒脫手那一刻竿底還在筒內：竿底在洞口下方 (1 − 露出比例) 支長，繞擺動中心轉 outAngle。
      // 籤棒畫在籤筒後面，筒內那一段被筒身擋住，看起來就是從洞口抽出來的。
      final start = _rotate(_hole + Offset(0, _stickH * (1 - _slideOut2)), _pivot, outAngle);
      final u = seg(_outEnd, _landEnd);
      final ux = Curves.easeOutCubic.transform(u);
      final uy = Curves.easeOutBack.transform(u); // 落定時輕輕回彈
      final anchor = Offset(
        start.dx + (_landAnchor.dx - start.dx) * ux,
        start.dy + (_landAnchor.dy - start.dy) * uy - 60 * sin(pi * u), // 拋物線
      );
      children.add(_freeStick(
        anchor: anchor,
        angle: outAngle * (1 - ux),
        flip: 2 * pi * Curves.easeInOut.transform(u), // 空中翻一圈
        scale: 1 + (_landScale - 1) * ux,
      ));
      // 籤筒回正、往下沉並淡出，讓位給籤棒
      // 先維持不透明（籤棒在筒後面，看起來是從洞口抽出），等籤棒翻起來再快速淡出。
      final fade = Curves.easeIn.transform(seg(_outEnd + 0.06, _outEnd + 0.16));
      children.add(_canister(angle: canAngle, lift: 50 * aBack, visible: 0, opacity: 1 - fade));
      children.addAll(_numberColumn(seg(_landEnd, _writeEnd)));
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// 減少動態效果：籤棒直接立在旁邊、籤號寫好。
  Widget _landedStill() => Stack(
        clipBehavior: Clip.none,
        children: [
          _freeStick(anchor: _landAnchor, angle: 0, flip: 0, scale: _landScale),
          ..._numberColumn(1),
        ],
      );

  /// 以竿底中心為錨點畫一支籤棒。
  Widget _freeStick({required Offset anchor, required double angle, required double flip, required double scale}) {
    return Positioned(
      left: anchor.dx - _stickAnchorX * _stickW,
      top: anchor.dy - _stickH,
      width: _stickW,
      height: _stickH,
      child: Transform(
        alignment: const FractionalOffset(_stickAnchorX, 1),
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateZ(angle)
          ..rotateY(flip)
          ..scaleByDouble(scale, scale, 1, 1),
        child: Image.asset('assets/objects/OB03.webp', width: _stickW, height: _stickH),
      ),
    );
  }

  /// 「第七十七籤」直排，一字一字由上往下寫出。[p] 0…1 是整欄的進度。
  List<Widget> _numberColumn(double p) {
    final chars = '第${chineseNumber(_number!)}籤'.characters.toList();
    final style = brush(TextStyle(fontSize: _numberFont, height: 1.12, color: widget.inkColor));
    return [
      for (final (i, ch) in chars.indexed)
        Positioned(
          left: _numberX - _numberFont / 2,
          top: _numberTop + i * _numberFont * 1.12,
          width: _numberFont,
          child: Builder(builder: (context) {
            final each = ((p * chars.length) - i).clamp(0.0, 1.0);
            if (each == 0) return const SizedBox.shrink();
            // 由上往下擦出，像毛筆一筆一筆寫下去
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: Curves.easeOut.transform(each),
                child: Text(ch, textAlign: TextAlign.center, style: style),
              ),
            );
          }),
        ),
    ];
  }

  static Offset _rotate(Offset p, Offset c, double a) {
    final d = p - c;
    return c + Offset(d.dx * cos(a) - d.dy * sin(a), d.dx * sin(a) + d.dy * cos(a));
  }
}
