import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../data/models.dart';

/// 籤紙圖的長寬（@3x，籤詩_統一規格）。
const kSlipAspect = 1080 / 1620;

/// 分鏡 ⑤ 定格細讀：淺草寺籤紙可雙指放大；點任一句 → 其他部分調暗、該句用朱紅框框起，
/// 下方浮出這一句的白話；點最左欄看判語。再點同一句或點空白處收起。
/// 熱區位置來自 assets/data/hotspots_sensoji.json（tools/hotspots.py 產生）。
class SlipReader extends StatefulWidget {
  const SlipReader({
    super.key,
    required this.poem,
    required this.image,
    required this.hotspots,
    required this.gloss,
    this.judgment,
    this.onShowAll,
  });

  final Poem poem;

  /// 籤紙圖（外層可以包 SlipUnfold 等）。
  final Widget image;
  final SlipHotspots hotspots;
  final List<String> gloss;
  final Judgment? judgment;

  /// 「看全部白話」：打開四句並列的紙卡，標出目前這一句。
  final ValueChanged<int?>? onShowAll;

  @override
  State<SlipReader> createState() => SlipReaderState();
}

/// 選中的是第幾句（0–3）或判語（[judgmentIndex]）。
const judgmentIndex = 4;

class SlipReaderState extends State<SlipReader> {
  int? _selected;
  int? get selected => _selected;

  /// 收起時調暗層要淡出，挖空位置維持上一句，不然會先整片變暗再淡掉。
  int? _last;

  List<Rect> get _areas => [...widget.hotspots.lines, widget.hotspots.judgment];

  void select(int? i) => setState(() {
        _selected = (i == _selected) ? null : i;
        _last = _selected ?? _last;
      });

  void _onTap(Offset local, Size size) {
    final p = Offset(local.dx / size.width, local.dy / size.height);
    final hit = _areas.indexWhere((r) => r.contains(p));
    if (hit == judgmentIndex && widget.judgment == null) return;
    if (hit < 0) {
      setState(() => _selected = null);
    } else {
      select(hit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final fade = reduced ? Duration.zero : const Duration(milliseconds: 260);
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(
                      aspectRatio: kSlipAspect,
                      child: LayoutBuilder(builder: (context, slip) => _slip(slip.biggest, fade)),
                    ),
                  ),
                ),
              ),
            ),
            // 白話紙卡浮在籤紙下方，不跟著縮放
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.48),
                child: AnimatedSwitcher(
                  duration: fade,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: _selected == null ? const SizedBox.shrink() : _card(context, _selected!),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _slip(Size size, Duration fade) {
    final sel = _selected;
    final rect = sel == null ? null : _scale(_areas[sel], size);
    final hole = (sel ?? _last) == null ? null : _scale(_areas[(sel ?? _last)!], size);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.localPosition, size),
      child: Stack(
        children: [
          Positioned.fill(child: widget.image),
          // 調暗其他部分（選中的那一欄挖空）
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: sel == null ? 0 : 1,
                duration: fade,
                child: CustomPaint(painter: _DimPainter(hole: hole)),
              ),
            ),
          ),
          if (rect != null)
            Positioned.fromRect(
              rect: rect.inflate(2),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Palette.vermilion, width: 2.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          // 讀屏：每一句是一個按鈕
          for (final (i, area) in _areas.indexed)
            if (i < judgmentIndex || widget.judgment != null)
              Positioned.fromRect(
                rect: _scale(area, size),
                child: Semantics(
                  button: true,
                  selected: i == sel,
                  label: i == judgmentIndex ? '判語' : '第 ${i + 1} 句：${widget.poem.lines[i]}',
                  hint: '點兩下看白話',
                  onTap: () => select(i),
                  child: const SizedBox.expand(),
                ),
              ),
        ],
      ),
    );
  }

  Rect _scale(Rect r, Size s) => Rect.fromLTRB(r.left * s.width, r.top * s.height, r.right * s.width, r.bottom * s.height);

  Widget _card(BuildContext context, int i) {
    final text = Theme.of(context).textTheme;
    final isJudgment = i == judgmentIndex;
    return Material(
      key: ValueKey(i),
      color: Palette.card,
      elevation: 10,
      shadowColor: Palette.ink.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Palette.vermilion, width: 1.2),
      ),
      child: Semantics(
        liveRegion: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isJudgment ? '判語' : '第 ${i + 1} 句',
                      style: text.labelLarge?.copyWith(color: Palette.vermilionDeep),
                    ),
                  ),
                  IconButton(
                    tooltip: '收起',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 20),
                    color: Palette.inkSoft,
                    onPressed: () => setState(() => _selected = null),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: isJudgment ? _judgment(text) : _line(text, i),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(TextTheme text, int i) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.poem.lines[i],
            style: brush(const TextStyle(fontSize: 26, color: Palette.ink, letterSpacing: 3)),
          ),
          const SizedBox(height: 4),
          Text(widget.gloss[i], style: text.bodyLarge?.copyWith(color: Palette.ink, height: 1.6)),
          if (widget.onShowAll != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.onShowAll!(i),
                style: TextButton.styleFrom(foregroundColor: Palette.inkSoft, minimumSize: const Size(44, 40)),
                child: const Text('看四句白話'),
              ),
            ),
        ],
      );

  Widget _judgment(TextTheme text) {
    final j = widget.judgment!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in j.items.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  child: Text(e.key, style: text.bodyMedium?.copyWith(color: Palette.vermilionDeep)),
                ),
                Expanded(child: Text(e.value, style: text.bodyMedium?.copyWith(color: Palette.ink, height: 1.5))),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text('判語是籤紙上的日文原文；請 AI 解籤會用中文說明。', style: text.bodySmall?.copyWith(color: Palette.inkSoft)),
      ],
    );
  }
}

class _DimPainter extends CustomPainter {
  const _DimPainter({this.hole});
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (hole != null) path.addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(6)));
    canvas.drawPath(path, Paint()..color = Palette.ink.withValues(alpha: 0.42));
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}
