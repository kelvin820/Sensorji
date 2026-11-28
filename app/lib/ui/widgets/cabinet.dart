import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../logic/draw.dart';
import '../../logic/sounds.dart';

/// 分鏡 ③ 百籤櫃（Flutter 程式動畫，取代原本規劃的 Rive）。
///
/// 淺草寺：整面 10×10 籤櫃（OB04，1 號在左上、逐列往右排）→ 鏡頭推到抽中的那一格、格子發光 →
/// 換成近看的抽屜面（OB04_drawer_front；不放大 OB04，避免糊）→ 抽屜發光、籤號逐字寫上 →
/// 抽屜拉開（OB04_drawer_out），籤號移到下方的紙籤牌。
/// 六十甲子沒有百籤櫃，且要先擲筊確認：只有抽屜面發光、寫上籤號，不拉開。
/// 減少動態效果時直接顯示最後一格。
class DrawerCabinet extends StatefulWidget {
  const DrawerCabinet({super.key, required this.number, required this.deck});

  final int number;
  final Deck deck;

  @override
  State<DrawerCabinet> createState() => _DrawerCabinetState();
}

// ── 時間軸（毫秒） ───────────────────────────────────────────
const _wallIn = (0, 400); // 籤櫃淡入
const _push = (400, 2000); // 鏡頭推近
const _cellGlow = (900, 1900); // 格子發光
const _toFront = (1700, 2200); // 換成抽屜面
const _write = (2200, 3200); // 寫籤號
const _open = (3600, 4600); // 拉開抽屜
const kCabinetDuration = Duration(milliseconds: 4800);

// 六十甲子：只有抽屜面
const _frontOnlyIn = (0, 500);
const _frontOnlyWrite = (500, 1500);
const kFrontOnlyDuration = Duration(milliseconds: 1700);

/// 推近時格子放大幾倍（格子寬 ≈ 舞台寬的 70%），接著換成抽屜面。
const _pushScale = 7.0;

/// 舞台最寬多少（Web 寬螢幕不要大到喧賓奪主）。
const kCabinetMaxWidth = 340.0;

const _glow = Color(0xFFE3C68E);

/// 抽屜拉開圖 OB04_drawer_out 1142×897；抽屜內部中心約 (720, 470)。
const _outAspect = 897 / 1142;
const _outInside = Offset(720 / 1142, 470 / 897);

class _DrawerCabinetState extends State<DrawerCabinet> with TickerProviderStateMixin {
  late final bool _wall = widget.deck == Deck.sensoji;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _wall ? kCabinetDuration : kFrontOnlyDuration,
  );
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  bool? _reduced;
  bool _drawerSound = false;

  @override
  void initState() {
    super.initState();
    // 抽屜開始拉開：木頭摩擦聲（只在播動畫時）
    _c.addListener(() {
      if (_wall && !_drawerSound && _c.isAnimating && _c.value * kCabinetDuration.inMilliseconds >= _open.$1) {
        _drawerSound = true;
        Sounds.play(Sfx.drawer);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    final first = _reduced == null;
    _reduced = reduced;
    if (reduced) {
      _c.value = 1;
      _breath.stop();
    } else {
      first ? _c.forward() : _c.value = 1;
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _breath.dispose();
    super.dispose();
  }

  /// 目前時間（毫秒）落在 [r] 的比例 0…1。
  double _seg((int, int) r) {
    final ms = _c.value * (_c.duration!.inMilliseconds);
    return ((ms - r.$1) / (r.$2 - r.$1)).clamp(0.0, 1.0);
  }

  String get _label => '第${chineseNumber(widget.number)}籤';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '籤櫃：$_label',
      child: LayoutBuilder(
        builder: (context, box) {
          final w = min(box.maxWidth, kCabinetMaxWidth);
          return Center(
            child: SizedBox(
              width: w,
              height: w,
              child: AnimatedBuilder(
                animation: Listenable.merge([_c, _breath]),
                builder: (context, _) => _wall ? _sensoji(w) : _frontOnly(w),
              ),
            ),
          );
        },
      ),
    );
  }

  double get _breathing => (_reduced ?? false) ? 0.5 : Curves.easeInOut.transform(_breath.value);

  // ── 淺草寺：籤櫃 → 抽屜面 → 拉開 ─────────────────────────────

  Widget _sensoji(double w) {
    final push = Curves.easeInOutCubic.transform(_seg(_push));
    final toFront = Curves.easeInOut.transform(_seg(_toFront));
    final open = Curves.easeInOutCubic.transform(_seg(_open));
    // 錯開淡出淡入，避免兩個抽屜各半透明疊在一起
    final frontOut = Curves.easeIn.transform((open / 0.55).clamp(0.0, 1.0));
    final outIn = Curves.easeOut.transform(((open - 0.25) / 0.75).clamp(0.0, 1.0));
    final children = <Widget>[];

    // 1. 整面籤櫃，鏡頭推到抽中的那一格
    final wallOpacity = _seg(_wallIn) * (1 - toFront);
    if (wallOpacity > 0) {
      final i = widget.number - 1;
      final cell = Rect.fromLTWH((i % 10) * w / 10, (i ~/ 10) * w / 10, w / 10, w / 10);
      final k = 1 + (_pushScale - 1) * push;
      final focus = Offset.lerp(Offset(w / 2, w / 2), cell.center, push)!;
      final m = Matrix4.identity()
        ..translateByDouble(w / 2, w / 2, 0, 1)
        ..scaleByDouble(k, k, 1, 1)
        ..translateByDouble(-focus.dx, -focus.dy, 0, 1);
      final glow = sin(pi * _seg(_cellGlow)).clamp(0.0, 1.0) * 0.6 + 0.4 * _seg(_cellGlow);
      children.add(Positioned.fill(
        child: Opacity(
          opacity: wallOpacity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Transform(
              transform: m,
              child: Stack(
                children: [
                  Image.asset('assets/objects/OB04.webp', width: w, height: w, fit: BoxFit.fill),
                  // 抽中的那一格發光（鏡頭推近時越來越亮）
                  Positioned.fromRect(
                    rect: cell,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: _glow.withValues(alpha: glow), width: 0.6),
                        boxShadow: [
                          BoxShadow(color: _glow.withValues(alpha: 0.7 * glow), blurRadius: 3, spreadRadius: 0.5),
                        ],
                        color: _glow.withValues(alpha: 0.25 * glow),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    // 2. 近看的抽屜面：發光、寫上籤號；拉開時淡出
    final frontOpacity = toFront * (1 - frontOut);
    final front = _frontRect(w);
    if (frontOpacity > 0) {
      // 從推近的格子大小（≈0.7 寬）接到抽屜面（0.8 寬），拉開時略縮
      final scale = (0.7 / 0.8 + (1 - 0.7 / 0.8) * toFront) * (1 - 0.06 * open);
      children.add(Positioned.fromRect(
        rect: front,
        child: Opacity(
          opacity: frontOpacity,
          child: Transform.scale(scale: scale, child: _drawerFront(front.width, glow: toFront)),
        ),
      ));
    }

    // 3. 拉開的抽屜，抽屜裡透出暖光（分鏡 ④ 籤紙從這裡出來）
    if (outIn > 0) {
      final out = _outRect(w);
      children.add(Positioned.fromRect(
        rect: out,
        child: Opacity(
          opacity: outIn,
          child: Transform.scale(
            scale: 1.06 - 0.06 * outIn,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: Image.asset('assets/objects/OB04_drawer_out.webp', fit: BoxFit.contain)),
                Positioned(
                  left: out.width * _outInside.dx - out.width * 0.16,
                  top: out.height * _outInside.dy - out.width * 0.12,
                  width: out.width * 0.32,
                  height: out.width * 0.24,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [
                          _glow.withValues(alpha: (0.3 + 0.25 * _breathing) * outIn),
                          _glow.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }

    // 4. 籤號：寫在抽屜面上；拉開時移到下方的紙籤牌
    if (toFront > 0) {
      final onFront = Offset(w / 2, front.top + front.height * 0.2);
      final caption = Offset(w / 2, _captionCenterY(w));
      final pos = Offset.lerp(onFront, caption, open)!;
      final size = _numberFont(w) + (_captionFont(w) - _numberFont(w)) * open;
      children.add(_numberAt(pos, size, write: _seg(_write), card: outIn));
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }

  // ── 六十甲子：抽屜面淡入、發光、寫上籤號 ─────────────────────────

  Widget _frontOnly(double w) {
    final appear = Curves.easeOut.transform(_seg(_frontOnlyIn));
    final front = _frontRect(w);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: front,
          child: Opacity(
            opacity: appear,
            child: Transform.scale(scale: 0.92 + 0.08 * appear, child: _drawerFront(front.width, glow: appear)),
          ),
        ),
        _numberAt(Offset(w / 2, front.top + front.height * 0.2), _numberFont(w), write: _seg(_frontOnlyWrite), card: 0),
      ],
    );
  }

  // ── 共用 ─────────────────────────────────────────────────

  Rect _frontRect(double w) => Rect.fromLTWH(w * 0.1, w * 0.06, w * 0.8, w * 0.8);
  Rect _outRect(double w) => Rect.fromLTWH(w * 0.07, w * 0.02, w * 0.86, w * 0.86 * _outAspect);
  double _captionCenterY(double w) => w * 0.88;
  double _numberFont(double w) => w * 0.8 * 0.128;
  double _captionFont(double w) => w * 0.088;

  /// 抽屜面＋後面的暖光（呼吸）。
  Widget _drawerFront(double size, {required double glow}) {
    final a = glow * (0.35 + 0.3 * _breathing);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.06),
        boxShadow: [BoxShadow(color: _glow.withValues(alpha: a), blurRadius: size * 0.12, spreadRadius: size * 0.01)],
      ),
      child: Image.asset('assets/objects/OB04_drawer_front.webp', width: size, height: size),
    );
  }

  /// 以 [center] 為中心畫籤號；[write] 0…1 逐字由左到右寫出，[card] 0…1 淡入紙籤牌底。
  Widget _numberAt(Offset center, double fontSize, {required double write, required double card}) {
    final chars = _label.characters.toList();
    final style = brush(TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: Palette.ink,
      letterSpacing: fontSize * 0.1,
      height: 1.2,
    ));
    final boxW = fontSize * (chars.length + 2) * 1.15;
    final boxH = fontSize * 1.8;
    return Positioned(
      left: center.dx - boxW / 2,
      top: center.dy - boxH / 2,
      width: boxW,
      height: boxH,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.card.withValues(alpha: 0.92 * card),
          borderRadius: BorderRadius.circular(boxH / 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12 * card), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < chars.length; i++)
                Builder(builder: (_) {
                  // 每個字依序淡入並由大略縮回，像一筆一筆寫上去
                  final u = ((write * chars.length) - i).clamp(0.0, 1.0);
                  final e = Curves.easeOut.transform(u);
                  return Opacity(
                    opacity: e,
                    child: Transform.scale(scale: 1.25 - 0.25 * e, child: Text(chars[i], style: style)),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
